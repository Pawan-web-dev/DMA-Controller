

module adder_pc (
	input logic [31:0] A,
	
	output logic [31:0] Y
);
	assign Y = A + 31'd4;
endmodule
