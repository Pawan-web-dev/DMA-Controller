module ALU (
    input  logic [31:0] src_A,
    input  logic [31:0] src_B,
    input  logic [2:0]  ALU_select,
    output logic [31:0] ALU_out,
    output logic        zero_f
);

    always_comb begin
        unique case (ALU_select)
            3'b000:  ALU_out = src_A + src_B;
            3'b001:  ALU_out = src_A - src_B;
            3'b010:  ALU_out = src_A & src_B;
            3'b011:  ALU_out = src_A | src_B;
            3'b100:  ALU_out = src_A ^ src_B;
            3'b101:  ALU_out = ($signed(src_A) < $signed(src_B)) ? 32'd1 : 32'd0;
            default: ALU_out = 32'h0000_0000;
        endcase
        zero_f = (ALU_out == 32'h0);
    end

endmodule
