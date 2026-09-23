// ============================================================
// File: adder.sv
// FIXED vs original: the file was named adder.sv but the module
// inside was declared `module adder_pc` - identical to the
// module name in adder_pc.sv. Two files defining the same module
// name is a compile error the moment both are in the same
// project. Renamed this one to `adder` (a plain 2-input adder,
// used here for PCS + immediate -> branch/jump target).
// ============================================================

module adder (
    input  logic [31:0] A,
    input  logic [31:0] B,
    output logic [31:0] Y
);
    assign Y = A + B;
endmodule
