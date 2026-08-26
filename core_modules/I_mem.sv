

module I_mem (
	input logic clk,

	input logic [31:0] addr,

	output logic [31:0] instruction	
);

	logic [31:0] mem [512:0];

  assign instruction = mem[addr];

endmodule


