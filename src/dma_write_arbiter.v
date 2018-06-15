module dma_write_arbiter #(
	parameter p_paths = 2
)(
	input wire i_clk,
	input wire i_rst,

	input wire [p_paths*32-1:0] ar_dma_write_addr,
	input wire [p_paths*10-1:0] ar_dma_write_len,
	input wire [p_paths-1:0] 	ar_dma_write_pending,
	output reg [p_paths-1:0] 	ar_dma_write_done,

	input wire [p_paths*128-1:0] ar_dma_write_data,
  	input wire [p_paths-1:0]     ar_dma_write_data_valid,
  	output reg [p_paths-1:0]     ar_dma_write_data_ready,


	output reg [31:0] 			dma_write_addr,
	output reg [9:0] 			dma_write_len,
	output reg 					dma_write_pending,
	input wire 					dma_write_done,

	output reg 					dma_write_data_valid,
	output reg [127:0] 			dma_write_data,
	input wire 					dma_write_data_ready
);


(* dont_touch = "true" *) reg [p_paths-1:0] r_last_path_mask;
(* dont_touch = "true" *) reg [p_paths-1:0] r_active_path;
(* dont_touch = "true" *) reg [7:0] r_dma_write_cycles;

// Output mux
genvar i;
integer j;
generate
	always @(*) begin
		dma_write_addr = ar_dma_write_addr[31:0];
		dma_write_len = ar_dma_write_len[9:0];
		dma_write_pending = ar_dma_write_pending[0];
		ar_dma_write_done = 0;

		dma_write_data = ar_dma_write_data[127:0];
		dma_write_data_valid = ar_dma_write_data_valid[0];
		ar_dma_write_data_ready = 0;

		for (j=0; j<p_paths; j=j+1) begin
			if(r_active_path[j]) begin
				dma_write_addr = ar_dma_write_addr[j*32+:32];
				dma_write_len = ar_dma_write_len[j*10+:10];
				dma_write_pending = ar_dma_write_pending[j];
				ar_dma_write_done[j] = dma_write_done;

				dma_write_data = ar_dma_write_data[j*128+:128];
				dma_write_data_valid = ar_dma_write_data_valid[j];
				ar_dma_write_data_ready[j] = dma_write_data_ready;
			end else begin
				ar_dma_write_done[j] = 0;
				ar_dma_write_data_ready[j] = 0;
			end
		end
	end
endgenerate


wire [p_paths-1:0] paths_ready = ar_dma_write_pending & r_last_path_mask;
reg [p_paths-1:0] path_sel;

reg r_was_done;
generate
    for (i=0; i<p_paths; i=i+1) begin
        reg all_null;
        always @(*) begin
            all_null = paths_ready[i];
            for (j=0; j<i;j=j+1) begin
                if(paths_ready[j])
                    all_null = 0;
            end
        end

        always @(*) begin
            path_sel[i] = all_null;
        end
    end
endgenerate

localparam
	lp_state_bits = 32,
	lp_state_idle = 0;

always @(posedge i_clk) begin
	if (i_rst) begin
		r_last_path_mask <= {p_paths{1'b1}};
		r_active_path <= 0;
		r_dma_write_cycles <= 0;
		r_was_done <= 0;
	end else begin
		if (|paths_ready == 0) r_last_path_mask <= {p_paths{1'b1}};
		
		if(r_active_path == 0) begin
			r_active_path <= path_sel;
			r_last_path_mask <= r_last_path_mask & ~path_sel;
			r_was_done <= 0;
		end else if(dma_write_done) begin
			r_dma_write_cycles <= dma_write_len[9:2]-2;
			r_was_done <= 1;
		end else if(r_dma_write_cycles == 0 && r_was_done) begin
			r_active_path <= path_sel;
		end

		if(r_dma_write_cycles != 0 && dma_write_data_valid && dma_write_data_ready) r_dma_write_cycles <= r_dma_write_cycles - 1'b1;
	end
end

endmodule