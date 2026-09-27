interface dma_if(input logic clk);

    //============================================================
    // Reset
    //============================================================
    logic rst_n;

    //============================================================
    // CPU / CSR interface
    //============================================================
    logic        csr_valid;
    logic        csr_write;
    logic [7:0]  csr_addr;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;

    //============================================================
    // DMA memory master interface
    //============================================================
    logic        mem_valid;
    logic        mem_write;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;

    logic [31:0] mem_rdata;
    logic        mem_ready;
    logic        mem_error;

    //============================================================
    // DMA status
    //============================================================
    logic        irq;
    logic        busy;
    logic        done;
    logic        error;
    logic [3:0]  error_code;


    //============================================================
    // Driver
    // Driver drives:
    //   - reset
    //   - CSR inputs
    //   - memory response
    //============================================================
    modport DRIVER (
        input  clk,

        output rst_n,

        output csr_valid,
        output csr_write,
        output csr_addr,
        output csr_wdata,

        input  csr_rdata,

        input  mem_valid,
        input  mem_write,
        input  mem_addr,
        input  mem_wdata,

        output mem_rdata,
        output mem_ready,
        output mem_error,

        input irq,
        input busy,
        input done,
        input error,
        input error_code
    );


    //============================================================
    // Monitor
    // Monitor observes everything.
    //============================================================
    modport MONITOR (
        input clk,
        input rst_n,

        input csr_valid,
        input csr_write,
        input csr_addr,
        input csr_wdata,
        input csr_rdata,

        input mem_valid,
        input mem_write,
        input mem_addr,
        input mem_wdata,
        input mem_rdata,
        input mem_ready,
        input mem_error,

        input irq,
        input busy,
        input done,
        input error,
        input error_code
    );

endinterface