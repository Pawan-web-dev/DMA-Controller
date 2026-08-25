

module adder_pc (
	input logic [31:0] A,
    input logic [31:0] B,
	
	output logic [31:0] Y
);
	assign Y = A + B;
endmodule
