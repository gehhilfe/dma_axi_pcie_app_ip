// File: xilinx_pcie_ep_init.vh
// Name: Tim Burkert
// Email: burkert.tim@gmail.com
// Date: 16.4.18
// Desc: Instantiate a xilinx_pcie_ep used for VPCIE testbench

wire [2:0]      req_tc;
wire            req_td;
wire            req_ep;
wire [1:0]      req_attr;
wire [9:0]      req_len;
wire [15:0]     req_rid;
wire [7:0]      req_tag;
wire [7:0]      req_be;
wire [12:0]     req_addr;

xilinx_pcie_ep xilinx_pcie_ep_inst (
    .i_clk(user_clk),
    .i_rst_n(user_reset),

    //.cfg_max_read_request_size(cfg_dcommand[14:12]),
    //.cfg_max_payload_size(cfg_dcommand[7:5]),

    .m_axis_rx_tlast(m_axis_rx_tlast),
    .m_axis_rx_tdata(m_axis_rx_tdata),
    .m_axis_rx_tuser(m_axis_rx_tuser),
    .m_axis_rx_tvalid(m_axis_rx_tvalid),
    .m_axis_rx_tready(m_axis_rx_tready),

    .req_tc(req_tc),
    .req_td(req_td),
    .req_ep(req_ep),
    .req_attr(req_attr),
    .req_len(req_len),
    .req_rid(req_rid),
    .req_tag(req_tag),
    .req_be(req_be),
    .req_addr(req_addr),

    .req_compl(req_compl),
    .req_compl_wd(req_compl_wd),

    .compl_done(compl_done),
    .wr_busy(1'b0)
    );

xilinx_pcie_completer xilinx_pcie_completer_inst (
    .i_clk(user_clk),
    .i_rst_n(user_reset),

    .s_axis_tx_tready(s_axis_tx_tready),
    .s_axis_tx_tdata(s_axis_tx_tdata),
    .s_axis_tx_tkeep(s_axis_tx_tkeep),
    .s_axis_tx_tlast(s_axis_tx_tlast),
    .s_axis_tx_tvalid(s_axis_tx_tvalid),
    .tx_src_dsc(tx_src_dsc),

    .req_compl(req_compl),
    .req_compl_wd(req_compl_wd),
    .compl_done(compl_done),

    .req_tc(req_tc),
    .req_td(req_td),
    .req_ep(req_ep),
    .req_attr(req_attr),
    .req_len(req_len),
    .req_rid(req_rid),
    .req_tag(req_tag),
    .req_be(req_be),
    .req_addr(req_addr),

    .completer_id(cfg_completer_id),
    .rd_data(32'hCAFEBABE)
);
