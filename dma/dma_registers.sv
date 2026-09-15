module dma_registers (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        csr_valid,
    input  logic        csr_write,
    input  logic [7:0]  csr_addr,
    input  logic [31:0] csr_wdata,
    output logic [31:0] csr_rdata,
    input  logic        dma_busy,
    input  logic        dma_done,
    input  logic        dma_error,
    input  logic [3:0]  dma_error_code,
    output logic        start_pulse,
    output logic        clear_done,
    output logic        clear_error,
    output logic        irq_enable,
    output logic [31:0] src_addr,
    output logic [31:0] dst_addr,
    output logic [31:0] length_words
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_addr     <= 32'h0;
            dst_addr     <= 32'h0;
            length_words <= 32'h0;
            irq_enable   <= 1'b0;
            start_pulse  <= 1'b0;
            clear_done   <= 1'b0;
            clear_error  <= 1'b0;
        end else begin
            start_pulse <= 1'b0;
            clear_done  <= 1'b0;
            clear_error <= 1'b0;

            if (csr_valid && csr_write) begin
                unique case (csr_addr)
                    8'h00: begin
                        if (csr_wdata[0] && !dma_busy)
                            start_pulse <= 1'b1;
                        if (csr_wdata[1])
                            clear_done <= 1'b1;
                        if (csr_wdata[2])
                            clear_error <= 1'b1;
                    end
                    8'h08: src_addr     <= csr_wdata;
                    8'h0C: dst_addr     <= csr_wdata;
                    8'h10: length_words <= csr_wdata;
                    8'h14: irq_enable   <= csr_wdata[0];
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        csr_rdata = 32'h0;
        if (csr_valid && !csr_write) begin
            unique case (csr_addr)
                8'h00: csr_rdata = 32'h0;
                8'h04: begin
                    csr_rdata[0]   = dma_busy;
                    csr_rdata[1]   = dma_done;
                    csr_rdata[2]   = dma_error;
                    csr_rdata[7:4] = dma_error_code;
                end
                8'h08: csr_rdata = src_addr;
                8'h0C: csr_rdata = dst_addr;
                8'h10: csr_rdata = length_words;
                8'h14: csr_rdata = {31'h0, irq_enable};
                default: csr_rdata = 32'h0;
            endcase
        end
    end

endmodule
