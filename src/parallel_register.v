// File: parallel_register.v
// Name: Tim Burkert
// Email: burkert.tim@gmail.com
// Date: 25.4.18
// Desc: 	Parallel registers with virtual and physical registers
// 			Physical registers can be read and written by bram interface
// 			Virtual registers can on by read and writes are ignored
//			Lower half of P_REGISTERS_2TON (highest bit 0) are physical registers
//			Upper half are virtual registers

`include "registers.vh"

module parallel_register #(
	)(
		input wire i_clk,
		input wire i_rst_n,

		// Read port
		input wire [31:0] rd_addr,
		output reg [31:0] rd_data,

		// Write port
		input wire [31:0] wr_addr,
		input wire [7:0] wr_be,
		input wire [31:0] wr_data,
		input wire wr_en,

		// memory debug access
		output reg [31:0] debug_mem_addr,
		output reg [31:0] debug_mem_data,
		input wire [31:0] debug_mem_status,
		input wire [31:0] virt_debug_mem_data,

		output reg debug_mem_write_access
	);



// read 
always @(posedge i_clk) begin
	if (i_rst_n) begin
		rd_data <= 32'h0;
	end // i_rst_n
	else begin
		case(rd_addr)
			`REG_DEBUG_MEM_ADDR: rd_data <= debug_mem_addr;
			`REG_DEBUG_MEM_DATA: rd_data <= virt_debug_mem_data;
			`REG_DEBUG_MEM_STATUS: rd_data <= debug_mem_status;
			default: begin
			end
		endcase
	end // else
end

function [31:0] byteEnable;
input [31:0] old;
input [31:0] new;
input [7:0] be;
begin
	byteEnable = old;
	if(be[0]) byteEnable[(0+1)*8-1:0*8] = new[(0+1)*8-1:0*8];
	if(be[1]) byteEnable[(1+1)*8-1:1*8] = new[(1+1)*8-1:1*8];
	if(be[2]) byteEnable[(2+1)*8-1:2*8] = new[(2+1)*8-1:2*8];
	if(be[3]) byteEnable[(3+1)*8-1:3*8] = new[(3+1)*8-1:3*8];
end
endfunction

// write
always @(posedge i_clk) begin
	if (i_rst_n) begin
		debug_mem_write_access <= 0;
	end
	else begin
		debug_mem_write_access <= 0;
		if(wr_en) begin
			case(wr_addr)
				`REG_DEBUG_MEM_ADDR: debug_mem_addr <= byteEnable(debug_mem_addr, wr_data, wr_be);
				`REG_DEBUG_MEM_DATA: begin
					debug_mem_data <= byteEnable(debug_mem_data, wr_data, wr_be);
					debug_mem_write_access <= 1;
				end
				default: begin
				end
			endcase
		end
	end
end

endmodule // parallel_register