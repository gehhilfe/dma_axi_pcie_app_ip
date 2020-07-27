module dma_read_arbiter #(
	parameter p_paths = 2
)(
	input wire i_clk,
	input wire i_rst,

	input wire [p_paths*32-1:0] ar_dma_read_addr,
	input wire [p_paths*10-1:0] ar_dma_read_len,
	input wire [p_paths-1:0] 	ar_dma_read_valid,
	output reg [p_paths-1:0] 	ar_dma_done,

	output reg [31:0] 			dma_read_addr,
	output reg [9:0] 			dma_read_len,
	output reg 					dma_valid,
	input wire 					dma_done
);


reg [p_paths-1:0] r_last_path_mask;
reg [p_paths-1:0] r_active_path;

// Output mux
genvar i;
integer j;
generate
	always @(*) begin
		dma_read_addr = ar_dma_read_addr[31:0];
		dma_read_len = ar_dma_read_len[9:0];
		dma_valid = ar_dma_read_valid[0];
		ar_dma_done = 0;

		for (j=0; j<p_paths; j=j+1) begin
			if(r_active_path[j]) begin
				dma_read_addr = ar_dma_read_addr[j*32+:32];
				dma_read_len = ar_dma_read_len[j*10+:10];
				dma_valid = ar_dma_read_valid[j];
				ar_dma_done[j] = dma_done;
			end else begin
				ar_dma_done[j] = 0;
			end
		end
	end
endgenerate


wire [p_paths-1:0] paths_ready = ar_dma_read_valid & r_last_path_mask;
reg [p_paths-1:0] path_sel;
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
	end else begin
		if (|paths_ready == 0) r_last_path_mask <= {p_paths{1'b1}};
		else begin
			if(r_active_path == 0) begin
				r_active_path <= path_sel;
			end else if(dma_done) begin
				r_last_path_mask <= r_last_path_mask | ~path_sel;
				r_active_path <= 0;
			end
		end
	end
end

endmodule