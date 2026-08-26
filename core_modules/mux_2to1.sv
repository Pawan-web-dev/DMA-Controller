

module mux_2to1 (
	input logic sel,
	input logic [31:0] A,
	input logic [31:0] B,

	output logic [31:0] Y

);
	always_comb begin
		if (sel)
			Y = B;
		else
			Y = A;
	end
endmodule


