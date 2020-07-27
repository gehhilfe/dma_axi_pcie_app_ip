`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/13/2018 07:06:20 PM
// Design Name: 
// Module Name: fifo
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


module fifo #(
    parameter BITS_DEPTH = 8,
    parameter BITS_WIDTH = 32
)
(
    input wire i_clk,
    input wire i_rst,
    
    input wire [BITS_WIDTH-1:0] din,
    input wire wr_en,
    
    output reg [BITS_WIDTH-1:0] dout,
    input wire rd_en,
    
    output wire full,
    output wire empty,

    output wire half_full
    );

reg [BITS_DEPTH:0] read_ptr, write_ptr;
reg [BITS_DEPTH-1:0] counter;

reg [BITS_WIDTH-1:0] mem [0:2**BITS_DEPTH];

assign half_full = counter[BITS_DEPTH-1];

assign empty = counter == 0;
assign full = read_ptr[BITS_DEPTH] != write_ptr[BITS_DEPTH] && read_ptr[BITS_DEPTH-1:0] == write_ptr[BITS_DEPTH-1:0];
    
always @(posedge i_clk) begin
    if (i_rst) begin
        read_ptr <= 0;
        write_ptr <= 0;
        dout <= 0;
        counter <= 0;
    end else begin
        if(wr_en && rd_en && empty) begin
            dout <= din;
        end else begin

            if (wr_en) begin 
                mem[write_ptr[BITS_DEPTH-1:0]] <= din;
                write_ptr <= write_ptr + 1'b1;
            end

            if (rd_en) begin 
                read_ptr <= read_ptr + 1'b1;
                dout <= mem[read_ptr[BITS_DEPTH-1:0]];
            end

            if(wr_en && !rd_en) begin
                counter <= counter + 1;
            end else 
            if(rd_en && !wr_en) begin
                counter <= counter - 1;
            end
        end
    end
end    
endmodule
