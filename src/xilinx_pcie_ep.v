// File: xilinx_pcie_ep.v
// Name: Tim Burkert
// Email: burkert.tim@gmail.com
// Date: 16.4.18
// Desc: PCIE Endpoint converting Xilinx PCIE IP-Core to AXI and DMA Module

`define DEFAULT(A,B) A = B;
`define APPLY(A,B) B <= A;

module xilinx_pcie_ep #(
    parameter P_DATA_WIDTH = 128
    )(
    input wire i_clk,
    input wire i_rst_n,
    //Configuration interface
    input wire [2:0] cfg_max_read_request_size,
    input wire [2:9] cfg_max_payload_size,

    // Memory read compleation
    output reg         req_compl,
    output reg         req_compl_wd,
    input wire         compl_done,

    output reg [2:0] req_tc,
    output reg req_td,
    output reg req_ep,
    output reg [1:0] req_attr,
    output reg [9:0] req_len,
    output reg [15:0] req_rid,
    output reg [7:0] req_tag,
    output reg [7:0] req_be,
    output reg [12:0] req_addr,

    // Memory Write
    output reg [10:0]  wr_addr,
    output reg [7:0]   wr_be,
    output reg [31:0]  wr_data,
    output reg         wr_en,
    input wr_busy,

    //Receive interface signals
    input wire m_axis_rx_tlast,
    input wire [P_DATA_WIDTH-1:0] m_axis_rx_tdata,
    input wire [21:0] m_axis_rx_tuser,
    input wire m_axis_rx_tvalid,
    output reg m_axis_rx_tready
    );

localparam
    lp_state_bits = 32,
    lp_state_rst = 0,
    lp_state_rx_mem_rd32_dw1dw2 = 1,
    lp_state_rx_mem_wr32_dw1dw2 = 2,
    lp_state_rx_wait = 3;

localparam RX_MEM_RD32_FMT_TYPE = 7'b000_0000;
localparam RX_MEM_WR32_FMT_TYPE = 7'b100_0000;
localparam RX_MEM_RD64_FMT_TYPE = 7'b010_0000;
localparam RX_MEM_WR64_FMT_TYPE = 7'b110_0000;
localparam RX_IO_RD32_FMT_TYPE  = 7'b000_0010;
localparam RX_IO_WR32_FMT_TYPE  = 7'b100_0010;

//wires
wire [4:0] rx_is_of = m_axis_rx_tuser[21:17];
wire [4:0] rx_is_eof = m_axis_rx_tuser[14:10];
wire [7:0] rx_bar_hit = m_axis_rx_tuser[9:2];
wire rx_err_fwd = m_axis_rx_tuser[1];
wire rx_ecrc_err = m_axis_rx_tuser[0];

wire sof_present = m_axis_rx_tuser[14];
wire sof_right = !m_axis_rx_tuser[13] && sof_present;
wire sof_mid = m_axis_rx_tuser[13] && sof_present;

//registers
reg [lp_state_bits-1:0] rx_state;
reg [7:0] tlp_type;

//comb registers
reg req_compl_next;
reg req_compl_wd_next;

reg m_axis_rx_tready_next;
reg [lp_state_bits-1:0] rx_state_next;
reg [7:0] tlp_type_next;

reg [2:0] req_tc_next;
reg req_td_next;
reg req_ep_next;
reg [1:0] req_attr_next;
reg [9:0] req_len_next;
reg [15:0] req_rid_next;
reg [7:0] req_tag_next;
reg [7:0] req_be_next;
reg [12:0] req_addr_next;

reg [10:0]  wr_addr_next;
reg [7:0]   wr_be_next;
reg [31:0]  wr_data_next;
reg         wr_en_next;

assign    mem64_bar_hit_n = 1'b1;
assign    io_bar_hit_n = 1'b1;
assign    mem32_bar_hit_n = ~(m_axis_rx_tuser[2]);
assign    erom_bar_hit_n  = ~(m_axis_rx_tuser[8]);

reg [1:0] region_select;
always @(*) begin
  case ({io_bar_hit_n, mem32_bar_hit_n, mem64_bar_hit_n, erom_bar_hit_n})

    4'b0111 : begin
      region_select <= 2'b00;    // Select IO region
    end // 4'b0111

    4'b1011 : begin
      region_select <= 2'b01;    // Select Mem32 region
    end // 4'b1011

    4'b1101 : begin
      region_select <= 2'b10;    // Select Mem64 region
    end // 4'b1101

    4'b1110 : begin
      region_select <= 2'b11;    // Select EROM region
    end // 4'b1110

    default : begin
      region_select <= 2'b00;    // Error selection will select IO region
    end // default

  endcase // case ({io_bar_hit_n, mem32_bar_hit_n, mem64_bar_hit_n, erom_bar_hit_n})
