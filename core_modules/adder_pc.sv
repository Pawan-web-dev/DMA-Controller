// PC + 4. Uses a 32-bit constant (not 31'd4).
module adder_pc (
    input  logic [31:0] A,
    output logic [31:0] Y
);
    assign Y = A + 32'd4;
endmodule
