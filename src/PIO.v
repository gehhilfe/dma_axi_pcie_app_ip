//-----------------------------------------------------------------------------
//
// (c) Copyright 2010-2011 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : PIO.v
// Version    : 3.3
//
// Description:  Programmed I/O module. Design implements 8 KBytes of programmable
//--              memory space. Host processor can access this memory space using
//--              Memory Read 32 and Memory Write 32 TLPs. Design accepts
//--              1 Double Word (DW) payload length on Memory Write 32 TLP and
//--              responds to 1 DW length Memory Read 32 TLPs with a Completion
//--              with Data TLP (1DW payload).
//--
//--------------------------------------------------------------------------------

`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module PIO #(
  parameter C_DATA_WIDTH = 64,            // RX/TX interface data width

  // Do not override parameters below this line
  parameter KEEP_WIDTH = C_DATA_WIDTH / 8,              // TSTRB width
  parameter TCQ        = 1
)(
  input                         user_clk,
  input                         user_reset,
  input                         user_lnk_up,

  // AXIS
  input                         s_axis_tx_tready,
  output  [C_DATA_WIDTH-1:0]    s_axis_tx_tdata,
  output  [KEEP_WIDTH-1:0]      s_axis_tx_tkeep,
  output                        s_axis_tx_tlast,
  output                        s_axis_tx_tvalid,
  output                        tx_src_dsc,


  input  [C_DATA_WIDTH-1:0]     m_axis_rx_tdata,
  input  [KEEP_WIDTH-1:0]       m_axis_rx_tkeep,
  input                         m_axis_rx_tlast,
  input                         m_axis_rx_tvalid,
  output                        m_axis_rx_tready,
  input    [21:0]               m_axis_rx_tuser,


  input                         cfg_to_turnoff,
  output                        cfg_turnoff_ok,

  input [15:0]                  cfg_completer_id,

  output wire                   rd_en,
  input wire                    rd_done,
  output wire [31:0]            rd_addr,
  output wire [7:0]             rd_be,
  input wire [31:0]             rd_data,

  output wire                   wr_en,
  input wire                    wr_done,
  output wire [31:0]            wr_addr,
  output wire [7:0]             wr_be,
  output wire [31:0]            wr_data,

  input wire  [31:0]            dma_read_addr,
  input wire  [9:0]             dma_read_len,
  input wire                    dma_read_valid,
  output wire                   dma_read_done,
  output wire [7:0]             current_tag,

  // DMA Write Request intf
  input wire [31:0]             dma_write_addr,
  input wire [9:0]              dma_write_len,
  input wire                    dma_write_pending,
  output wire                   dma_write_done,

  // DMA Write Data Stream intf
  input wire [127:0]            dma_write_data,
  input wire                    dma_write_data_valid,
  output wire                   dma_write_data_ready,

  output wire [7:0]             packer_tag,
  output wire [127:0]           packer_dout,
  output wire [3:0]             packer_dout_dwen,
  output wire                   packer_valid,
  output wire                   packer_done
); // synthesis syn_hier = "hard"

  // Local wires
  wire          req_compl;
  wire          req_compl_wd;
  wire          compl_done;
  reg           pio_reset_n;


  assign rd_be = 8'h0F;
  assign rd_en = req_compl;


  always @(posedge user_clk) begin
    if (user_reset)
        pio_reset_n <= #TCQ 1'b0;
    else
        pio_reset_n <= #TCQ user_lnk_up;
  end


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
wire [31:0]     req_addr;


assign packer_tag = req_tag;

// Packer
wire [127:0]  packer_ep_dout;
wire [1:0]    packer_first_dw;
wire          packer_ep_valid;
wire          packer_ep_done;

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

    .compl_done(rd_done),
    .wr_done(wr_done),

    .wr_addr(wr_addr),
    .wr_be(wr_be),
    .wr_data(wr_data),
    .wr_en(wr_en),

    // Packer
    .packer_dout(packer_ep_dout),
    .packer_first_dw(packer_first_dw),
    .packer_valid(packer_ep_valid),
    .packer_done(packer_ep_done)

    );

packer dma_completion_packer (
    .i_clk(user_clk),
    .i_rst(user_reset),

    .din(packer_ep_dout),
    .first_dw(packer_first_dw),
    .valid(packer_ep_valid),
    .done(packer_ep_done),

    .dout(packer_dout),
    .dout_valid(packer_valid),
    .dout_dwen(packer_dout_dwen),
    .dout_done(packer_done)
  );

xilinx_pcie_rx xilinx_pcie_completer_inst (
    .i_clk(user_clk),
    .i_rst(user_reset),

    .s_axis_tx_tready(s_axis_tx_tready),
    .s_axis_tx_tdata(s_axis_tx_tdata),
    .s_axis_tx_tkeep(s_axis_tx_tkeep),
    .s_axis_tx_tlast(s_axis_tx_tlast),
    .s_axis_tx_tvalid(s_axis_tx_tvalid),
    .tx_src_dsc(tx_src_dsc),

    .req_compl(rd_done),
    .req_compl_wd(rd_done),
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
    .rd_addr(rd_addr),
    .rd_data(rd_data),

    // DMA Write Request intf
    .dma_write_addr(dma_write_addr),
    .dma_write_len(dma_write_len),
    .dma_write_pending(dma_write_pending),
    .dma_write_done(dma_write_done),

    // DMA Write Data Stream intf
    .dma_write_data(dma_write_data),
    .dma_write_data_valid(dma_write_data_valid),
    .dma_write_data_ready(dma_write_data_ready),
    
    
    .dma_read_addr(dma_read_addr),
    .dma_read_len(dma_read_len),
    .dma_read_valid(dma_read_valid),
    .dma_read_done(dma_read_done),
    .current_tag(current_tag)
);

  //
  // Turn-Off controller
  //

  PIO_TO_CTRL #(
    .TCQ( TCQ )
  ) PIO_TO_inst  (
    .clk( user_clk ),                       // I
    .rst_n( pio_reset_n ),                  // I

    .req_compl( rd_done ),                // I
    .compl_done( compl_done ),              // I

    .cfg_to_turnoff( cfg_to_turnoff ),      // I
    .cfg_turnoff_ok( cfg_turnoff_ok )       // O
  );


endmodule // PIO
