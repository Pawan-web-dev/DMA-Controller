

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
	
    always_ff @(posedge clk) begin
        if (we && rd != 5'd0)
            register[rd] <= wd;
    end

    assign Ra = (rs_1 == 5'd0) ? 32'h0 : register[rs_1];
    assign Rb = (rs_2 == 5'd0) ? 32'h0 : register[rs_2];
endmodule


