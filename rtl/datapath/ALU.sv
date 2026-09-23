// ============================================================
// File: ALU.sv
// FIXED vs original:
//  - ALU_select 3'b101 used to be a shift-left, but alu_decoder.sv
//    maps slt/slti to 3'b101 -> the ALU never actually computed
//    slt. Re-encoded so ALUControl is consistent end-to-end.
//  - Shift amount now uses src_B[4:0] (RV32 shifts are 5-bit),
//    not the full 32-bit src_B.
//  - Added xor and srl so the R-type/I-type ALU ops main_decoder
//    already claims to support (funct3 100/001/101) are all
//    actually implemented.
// ============================================================

module ALU (
    input  logic [31:0] src_A,
    input  logic [31:0] src_B,
    input  logic [2:0]  ALU_select,

    output logic [31:0] ALU_out,
    output logic        zero_f
);

    always_comb begin
        case (ALU_select)
            3'b000: ALU_out = src_A + src_B;                              // add / addi
            3'b001: ALU_out = src_A - src_B;                              // sub / beq compare
            3'b010: ALU_out = src_A & src_B;                              // and / andi
            3'b011: ALU_out = src_A | src_B;                              // or  / ori
            3'b100: ALU_out = src_A ^ src_B;                              // xor / xori
            3'b101: ALU_out = {31'b0, $signed(src_A) < $signed(src_B)};   // slt / slti
            3'b110: ALU_out = src_A << src_B[4:0];                        // sll / slli
            3'b111: ALU_out = src_A >> src_B[4:0];                        // srl / srli
            default: ALU_out = 32'b0;
        endcase
        zero_f = (ALU_out == 32'b0);
    end

endmodule
