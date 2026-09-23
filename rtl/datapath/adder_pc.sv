// ============================================================
// File: adder_pc.sv
// FIXED vs original: constant was `31'd4` (31-bit) added to a
// 32-bit signal. It happened to work by luck (zero-extension),
// but the width mismatch is exactly the kind of thing that turns
// into a real bug the moment someone edits this file. Now 32'd4.
// ============================================================

module adder_pc (
    input  logic [31:0] A,
    output logic [31:0] Y
);
    assign Y = A + 32'd4;
endmodule
