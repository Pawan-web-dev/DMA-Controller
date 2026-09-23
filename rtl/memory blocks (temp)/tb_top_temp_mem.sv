// ============================================================
// File: tb_top_temp_mem.sv   [NEW - TEMPORARY, simulation only]
//
// Wires RV_core_m straight to a single data_memory instance so
// you can simulate/verify the core before the real system bus,
// arbiter, and DMA controller exist. This is exactly the
// "temporary" use of the existing memory modules you asked
// about - NOT the final SoC. Delete/replace this once the real
// bus + arbiter + DMA are wired up; memory belongs outside the
// core, on the shared bus, per the architecture discussed.
//
// This also does NOT model instruction vs. data separately -
// everything (fetch and load/store) goes through the one
// data_memory instance, matching the shared/von-Neumann-style
// bus we've been designing. Preload instructions into
// data_memory's array (or add a $readmemh) to actually run code.
//
// data_memory has a fixed 1-cycle latency (always_ff, result
// available the cycle after the request). bus_ready here is
// just "a request was issued last cycle" - a stand-in for a real
// bus ack until this is replaced by an actual bus/arbiter.
// ============================================================

module tb_top_temp_mem (
    input logic clk,
    input logic rst_n
);

    logic [31:0] bus_addr, bus_wdata, bus_rdata;
    logic        bus_we, bus_req, bus_ready;

    RV_core_m u_core (
        .clk      (clk),
        .rst_n    (rst_n),
        .bus_addr (bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_we   (bus_we),
        .bus_req  (bus_req),
        .bus_ready(bus_ready)
    );

    always_ff @(posedge clk or negedge rst_n)
        if (~rst_n) bus_ready <= 1'b0;
        else        bus_ready <= bus_req;

    data_memory #(.ADDR_WIDTH(9)) u_mem (
        .clk       (clk),
        .we        (bus_we & bus_req),
        .addr      (bus_addr),
        .write_data(bus_wdata),
        .read_data (bus_rdata)
    );

endmodule
