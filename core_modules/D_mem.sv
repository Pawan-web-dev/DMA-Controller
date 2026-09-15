// Byte-addressed CPU view, word-indexed storage.
// Combinational read so a single-cycle lw can write back in the same cycle.
module D_mem #(
    parameter int ADDR_WIDTH = 9
) (
    input  logic        clk,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] wd,
    output logic [31:0] data_out
);

    localparam int DEPTH = (1 << ADDR_WIDTH);

    logic [31:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] word_addr;

    assign word_addr = addr[ADDR_WIDTH+1:2];
    assign data_out  = mem[word_addr];

    always_ff @(posedge clk) begin
        if (we)
            mem[word_addr] <= wd;
    end

endmodule
