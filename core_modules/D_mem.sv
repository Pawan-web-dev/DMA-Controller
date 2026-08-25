

module D_mem (
	input logic clk,
	input logic we,

	input logic [31:0] addr,
	input logic [31:0] wd,	

	output logic [31:0] data_out
);

	logic [31:0] mem [512:0];

	always_ff @(posedge clk) begin
		if (we)
			mem[addr] <= wd;
		else
			data_out <= mem[addr];
	end

endmodule
