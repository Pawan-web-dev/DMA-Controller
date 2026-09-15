module dma_controller (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        csr_valid,
    input  logic        csr_write,
    input  logic [7:0]  csr_addr,
    input  logic [31:0] csr_wdata,
    output logic [31:0] csr_rdata,
    output logic        mem_valid,
    output logic        mem_write,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    input  logic        mem_ready,
    input  logic        mem_error,
    output logic        irq,
    output logic        busy,
    output logic        done,
    output logic        error,
    output logic [3:0]  error_code
);

    logic        start_pulse;
    logic        clear_done;
    logic        clear_error;
    logic        irq_enable;
    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [31:0] length_words;
    logic        done_event;
    logic        error_event;
    logic [3:0]  fsm_error_code;
    logic        done_status;
    logic        sticky_error;
    logic [3:0]  sticky_error_code;

    dma_registers u_dma_registers (
        .clk           (clk),
        .rst_n         (rst_n),
        .csr_valid     (csr_valid),
        .csr_write     (csr_write),
        .csr_addr      (csr_addr),
        .csr_wdata     (csr_wdata),
        .csr_rdata     (csr_rdata),
        .dma_busy      (busy),
        .dma_done      (done_status),
        .dma_error     (sticky_error),
        .dma_error_code(sticky_error_code),
        .start_pulse   (start_pulse),
        .clear_done    (clear_done),
        .clear_error   (clear_error),
        .irq_enable    (irq_enable),
        .src_addr      (src_addr),
        .dst_addr      (dst_addr),
        .length_words  (length_words)
    );

    dma_fsm u_dma_fsm (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start_pulse),
        .cfg_src_addr    (src_addr),
        .cfg_dst_addr    (dst_addr),
        .cfg_length_words(length_words),
        .busy            (busy),
        .done_event      (done_event),
        .error_event     (error_event),
        .error_code      (fsm_error_code),
        .mem_valid       (mem_valid),
        .mem_write       (mem_write),
        .mem_addr        (mem_addr),
        .mem_wdata       (mem_wdata),
        .mem_rdata       (mem_rdata),
        .mem_ready       (mem_ready),
        .mem_error       (mem_error)
    );

    dma_error_handler u_dma_error_handler (
        .clk              (clk),
        .rst_n            (rst_n),
        .dma_error_in     (error_event),
        .dma_error_code_in(fsm_error_code),
        .clear_error      (clear_error),
        .dma_error        (sticky_error),
        .error_code       (sticky_error_code),
        .dma_reset_n      ()
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            done_status <= 1'b0;
        else if (clear_done)
            done_status <= 1'b0;
        else if (done_event)
            done_status <= 1'b1;
    end

    assign done       = done_status;
    assign error      = sticky_error;
    assign error_code = sticky_error_code;
    assign irq        = irq_enable && (done_status || sticky_error);

endmodule
