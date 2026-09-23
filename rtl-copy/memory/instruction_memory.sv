// ============================================================
// File: instruction_memory.sv
// Purpose: Instruction memory for RV32I CPU
//
// RV32 uses byte addresses.
// Each instruction is 32 bits = 4 bytes.
// Therefore addr[31:2] is used as the word index.
// ============================================================

module instruction_memory #(
    parameter int ADDR_WIDTH = 9
) (
    input  logic             clk,
    input  logic [31:0]      addr,
    output logic [31:0]      instruction
);

    localparam int DEPTH = (1 << ADDR_WIDTH);

    logic [31:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        instruction <= mem[addr[ADDR_WIDTH+1:2]];
    end

endmodule