end

//comb logic state_next
always @ ( * ) begin
    rx_state_next = rx_state;
    `DEFAULT(req_tc_next, req_tc)
    `DEFAULT(req_td_next, req_td)
    `DEFAULT(req_ep_next, req_ep)
    `DEFAULT(req_attr_next, req_attr)
    `DEFAULT(req_len_next, req_len)
    `DEFAULT(req_rid_next, req_rid)
    `DEFAULT(req_tag_next, req_tag)
    `DEFAULT(req_be_next, req_be)
    `DEFAULT(tlp_type_next, tlp_type)
    case (rx_state)
        lp_state_rst: begin
            rx_state_next = lp_state_rst;
            //PNew TLP start
            if(m_axis_rx_tvalid && m_axis_rx_tready) begin
                //TLP start in middle
                if(sof_mid) begin
                    tlp_type_next = m_axis_rx_tdata[95:88];
                    req_len_next = m_axis_rx_tdata[73:64];
                    case(m_axis_rx_tdata[94:88])

                        RX_MEM_RD32_FMT_TYPE: begin
                            if(m_axis_rx_tdata[73:64] == 10'b1) begin
                                req_tc_next =  m_axis_rx_tdata[86:84];
                                req_td_next =  m_axis_rx_tdata[79];
                                req_ep_next =  m_axis_rx_tdata[78];
                                req_attr_next =  m_axis_rx_tdata[77:76];
                                req_len_next =  m_axis_rx_tdata[73:64];
                                req_rid_next =  m_axis_rx_tdata[127:112];
                                req_tag_next =  m_axis_rx_tdata[111:104];
                                req_be_next =  m_axis_rx_tdata[103:96];
                                rx_state_next = lp_state_rx_mem_rd32_dw1dw2;
                            end else begin
                                rx_state_next = lp_state_rst;
                            end
                        end
/*
                        RX_MEM_RD64_FMT_TYPE: begin
                            if(m_axis_rx_tdata[73:64] == 10'b1) begin
                                req_tc_next =  m_axis_rx_tdata[86:84];
                                req_td_next =  m_axis_rx_tdata[79];
                                req_ep_next =  m_axis_rx_tdata[78];
                                req_attr_next =  m_axis_rx_tdata[77:76];
                                req_len_next =  m_axis_rx_tdata[73:64];
                                req_rid_next =  m_axis_rx_tdata[127:112];
                                req_tag_next =  m_axis_rx_tdata[111:104];
                                req_be_next =  m_axis_rx_tdata[103:96];
                            end else begin
                                rx_state_next = lp_state_rst;
                            end
                        end
*/
                        RX_MEM_WR32_FMT_TYPE: begin
                            if(m_axis_rx_tdata[73:64] == 10'b1) begin
                                //WR
                                rx_state_next = lp_state_rx_mem_wr32_dw1dw2;
                            end else begin
                                rx_state_next = lp_state_rst;
                            end
                        end
/*
                        RX_MEM_WR64_FMT_TYPE: begin
                            if(m_axis_rx_tdata[73:64] == 10'b1) begin
                                //WR
                            end else begin
                                rx_state_next = lp_state_rst;
                            end
                        end
*/
                        default: $display("Unsuporrted FMT TYPE in module xilinx_pcie_ep\n");
                    endcase
                end
                //TLP start on right
                else if(sof_right) begin
                    tlp_type_next = m_axis_rx_tdata[31:24];
                    req_len_next = m_axis_rx_tdata[9:0];
                    case (m_axis_rx_tdata[30:24])

                        RX_MEM_RD32_FMT_TYPE: begin
                            if(m_axis_rx_tdata[9:0] == 10'b1) begin
                                req_tc_next =  m_axis_rx_tdata[22:20];
                                req_td_next =  m_axis_rx_tdata[15];
                                req_ep_next =  m_axis_rx_tdata[14];
                                req_attr_next =  m_axis_rx_tdata[13:12];
                                req_len_next =  m_axis_rx_tdata[9:0];
                                req_rid_next =  m_axis_rx_tdata[63:48];
                                req_tag_next =  m_axis_rx_tdata[47:40];
                                req_be_next =  m_axis_rx_tdata[39:32];
                                rx_state_next = lp_state_rx_wait;
                            end else begin
                                rx_state_next = lp_state_rst;
                            end
                        end
/*
                        RX_MEM_RD64_FMT_TYPE: begin
                            if(m_axis_rx_tdata[9:0] == 10'b1) begin
                                req_tc_next =  m_axis_rx_tdata[22:20];
                                req_td_next =  m_axis_rx_tdata[15];
                                req_ep_next =  m_axis_rx_tdata[14];
                                req_attr_next =  m_axis_rx_tdata[13:12];
                                req_len_next =  m_axis_rx_tdata[9:0];
                                req_rid_next =  m_axis_rx_tdata[63:48];
                                req_tag_next =  m_axis_rx_tdata[47:40];
                                req_be_next =  m_axis_rx_tdata[49:32];
                            end else begin
                                rx_state_next = lp_state_rst;
                            end
                        end
*/
                        RX_MEM_WR32_FMT_TYPE: begin
                            if(m_axis_rx_tdata[9:0] == 10'b1) begin
                                //WR
                                rx_state_next = lp_state_rx_wait;
                            end else begin
                                rx_state_next = lp_state_rst;
                            end
                        end
/*
                        RX_MEM_WR64_FMT_TYPE: begin
                            if(m_axis_rx_tdata[9:0] == 10'b1) begin
                                //WR
                            end else begin
                                rx_state_next = lp_state_rst;
                            end
                        end
*/
                        default: $display("Unsuporrted FMT TYPE in module xilinx_pcie_ep\n");
                    endcase
                end
            end
        end

        lp_state_rx_mem_rd32_dw1dw2: begin
                if(m_axis_rx_tvalid) begin
                        rx_state_next = lp_state_rx_wait;
                end else begin
                        rx_state_next = lp_state_rx_mem_rd32_dw1dw2;
                end
        end

        lp_state_rx_mem_wr32_dw1dw2: begin
                if(m_axis_rx_tvalid) begin
                        rx_state_next = lp_state_rx_wait;
                end else begin
                        rx_state_next = lp_state_rx_mem_wr32_dw1dw2;
                end
        end

        lp_state_rx_wait: begin
                if ((tlp_type == RX_MEM_WR32_FMT_TYPE) &&(!wr_busy)) begin
                  rx_state_next =  lp_state_rst;
                end // if ((tlp_type == RX_MEM_WR32_FMT_TYPE) &&(!wr_busy))
                else if ((tlp_type == RX_IO_WR32_FMT_TYPE) && (!wr_busy)) begin
                  rx_state_next =  lp_state_rst;
                end // if ((tlp_type == RX_IO_WR32_FMT_TYPE) && (!compl_done))
                else if ((tlp_type == RX_MEM_WR64_FMT_TYPE) && (!wr_busy)) begin
                  rx_state_next =  lp_state_rst;
                end // if ((tlp_type == RX_MEM_WR64_FMT_TYPE) && (!wr_busy))
                else if ((tlp_type == RX_MEM_RD32_FMT_TYPE) && (compl_done)) begin
                  rx_state_next =  lp_state_rst;
                end
                else if ((tlp_type == RX_IO_RD32_FMT_TYPE) && (compl_done)) begin
                  rx_state_next =  lp_state_rst;
                end
                else if ((tlp_type == RX_MEM_RD64_FMT_TYPE) && (compl_done)) begin
                  rx_state_next =  lp_state_rst;
                end else begin
                  rx_state_next = lp_state_rx_wait;
                end
        end
        default: $display("Unkown state in module xilinx_pcie_ep\n");
    endcase
end

//comb logic output next
always @ ( * ) begin
    `DEFAULT(m_axis_rx_tready_next, 1'b0)
    `DEFAULT(req_addr_next, req_addr)
    `DEFAULT(req_compl_next, 1'b0)
    `DEFAULT(req_compl_wd_next, 1'b0)
    `DEFAULT(wr_data_next, wr_data)
    `DEFAULT(wr_addr_next, wr_addr)
    `DEFAULT(wr_en_next, 1'b0)
    `DEFAULT(wr_be_next, wr_be)

    case (rx_state)
        lp_state_rst: begin
            m_axis_rx_tready_next = 1'b1;
            if ((m_axis_rx_tvalid) && (m_axis_rx_tready)) begin
                if(sof_mid) begin
                    m_axis_rx_tready_next = 1'b0;
                end else if(sof_right) begin
                    m_axis_rx_tready_next = 1'b0;
                    case (m_axis_rx_tdata[30:24])
                            RX_MEM_RD32_FMT_TYPE: begin
                                    if (m_axis_rx_tdata[9:0] == 10'b1) begin
                                            req_addr_next = m_axis_rx_tdata[78:66];
                                            req_compl_next = 1;
                                            req_compl_wd_next = 1;
                                    end
                            end
                            RX_MEM_WR32_FMT_TYPE: begin
                                    if (m_axis_rx_tdata[9:0] == 10'b1) begin
                                            wr_be_next = m_axis_rx_tdata[39:32];
                                            wr_data_next = m_axis_rx_tdata[127:96];
                                            wr_addr_next = m_axis_rx_tdata[78:66];
                                            wr_en_next = 1'b1;
                                    end
                            end
                    endcase
                end
            end
        end

        lp_state_rx_mem_rd32_dw1dw2: begin
                if(m_axis_rx_tvalid) begin
                        m_axis_rx_tready_next = 1'b0;
                        req_addr_next = m_axis_rx_tdata[14:2];
                        req_compl_next = 1;
                        req_compl_wd_next = 1;
                end
        end

        lp_state_rx_mem_wr32_dw1dw2: begin
                if(m_axis_rx_tvalid) begin
                        m_axis_rx_tready_next = 1'b0;
                        wr_data_next = m_axis_rx_tdata[63:32];
                        wr_addr_next = m_axis_rx_tdata[14:2];
                        wr_en_next = 1'b1;
                end
        end

        lp_state_rx_wait: begin
                if ((tlp_type == RX_MEM_WR32_FMT_TYPE) &&(!wr_busy)) begin
                  m_axis_rx_tready_next  =  1'b1;
                end // if ((tlp_type == RX_MEM_WR32_FMT_TYPE) &&(!wr_busy))
                else if ((tlp_type == RX_IO_WR32_FMT_TYPE) && (!wr_busy)) begin
                  m_axis_rx_tready_next =  1'b1;
                end // if ((tlp_type == RX_IO_WR32_FMT_TYPE) && (!compl_done))
                else if ((tlp_type == RX_MEM_WR64_FMT_TYPE) && (!wr_busy)) begin
                  m_axis_rx_tready_next =  1'b1;
                end // if ((tlp_type == RX_MEM_WR64_FMT_TYPE) && (!wr_busy))
                else if ((tlp_type == RX_MEM_RD32_FMT_TYPE) && (compl_done)) begin
                  m_axis_rx_tready_next =  1'b1;
                end
                else if ((tlp_type == RX_IO_RD32_FMT_TYPE) && (compl_done)) begin
                  m_axis_rx_tready_next =  1'b1;
                end
                else if ((tlp_type == RX_MEM_RD64_FMT_TYPE) && (compl_done)) begin
                  m_axis_rx_tready_next =  1'b1;
                end
        end

        default: $display("Unkown output for next state module xilinx_pcie_ep\n");
    endcase
end

//seq logic

always @ (posedge i_clk) begin
    if(i_rst_n) begin
        m_axis_rx_tready <= 0;
        rx_state <= lp_state_rst;
        wr_en <= 0;
    end else begin
        m_axis_rx_tready <= m_axis_rx_tready_next;
        rx_state <= rx_state_next;

        `APPLY(req_tc_next, req_tc)
        `APPLY(req_td_next, req_td)
        `APPLY(req_ep_next, req_ep)
        `APPLY(req_attr_next, req_attr)
        `APPLY(req_len_next, req_len)
        `APPLY(req_rid_next, req_rid)
        `APPLY(req_tag_next, req_tag)
        `APPLY(req_be_next, req_be)
        `APPLY(tlp_type_next, tlp_type)

        `APPLY(req_compl_next, req_compl)
        `APPLY(req_compl_wd_next, req_compl_wd)
        `APPLY(wr_data_next, wr_data)
        `APPLY(wr_addr_next, wr_addr)
        `APPLY(wr_en_next, wr_en)
        `APPLY(wr_be_next, wr_be)
        `APPLY(req_addr_next, req_addr)
    end
end


// DEBUG

// synthesis translate_off
reg  [8*20:1] state_ascii;
always @(rx_state)
begin
  case (rx_state)
    lp_state_rst                        : state_ascii <= "lp_state_rst";
    lp_state_rx_mem_rd32_dw1dw2         : state_ascii <= "lp_state_rx_mem_rd32_dw1dw2";
    lp_state_rx_mem_wr32_dw1dw2         : state_ascii <= "lp_state_rx_mem_wr32_dw1dw2";
    lp_state_rx_wait                    : state_ascii <=  "lp_state_rx_wait";

  endcase

end
// synthesis translate_on

endmodule // xilinx_pcie_ep
