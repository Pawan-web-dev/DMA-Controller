// ============================================================
// File: mux_3to1.sv
// FIXED vs original: default branch assigned `31'bx` (31-bit) to
// a 32-bit output. Minor, but same class of width bug as
// adder_pc.sv - fixed to 32'bx.
// ============================================================

module mux_3to1 (
    input  logic [1:0]  sel,
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [31:0] C,

    output logic [31:0] Y
);
    always_comb begin
        case (sel)
            2'b00: Y = A;
            2'b01: Y = B;
            2'b10: Y = C;
            default: Y = 32'bx;
        endcase
    end
endmodule
