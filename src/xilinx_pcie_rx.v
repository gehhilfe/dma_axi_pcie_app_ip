`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2018 13:43:25
// Design Name: 
// Module Name: xilinx_pcie_rx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module xilinx_pcie_rx #(
    parameter P_DATA_WIDTH = 128,
    parameter P_KEEP_WIDTH = P_DATA_WIDTH / 8
)(
    input wire          i_clk,
    input wire          i_rst,
    
    // AXIS
    input wire                      s_axis_tx_tready,
    output  reg [P_DATA_WIDTH-1:0]  s_axis_tx_tdata,
    output  reg [P_KEEP_WIDTH-1:0]  s_axis_tx_tkeep,
    output  reg                     s_axis_tx_tlast,
    output  reg                     s_axis_tx_tvalid,
    output  wire                    tx_src_dsc,
    
    // DMA Read request intf
    input wire [31:0]   dma_read_addr,
    input wire [9:0]    dma_read_len,
    input wire          dma_read_valid,
    output reg          dma_read_done,
    output wire [7:0]   current_tag,

    // DMA Write Request intf
    input wire [31:0]   dma_write_addr,
    input wire [9:0]    dma_write_len,
    input wire          dma_write_pending,
    output reg          dma_write_done,

    // DMA Write Data Stream intf
    input wire [127:0]  dma_write_data,
    input wire          dma_write_data_valid,
    output wire         dma_write_data_ready,


    input wire          req_compl,
    input wire          req_compl_wd,
    output reg          compl_done,
    
    input wire [2:0]    req_tc,
    input wire          req_td,
    input wire          req_ep,
    input wire [1:0]    req_attr,
    input wire [9:0]    req_len,
    input wire [15:0]   req_rid,
    input wire [7:0]    req_tag,
    input wire [7:0]    req_be,
    input wire [31:0]   req_addr,
    
    output wire [31:0]  rd_addr,
    output wire [3:0]   rd_be,
    input wire [31:0]   rd_data,
    input wire [15:0]   completer_id
    );

assign rd_be = req_be;
assign rd_addr = req_addr[31:0];
// Unused discontinue
assign tx_src_dsc = 1'b0;

localparam PIO_CPLD_FMT_TYPE      = 7'b10_01010;
localparam PIO_CPL_FMT_TYPE       = 7'b00_01010;
localparam FMT_TYPE_READ_REQUEST  = 7'b00_00000;
localparam FMT_TYPE_WRITE_REQUEST = 7'b10_00000;

reg [6:0] lower_addr;
always @ (rd_be or req_addr or req_compl_wd) begin
        casex ({req_compl_wd, rd_be[3:0]})
                5'b1_0000 : lower_addr = {req_addr[6:2], 2'b00};
                5'b1_xxx1 : lower_addr = {req_addr[6:2], 2'b00};
                5'b1_xx10 : lower_addr = {req_addr[6:2], 2'b01};
                5'b1_x100 : lower_addr = {req_addr[6:2], 2'b10};
                5'b1_1000 : lower_addr = {req_addr[6:2], 2'b11};
                5'b0_xxxx : lower_addr = 8'h0;
        endcase // casex ({compl_wd, rd_be[3:0]})
end


// Local registers
reg [11:0] byte_count;

always @ (rd_be) begin
        casex (rd_be[3:0])
                4'b1xx1 : byte_count = 12'h004;
                4'b01x1 : byte_count = 12'h003;
                4'b1x10 : byte_count = 12'h003;
                4'b0011 : byte_count = 12'h002;
                4'b0110 : byte_count = 12'h002;
                4'b1100 : byte_count = 12'h002;
                4'b0001 : byte_count = 12'h001;
                4'b0010 : byte_count = 12'h001;
                4'b0100 : byte_count = 12'h001;
                4'b1000 : byte_count = 12'h001;
                4'b0000 : byte_count = 12'h001;
        endcase
end

localparam 
    lp_state_bits = 32,
    lp_state_idle = 0,
    lp_state_fin = 1,
    lp_state_wait_ready = 2,
    lp_state_stream_dma_write = 3;


reg [lp_state_bits-1:0] state, state_next, state_after_ready, state_after_ready_next;

reg [8:0] r_dma_write_cycles;
reg [127:0] r_dma_write_scratch;


reg set_read_completion_with_data;
reg set_read_completion_without_data;
reg set_dma_read_request;
reg set_dma_write_request;
reg set_stream_dma_write;

assign dma_write_data_ready = set_dma_write_request || (set_stream_dma_write && r_dma_write_cycles > 1);

reg reset_valid;
reg [7:0] next_free_tag;
assign current_tag = next_free_tag;
reg incr_tag;

always @(*) begin
    state_next = state;
    set_read_completion_with_data = 0;
    set_dma_read_request = 0;
    set_dma_write_request = 0;
    set_stream_dma_write = 0;

    set_read_completion_without_data = 0;
    reset_valid = 0;
    incr_tag = 0;
    
    case(state)
        lp_state_idle: begin
            if(req_compl) begin
                state_next = lp_state_fin;
                if(req_compl_wd)
                    set_read_completion_with_data = 1;
                else
                    set_read_completion_without_data = 1;
            end else if(dma_read_valid) begin
                state_next = lp_state_fin;
                set_dma_read_request = 1;
                incr_tag = 1;
            end else if(dma_write_pending) begin
                set_dma_write_request = 1;
                state_next = lp_state_stream_dma_write;
            end
        end

        lp_state_fin: begin
            if (s_axis_tx_tready) begin
                reset_valid = 1;
                state_next = lp_state_idle;
            end
        end

        lp_state_wait_ready: begin
            if (s_axis_tx_tready) begin
                state_next = state_after_ready;
            end
        end

        lp_state_stream_dma_write: begin
            if (s_axis_tx_tready) begin
                if(r_dma_write_cycles != 0) begin
                    set_stream_dma_write = 1;    
                end else begin
                    reset_valid = 1;
                    state_next = lp_state_idle;
                end
            end
        end
    endcase
end

function [P_DATA_WIDTH-1:0] tlp_header_completion;
    input [6:0] fmt_type;
    input [2:0] tc;
    input td;
    input ep;
    input [1:0] attr;
    input [9:0] len;
    input [15:0] completer_id;
    input [11:0] byte_count;
    input [15:0] requester_id;
    input [7:0] tag;
    input [6:0] lower_addr;
    input [31:0] data;
    begin
        tlp_header_completion = {
                data,                   // 32 // DW 4

                requester_id,           // 16 // DW 3
                tag,                    //  8
                {1'b0},                 //  1
                lower_addr,             //  7
                
                completer_id,           // 16 // DW 2
                {3'b0},                 //  3
                {1'b0},                 //  1
                byte_count,             // 12

                {1'b0},                 //  1 // DW 1
                fmt_type,               //  7
                {1'b0},                 //  1
                tc,                     //  3
                {4'b0},                 //  4
                td,                     //  1
                ep,                     //  1
                attr,                   //  2
                {2'b0},                 //  2
                len                     // 10
        };
    end
endfunction

function [P_DATA_WIDTH-1:0] tlp_header_read_request;
    input [31:0] addr;
    input [9:0] len;
    input [7:0] tag;
    input [15:0] completer_id;
    begin
        tlp_header_read_request = {
                {32'b0},                // 32 // DW 3
                
                addr[31:2],             // 30 // DW 2
                {2'b0},                 //  2

                completer_id,           // 16 // DW 1
                tag,                    // 8
                (len==1)?{4'b0}:{4'hf},                 //  4
                {4'hf},                 //  4

                {1'b0},                 //  1 // DW 0
                FMT_TYPE_READ_REQUEST,  //  7 //
                {1'b0},                 //  1 //
                {3'b0},                 //  3 //
                {4'b0},                 //  4 //
                {1'b0},                 //  1 //
                {1'b0},                 //  1 //
                {2'b0},                 //  2 //
                {2'b0},                 //  2 //
                len                     // 10 //
        };
    end
endfunction

function [P_DATA_WIDTH-1:0] tlp_header_write_request;
    input [31:0] addr;
    input [9:0] len;
    input [15:0] completer_id;
    input [31:0] first_dw;
    begin
        tlp_header_write_request = {
                first_dw,               // 32 // DW 4
                
                addr[31:2],             // 30 // DW 3
                {2'b0},                 //  2

                completer_id/*{16'b0}*/,                // 16 // DW 1 Req. ID
                8'h0,                   // 8
                (len==1)?{4'b0}:{4'hf}, //  4
                {4'hf},                 //  4

                {1'b0},                 //  1 // DW 0
                FMT_TYPE_WRITE_REQUEST, //  7 //
                {1'b0},                 //  1 // R
                {3'b0},                 //  3 // TC
                {4'b0},                 //  4 // R
                {1'b0},                 //  1 // TD
                {1'b0},                 //  1 // EP
                {2'b0},                 //  2 // Attr
                {2'b0},                 //  2 // R
                len                     // 10 //
        };
    end
endfunction

always @(posedge i_clk) begin
    if (i_rst) begin
        state <= lp_state_idle;
        s_axis_tx_tvalid <= 0;
        compl_done  <= 0;
        dma_read_done <= 0;
        next_free_tag <= 0;
        dma_write_done <= 0;
    end
    else begin
        state <= state_next;
        state_after_ready <= state_after_ready_next;

        if (incr_tag) next_free_tag <= next_free_tag + 1'b1;
        if (dma_write_done) dma_write_done <= 0;

        if (reset_valid) begin
            s_axis_tx_tvalid  <=  1'b0;
            compl_done <= 0;
            dma_read_done <= 0;
        end else if (set_read_completion_with_data || set_read_completion_without_data) begin
            s_axis_tx_tdata <= tlp_header_completion(
                    (set_read_completion_without_data)?PIO_CPL_FMT_TYPE:PIO_CPLD_FMT_TYPE,
                    req_tc,
                    req_td,
                    req_ep,
                    req_attr,
                    req_len,
                    completer_id,
                    byte_count,
                    req_rid,
                    req_tag,
                    lower_addr,
                    rd_data
                );

            if (set_read_completion_with_data)
                s_axis_tx_tkeep   <=  16'hFFFF;
            else
                s_axis_tx_tkeep   <=  16'h0FFF;

            s_axis_tx_tlast   <=  1'b1;
            s_axis_tx_tvalid  <=  1'b1;
            compl_done <= 1;
        end // set_read_completion
        else if (set_dma_read_request) begin
            s_axis_tx_tdata <= tlp_header_read_request (
                    dma_read_addr,
                    dma_read_len[9:0],
                    next_free_tag,
                    completer_id
                );
            s_axis_tx_tkeep   <=  16'h0FFF;
            s_axis_tx_tvalid  <=  1'b1;
            dma_read_done <= 1;
        end // set_dma_read_request
        else if(set_dma_write_request) begin
            s_axis_tx_tdata <= tlp_header_write_request (
                    dma_write_addr,
                    dma_write_len,
                    completer_id,
                    dma_write_data[31:0]
                );
            r_dma_write_cycles <= dma_write_len[9:2];
            r_dma_write_scratch <= dma_write_data;
            s_axis_tx_tkeep   <=  16'hFFFF;
            s_axis_tx_tvalid  <=  1'b1;
            s_axis_tx_tlast <= 0;
            dma_write_done <= 1;
        end // set_dma_write_request
        else if (set_stream_dma_write) begin
            s_axis_tx_tdata[95:0] <= r_dma_write_scratch[127:32];
            s_axis_tx_tdata[127:96] <= dma_write_data[31:0];
            r_dma_write_scratch <= dma_write_data;
            if(r_dma_write_cycles == 1) begin
                s_axis_tx_tkeep <= 16'h0FFF;
                s_axis_tx_tlast <= 1;
            end
            r_dma_write_cycles <= r_dma_write_cycles - 1'b1;
        end
    end
end

endmodule
