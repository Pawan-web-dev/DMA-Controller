//=============================================================================
// Module      : dma_controller
// Project     : RISC-V SoC with DMA Controller
//
// Description : Top-level DMA IP.
//
// CPU side:
//   Memory-mapped register interface.
//
// Memory side:
//   DMA master interface.
//
// Register map:
//   0x00 CTRL
//   0x04 STATUS
//   0x08 SRC
//   0x0C DST
//   0x10 LENGTH
//   0x14 IRQ_ENABLE
//=============================================================================

module dma_controller (

    input  logic        clk,
    input  logic        rst_n,

    //=========================================================================
    // CPU / CSR interface
    //=========================================================================

    input  logic        csr_valid,
    input  logic        csr_write,
    input  logic [7:0]  csr_addr,
    input  logic [31:0] csr_wdata,

    output logic [31:0] csr_rdata,


    //=========================================================================
    // DMA memory master interface
    //=========================================================================

    output logic        mem_valid,
    output logic        mem_write,

    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,

    input  logic [31:0] mem_rdata,
    input  logic        mem_ready,
    input  logic        mem_error,


    //=========================================================================
    // DMA status / interrupt
    //=========================================================================

    output logic        irq,

    output logic        busy,
    output logic        done,

    output logic        error,
    output logic [3:0]  error_code

);


    //=========================================================================
    // Register block signals
    //=========================================================================

    logic        start_pulse;
    logic        clear_done;
    logic        clear_error;

    logic        irq_enable;

    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [31:0] length_words;


    //=========================================================================
    // FSM signals
    //=========================================================================

    logic        done_event;
    logic        error_event;

    logic [3:0]  fsm_error_code;


    //=========================================================================
    // Sticky DONE
    //=========================================================================

    logic done_status;


    //=========================================================================
    // Sticky ERROR
    //=========================================================================

    logic sticky_error;
    logic [3:0] sticky_error_code;


    //=========================================================================
    // DMA REGISTER BLOCK
    //=========================================================================

    dma_registers u_dma_registers (

        .clk            (clk),
        .rst_n          (rst_n),

        .csr_valid      (csr_valid),
        .csr_write      (csr_write),
        .csr_addr       (csr_addr),
        .csr_wdata      (csr_wdata),
        .csr_rdata      (csr_rdata),

        .dma_busy       (busy),
        .dma_done       (done_status),
        .dma_error      (sticky_error),
        .dma_error_code (sticky_error_code),

        .start_pulse    (start_pulse),
        .clear_done     (clear_done),
        .clear_error    (clear_error),

        .irq_enable     (irq_enable),

        .src_addr       (src_addr),
        .dst_addr       (dst_addr),
        .length_words   (length_words)

    );


    //=========================================================================
    // DMA FSM
    //=========================================================================

    dma_fsm u_dma_fsm (

        .clk              (clk),
        .rst_n            (rst_n),

        .start            (start_pulse),

        .cfg_src_addr     (src_addr),
        .cfg_dst_addr     (dst_addr),
        .cfg_length_words (length_words),

        .busy             (busy),

        .done_event       (done_event),

        .error_event      (error_event),
        .error_code       (fsm_error_code),

        .mem_valid        (mem_valid),
        .mem_write        (mem_write),

        .mem_addr         (mem_addr),
        .mem_wdata        (mem_wdata),

        .mem_rdata        (mem_rdata),
        .mem_ready        (mem_ready),
        .mem_error        (mem_error)

    );


    //=========================================================================
    // ERROR HANDLER
    //=========================================================================

    dma_error_handler u_dma_error_handler (

        .clk               (clk),
        .rst_n             (rst_n),

        .dma_error_in      (error_event),
        .dma_error_code_in (fsm_error_code),

        .clear_error       (clear_error),

        .dma_error         (sticky_error),
        .error_code        (sticky_error_code),

        .dma_reset_n       ()

    );


    //=========================================================================
    // DONE STATUS
    //
    // DONE is sticky.
    //
    // It becomes 1 after a successful transfer and remains 1 until:
    //
    //   1. CPU writes CLEAR_DONE
    //   2. Reset occurs
    //=========================================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            done_status <= 1'b0;

        end

        else begin

            if (clear_done) begin

                done_status <= 1'b0;

            end

            else if (done_event) begin

                done_status <= 1'b1;

            end

        end

    end


    //=========================================================================
    // External status
    //=========================================================================

    always_comb begin

        done       = done_status;

        error      = sticky_error;

        error_code = sticky_error_code;

    end


    //=========================================================================
    // INTERRUPT
    //
    // Interrupt is generated when:
    //
    //   IRQ enabled AND
    //   DMA done OR DMA error
    //=========================================================================

    always_comb begin

        irq = irq_enable && (done_status || sticky_error);

    end

endmodule