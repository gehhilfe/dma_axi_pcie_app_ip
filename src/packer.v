module packer (
    input wire i_clk,
    input wire i_rst,

    input wire [127:0] din,
    input wire [1:0] first_dw,
    input wire [7:0] tag,
    input wire valid,
    input wire done,

    output reg [127:0] dout,
    output reg dout_valid,
    output reg [3:0] dout_dwen,
    output wire dout_done,
    output reg [7:0] dout_tag
);


reg first_valid_after_done;
reg [1:0] start_first_dw;
reg [127:0] scratch;
reg reset_data_out;
reg need_rem;
reg [1:0] rem_dw;
reg [7:0] r_tag;

assign dout_done = reset_data_out;

always @(posedge i_clk) begin
    if(i_rst) begin
        first_valid_after_done <= 1;
        reset_data_out <= 0;
        need_rem <= 0;
        dout_valid <= 0;
    end else begin
        if (valid) begin
            first_valid_after_done <= 0;
        end

        if(done) begin
            first_valid_after_done <= 1;
        end


        scratch <= din;

        if (reset_data_out || (done && !valid)) begin
            dout_valid <= 0;
            reset_data_out <= 0;
        end

        if (valid && first_valid_after_done) begin
            start_first_dw <= first_dw;
            r_tag <= tag;
            case(first_dw)
                2'b00: begin
                    dout <= din;
                    dout_tag <= tag;
                    dout_valid <= 1;
                    dout_dwen <= 4'hF;
                end // 2'b00:
                2'b01: dout[95:0] <= din[127:32];
                2'b10: dout[63:0] <= din[127:64];
                2'b11: dout[31:0] <= din[127:96];
            endcase // first_dw
            if (done) begin
                reset_data_out <= 1;
                dout_valid <= 1;
                case(first_dw)
                2'b01: dout_dwen <= 4'b0111;
                2'b10: dout_dwen <= 4'b0011;
                2'b11: dout_dwen <= 4'b0001;
            endcase 
            end
        end 
        else if(valid && !first_valid_after_done && !done) begin
            dout_valid <= 1;
            dout_tag <= r_tag;
            dout_dwen <= 4'hF;
            case(start_first_dw)
                2'b00: dout <= din;
                
                2'b01: begin
                    dout[127:96] <= din[31:0];
                    if(dout_valid) dout[95:0] <= scratch[127:32];
                end // 2'b01:
                
                2'b10: begin
                    dout[127:64] <= din[63:0];
                    if(dout_valid) dout[63:0] <= scratch[127:64];
                end // 2'b10:

                2'b11: begin
                    dout[127:32] <= din[95:0];
                    if(dout_valid) dout[31:0] <= scratch[127:96];
                end // 2'b11:
            endcase

        end else if (valid && done) begin
            rem_dw <= first_dw;
            dout_tag <= r_tag;
            case({start_first_dw, first_dw})
                4'b0000: begin
                    dout <= din;
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                    reset_data_out <= 1;
                end
                
                4'b0001: begin
                    dout <= din;
                    dout_valid <= 1;
                    dout_dwen <= 4'b0111;
                    reset_data_out <= 1;
                end

                4'b0010: begin
                    dout <= din;
                    dout_valid <= 1;
                    dout_dwen <= 4'b0011;
                    reset_data_out <= 1;
                end

                4'b0011: begin
                    dout <= din;
                    dout_valid <= 1;
                    dout_dwen <= 4'b0001;
                    reset_data_out <= 1;
                end




                4'b0100: begin
                    dout[127:96] <= din[31:0];
                    if(dout_valid) dout[95:0] <= scratch[127:32];
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                    need_rem <= 1;
                end

                4'b0101: begin
                    dout[127:96] <= din[31:0];
                    if(dout_valid) dout[95:0] <= scratch[127:32];
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                    need_rem <= 1;
                end

                4'b0110: begin
                    dout[127:96] <= din[31:0];
                    if(dout_valid) dout[95:0] <= scratch[127:32];
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                    need_rem <= 1;
                end

                4'b0111: begin
                    dout[127:96] <= din[31:0];
                    if(dout_valid) dout[95:0] <= scratch[127:32];
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                    reset_data_out <= 1;
                end



                4'b1000: begin
                    dout[127:64] <= din[63:0];
                    if(dout_valid) dout[63:0] <= scratch[127:64];
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                    need_rem <= 1;
                end

                4'b1001: begin
                    dout[127:64] <= din[63:0];
                    if(dout_valid) dout[63:0] <= scratch[127:64];
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                    need_rem <= 1;
                end

                4'b1010: begin
                    dout[127:64] <= din[63:0];
                    if(dout_valid) dout[63:0] <= scratch[127:64];
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                    reset_data_out <= 1;
                end

                4'b1011: begin
                    dout[95:64] <= din[31:0];
                    if(dout_valid) dout[63:0] <= scratch[127:64];
                    reset_data_out <= 1;
                    dout_valid <= 1;
                    dout_dwen <= 4'b0111;
                end




                4'b1100: begin
                    dout[127:32] <= din[95:0];
                    if(dout_valid) dout[31:0] <= scratch[127:96];
                    need_rem <= 1;
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                end

                4'b1101: begin
                    dout[127:32] <= din[95:0];
                    if(dout_valid) dout[31:0] <= scratch[127:96];
                    reset_data_out <= 1;
                    dout_valid <= 1;
                    dout_dwen <= 4'b1111;
                end

                4'b1110: begin
                    dout[95:32] <= din[63:0];
                    if(dout_valid) dout[31:0] <= scratch[127:96];
                    dout_valid <= 1;
                    dout_dwen <= 4'b0111;
                    reset_data_out <= 1;
                end

                4'b1111: begin
                    dout[63:32] <= din[31:0];
                    if(dout_valid) dout[31:0] <= scratch[127:96];
                    dout_valid <= 1;
                    dout_dwen <= 4'b0011;
                    reset_data_out <= 1;
                end
            endcase
        end else if(need_rem) begin
            need_rem <= 0;
            case ({start_first_dw, rem_dw})

                4'b0100: begin
                    dout[95:0] <= scratch[127:32];
                    dout_dwen <= 4'b0111;
                    reset_data_out <= 1;
                end

                4'b0101: begin
                    dout[63:0] <= scratch[95:32];
                    dout_dwen <= 4'b0011;
                    reset_data_out <= 1;
                end

                4'b0110: begin
                    dout[31:0] <= scratch[63:32];
                    dout_dwen <= 4'b0001;
                    reset_data_out <= 1;
                end


                4'b1000: begin
                    dout[63:0] <= scratch[127:64];
                    dout_dwen <= 4'b0011;
                    reset_data_out <= 1;
                end

                4'b1001: begin
                    dout[31:0] <= scratch[95:64];
                    dout_dwen <= 4'b0001;
                    reset_data_out <= 1;
                end

                4'b1100: begin
                    dout[31:0] <= scratch[127:96];
                    dout_dwen <= 4'b0001;
                    reset_data_out <= 1;
                end
            endcase
        end
    end
end

endmodule