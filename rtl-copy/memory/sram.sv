// ============================================================
// File: sram.sv
// Purpose: Generic synchronous single-port SRAM
// Reusable memory IP
// ============================================================

module sram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 9
) (
    input  logic                  clk,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] write_data,
    output logic [DATA_WIDTH-1:0] read_data
);

    localparam int DEPTH = (1 << ADDR_WIDTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= write_data;
        else
            read_data <= mem[addr];
    end

endmodule
