// Byte-addressed CPU view, word-indexed ROM/RAM.
// Combinational read for a single-cycle core (clk kept for a stable interface).
module I_mem #(
    parameter int ADDR_WIDTH = 9
) (
    input  logic        clk,
    input  logic [31:0] addr,
    output logic [31:0] instruction
);

    localparam int DEPTH = (1 << ADDR_WIDTH);

    logic [31:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] word_addr;

    assign word_addr   = addr[ADDR_WIDTH+1:2];
    assign instruction = mem[word_addr];

    // clk unused: instruction memory is combinational in this single-cycle core
    logic unused_clk;
    assign unused_clk = clk;

endmodule
