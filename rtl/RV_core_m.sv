// ============================================================
// File: RV_core_m.sv   [NEW - top-level multicycle core]
//
// Wraps mc_controller + rv_datapath_mc. This is the module you
// drop into the system: it exposes ONLY a bus port, no memory
// inside it at all.
//
// bus_ready is the single handshake signal the core needs from
// whatever is on the other side: today a trivial SRAM wrapper
// (see tb_top_temp_mem.sv), later a real AXI-Lite/APB/Wishbone
// bridge, and later still an arbiter that may be granting the
// bus to the DMA controller instead - the core doesn't need to
// know which. It just holds state until bus_ready goes high.
// ============================================================

module RV_core_m (
    input  logic        clk,
    input  logic        rst_n,

    // ---- shared system bus port ----
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    input  logic [31:0] bus_rdata,
    output logic        bus_we,
    output logic        bus_req,     // core wants a transaction this cycle
    input  logic        bus_ready    // bus/arbiter/slave: transaction done
);

    logic [6:0] op;
    logic [2:0] funct3;
    logic       funct7b5;
    logic       zero_f;

    logic       ir_write, pcs_write, reg_a_write, reg_b_write;
    logic       alu_out_write, mdr_write;
    logic       alu_src_b_sel;
    logic [2:0] alu_control;
    logic       i_or_d;
    logic [1:0] pc_src;
    logic       pc_write;
    logic       reg_write;
    logic [1:0] result_src;

    mc_controller u_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .op       (op),
        .funct3   (funct3),
        .funct7b5 (funct7b5),
        .zero_f   (zero_f),
        .mem_ready(bus_ready),

        .ir_write     (ir_write),
        .pcs_write    (pcs_write),
        .reg_a_write  (reg_a_write),
        .reg_b_write  (reg_b_write),
        .alu_out_write(alu_out_write),
        .mdr_write    (mdr_write),
        .alu_src_b_sel(alu_src_b_sel),
        .alu_control  (alu_control),
        .i_or_d       (i_or_d),
        .mem_req      (bus_req),
        .mem_we       (bus_we),
        .pc_write     (pc_write),
        .pc_src       (pc_src),
        .reg_write    (reg_write),
        .result_src   (result_src)
    );

    rv_datapath_mc u_dp (
        .clk  (clk),
        .rst_n(rst_n),

        .ir_write     (ir_write),
        .pcs_write    (pcs_write),
        .reg_a_write  (reg_a_write),
        .reg_b_write  (reg_b_write),
        .alu_out_write(alu_out_write),
        .mdr_write    (mdr_write),
        .alu_src_b_sel(alu_src_b_sel),
        .alu_control  (alu_control),
        .i_or_d       (i_or_d),
        .pc_src       (pc_src),
        .pc_write     (pc_write),
        .reg_write    (reg_write),
        .result_src   (result_src),

        .op      (op),
        .funct3  (funct3),
        .funct7b5(funct7b5),
        .zero_f  (zero_f),

        .bus_addr (bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata)
    );

endmodule
