

module reg_file (

	input logic clk,

	input logic we,

	input logic [31:0] wd,
	input logic [4:0] rs_1,
	input logic [4:0] rs_2,
	
	input logic [4:0] rd,

	output logic [31:0] Ra,
	output logic [31:0] Rb


);

	logic [31:0] register [31:0];
	
	always_ff @(posedge clk or negedge clk) begin
		if (clk && we) begin
			register[rd] <= wd;
		end
		else if (~clk) begin
			Ra <= register[rs_1];
			Rb <= register[rs_2];
		end		
	end
endmodule
