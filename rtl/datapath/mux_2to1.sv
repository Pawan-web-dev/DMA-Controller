// ============================================================
// File: mux_2to1.sv
// FIXED vs original: the file was named mux_2to1.sv but the
// module inside was declared `module mux_3to1` (1-bit sel, 2
// data inputs) - the exact same module name as the *actual*
// 3-to-1 mux in mux_3to1.sv (2-bit sel, 3 data inputs). Same
// duplicate-name problem as adder.sv/adder_pc.sv. Renamed to
// match the file and its real function.
// ============================================================

module mux_2to1 (
    input  logic        sel,
    input  logic [31:0] A,
    input  logic [31:0] B,
    output logic [31:0] Y
);
    assign Y = sel ? B : A;
endmodule
