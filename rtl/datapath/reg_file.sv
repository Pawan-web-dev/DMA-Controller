// ============================================================
// File: reg_file.sv
// FIXED vs original:
//  - `always_ff @(posedge clk or negedge clk)` is not valid,
//    synthesizable hardware - you cannot trigger on both edges
//    of the same clock in an always_ff. It happened to simulate
//    something, but it did not describe a real register file.
//  - x0 was never hardwired to zero (writes to x0 were allowed,
//    reads of x0 just returned whatever was stored there) -
//    required behavior in RV32I.
//  - Reads are now plain combinational (asynchronous), which is
//    what the rest of the datapath (and the multicycle design)
//    assumes: Ra/Rb reflect rs_1/rs_2 immediately, no clock edge
//    needed to "see" a register value.
// ============================================================

module reg_file (
    input  logic        clk,
    input  logic        we,
    input  logic [31:0] wd,
    input  logic [4:0]  rs_1,
    input  logic [4:0]  rs_2,
    input  logic [4:0]  rd,

    output logic [31:0] Ra,
    output logic [31:0] Rb
);

    logic [31:0] register [31:0];

    // synchronous write, x0 is never writable
    always_ff @(posedge clk) begin
        if (we && (rd != 5'b0))
            register[rd] <= wd;
    end

    // combinational (asynchronous) read, x0 hardwired to 0
    assign Ra = (rs_1 == 5'b0) ? 32'b0 : register[rs_1];
    assign Rb = (rs_2 == 5'b0) ? 32'b0 : register[rs_2];

endmodule
