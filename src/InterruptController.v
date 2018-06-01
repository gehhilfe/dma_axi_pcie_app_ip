module InterruptController (
	input wire i_clk,
	input wire i_rst,

    // Interrupt output
    output reg cfg_interrupt,
    output reg [7:0] cfg_interrupt_di,
    input wire cfg_interrupt_rdy,

    // Interrupt input
    input wire int_valid,
    input wire [7:0] int_vector,
    output reg int_done
);


always @(posedge i_clk) begin
	if (i_rst) begin
		cfg_interrupt <= 0;
		int_done <= 0;
	end
	else begin
		if(int_done) begin
			int_done <= 0;
		end else if(cfg_interrupt && cfg_interrupt_rdy) begin
			cfg_interrupt <= 0;
			int_done <= 1;
		end else if(int_valid) begin
			cfg_interrupt <= 1;
			cfg_interrupt_di <= int_vector;
		end 
	end
end

endmodule