module dma_uvm_top;

    import uvm_pkg::*;
    import dma_pkg::*;
    `include "uvm_macros.svh"

    logic clk;

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Interface
    dma_if dma_vif(clk);

    // DUT
    dma_controller dut (
        .clk          (clk),
        .rst_n        (dma_vif.rst_n),

        .csr_valid    (dma_vif.csr_valid),
        .csr_write    (dma_vif.csr_write),
        .csr_addr     (dma_vif.csr_addr),
        .csr_wdata    (dma_vif.csr_wdata),
        .csr_rdata    (dma_vif.csr_rdata),

        .mem_valid    (dma_vif.mem_valid),
        .mem_write    (dma_vif.mem_write),
        .mem_addr     (dma_vif.mem_addr),
        .mem_wdata    (dma_vif.mem_wdata),
        .mem_rdata    (dma_vif.mem_rdata),
        .mem_ready    (dma_vif.mem_ready),
        .mem_error    (dma_vif.mem_error),

        .irq          (dma_vif.irq),
        .busy         (dma_vif.busy),
        .done         (dma_vif.done),
        .error        (dma_vif.error),
        .error_code   (dma_vif.error_code)
    );

    // Give virtual interface to UVM components
    initial begin
        uvm_config_db#(virtual dma_if)::set(
            null,
            "*",
            "vif",
            dma_vif
        );

        run_test("dma_test");
    end

endmodule