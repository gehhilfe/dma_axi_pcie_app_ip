// File: xilinx_pcie_ep.v
// Name: Tim Burkert
// Email: burkert.tim@gmail.com
// Date: 23.4.18
// Desc: PCIE Endpoint converting Xilinx PCIE IP-Core to AXI and DMA Module

`define DEFAULT(A,B) A = B;
`define APPLY(A,B) B <= A;

module xilinx_pcie_completer #(
    parameter P_DATA_WIDTH = 128,
    parameter P_KEEP_WIDTH = P_DATA_WIDTH / 8
    )(
    input wire          i_clk,
    input wire          i_rst_n,

    // AXIS
    input wire                      s_axis_tx_tready,
    output  reg [P_DATA_WIDTH-1:0]  s_axis_tx_tdata,
    output  reg [P_KEEP_WIDTH-1:0]  s_axis_tx_tkeep,
    output  reg                     s_axis_tx_tlast,
    output  reg                     s_axis_tx_tvalid,
    output  wire                    tx_src_dsc,

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
    output reg [3:0]    rd_be,
    input wire [31:0]   rd_data,
    input wire [15:0]   completer_id
    );


localparam PIO_CPLD_FMT_TYPE      = 7'b10_01010;
localparam PIO_CPL_FMT_TYPE       = 7'b00_01010;
localparam PIO_TX_RST_STATE       = 2'b00;
localparam PIO_TX_CPLD_QW1_FIRST  = 2'b01;
localparam PIO_TX_CPLD_QW1_TEMP   = 2'b10;
localparam PIO_TX_CPLD_QW1        = 2'b11;

assign rd_addr = req_addr[31:0];

// Unused discontinue
assign tx_src_dsc = 1'b0;

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

always @(posedge i_clk) begin
    if (i_rst_n)
    begin
     rd_be <=  0;
    end else begin
     rd_be <= req_be[3:0];
    end
  end

reg [6:0] lower_addr;
reg hold_state;
reg req_compl_q;
reg [31:0] rd_data_q;
reg req_compl_wd_q;
reg req_compl_q2;
reg [31:0] rd_data_q2;
reg req_compl_wd_q2;

wire compl_wd = req_compl_wd_q2;

always @ (rd_be or req_addr or compl_wd) begin
        casex ({compl_wd, rd_be[3:0]})
                5'b1_0000 : lower_addr = {req_addr[6:2], 2'b00};
                5'b1_xxx1 : lower_addr = {req_addr[6:2], 2'b00};
                5'b1_xx10 : lower_addr = {req_addr[6:2], 2'b01};
                5'b1_x100 : lower_addr = {req_addr[6:2], 2'b10};
                5'b1_1000 : lower_addr = {req_addr[6:2], 2'b11};
                5'b0_xxxx : lower_addr = 8'h0;
        endcase // casex ({compl_wd, rd_be[3:0]})
end


always @ ( posedge i_clk ) begin
  if (i_rst_n )
  begin
    req_compl_q      <= 1'b0;
    req_compl_wd_q   <= 1'b1;
  end // if !rst_n
  else
  begin
    rd_data_q <= rd_data;
    req_compl_q      <= req_compl;
    req_compl_wd_q   <= req_compl_wd;
  end // if rst_n
end

always @ ( posedge i_clk ) begin
  if (i_rst_n)
  begin
    req_compl_q2      <=  1'b0;
    req_compl_wd_q2   <=  1'b0;
  end // if (!rst_n )
  else
  begin
    rd_data_q2 <= rd_data_q;
    req_compl_q2      <=  req_compl_q;
    req_compl_wd_q2   <=  req_compl_wd_q;
  end // if (rst_n )
end

always @ ( posedge i_clk ) begin
        if (i_rst_n) begin
                s_axis_tx_tlast   <=  1'b0;
                s_axis_tx_tvalid  <=  1'b0;
                s_axis_tx_tdata   <=  {P_DATA_WIDTH{1'b0}};
                s_axis_tx_tkeep   <=  {P_KEEP_WIDTH{1'b0}};
                compl_done        <=  1'b0;
                hold_state        <=  1'b0;
        end else begin
        if (req_compl_q2 | hold_state) begin
                if (s_axis_tx_tready) begin
                        s_axis_tx_tlast   <=  1'b1;
                        s_axis_tx_tvalid  <=  1'b1;
                        s_axis_tx_tdata   <=  {                   // Bits
                                            rd_data_q2,                  // 32
                                            req_rid,                  // 16
                                            req_tag,                  //  8
                                            {1'b0},                   //  1
                                            lower_addr,               //  7
                                            completer_id,             // 16
                                            {3'b0},                   //  3
                                            {1'b0},                   //  1
                                            byte_count,               // 12
                                            {1'b0},                   //  1
                                            (req_compl_wd_q2 ?
                                            PIO_CPLD_FMT_TYPE :
                                            PIO_CPL_FMT_TYPE),        //  7
                                            {1'b0},                   //  1
                                            req_tc,                   //  3
                                            {4'b0},                   //  4
                                            req_td,                   //  1
                                            req_ep,                   //  1
                                            req_attr,                 //  2
                                            {2'b0},                   //  2
                                            req_len                   // 10
                                            };

                        // Here we select if the packet has data or
                        // not.  The strobe signal will mask data
                        // when it is not needed.  No reason to change
                        // the data bus.
                        if (req_compl_wd_q2)
                          s_axis_tx_tkeep   <=  16'hFFFF;
                        else
                          s_axis_tx_tkeep   <=  16'h0FFF;

                        compl_done        <=  1'b1;
                        hold_state        <=  1'b0;

                end // if (s_axis_tx_tready)
                else
                        hold_state        <=  1'b1;

        end // if (req_compl_q2 | hold_state)
    else begin
              s_axis_tx_tlast   <=  1'b0;
              s_axis_tx_tvalid  <=  1'b0;
              s_axis_tx_tdata   <=  {P_DATA_WIDTH{1'b0}};
              s_axis_tx_tkeep   <=  {P_KEEP_WIDTH{1'b1}};
              compl_done        <=  1'b0;
    end // if !(req_compl_q2 | hold_state)
  end // if rst_n
end

endmodule
