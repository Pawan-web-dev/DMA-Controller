

module I_mem (
	input logic clk,

	input logic [31:0] addr,

	output logic [31:0] instruction	
);

	logic [31:0] mem [512:0];

	always_ff @(posedge clk)
		instruction <= mem[addr];

endmodule
