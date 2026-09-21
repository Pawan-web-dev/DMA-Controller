// ============================================================
// File: data_memory.sv
// Purpose: CPU data-memory wrapper
//
// This is the first/simple version for CPU load/store testing.
// It uses byte addressing at the CPU interface and converts the
// address to a 32-bit word index.
//
// Later, when DMA is integrated, the memory interface can be
// extended to support CPU/DMA arbitration or dual-port access.
// ============================================================

module data_memory #(
    parameter int ADDR_WIDTH = 9
) (
    input  logic             clk,

    // CPU memory interface
    input  logic             we,
    input  logic [31:0]      addr,
    input  logic [31:0]      write_data,
    output logic [31:0]      read_data
);

    localparam int DEPTH = (1 << ADDR_WIDTH);

    logic [31:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr[ADDR_WIDTH+1:2]] <= write_data;
        else
            read_data <= mem[addr[ADDR_WIDTH+1:2]];
    end

endmodule
