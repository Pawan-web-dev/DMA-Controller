

module D_mem (
	input logic clk,
	input logic we,

	input logic [31:0] addr,
	input logic [31:0] wd,	

	output logic [31:0] data_out
);

	logic [31:0] mem [512:0];

    assign data_out = mem[addr];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= wd;
    end

endmodule
