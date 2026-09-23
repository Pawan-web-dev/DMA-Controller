// ============================================================
// File: alu_decoder.sv
// FIXED vs original: ALUControl values re-mapped to match the
// corrected ALU.sv encoding, and funct3 cases added for xor
// (100), sll (001), srl (101 without funct7b5 - sra not
// distinguished here, see note below).
//
// LIMITATION: sra (arithmetic right shift) is not distinguished
// from srl - both currently decode to a logical right shift.
// If you need sra, branch on funct7b5 the same way RtypeSub does.
// ============================================================

module aludec(
    input  logic       opb5,
    input  logic [2:0] funct3,
    input  logic       funct7b5,
    input  logic [1:0] ALUOp,

    output logic [2:0] ALUControl
);

    logic RtypeSub;
    assign RtypeSub = funct7b5 & opb5;   // TRUE only for R-type subtract

    always_comb
        case (ALUOp)
            2'b00: ALUControl = 3'b000;  // address calc (lw/sw) -> add
            2'b01: ALUControl = 3'b001;  // beq -> subtract, check zero flag
            default: case (funct3)       // R-type / I-type ALU
                3'b000:  ALUControl = RtypeSub ? 3'b001 : 3'b000; // sub / add, addi
                3'b010:  ALUControl = 3'b101; // slt, slti
                3'b100:  ALUControl = 3'b100; // xor, xori
                3'b110:  ALUControl = 3'b011; // or, ori
                3'b111:  ALUControl = 3'b010; // and, andi
                3'b001:  ALUControl = 3'b110; // sll, slli
                3'b101:  ALUControl = 3'b111; // srl, srli (sra not distinguished)
                default: ALUControl  = 3'b000;
            endcase
        endcase
endmodule
