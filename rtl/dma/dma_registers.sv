//=============================================================================
// Module      : dma_registers
// Project     : RISC-V SoC with DMA Controller
//
// Description : DMA configuration and CPU-visible register interface.
//
// Register Map:
//   0x00 CTRL
//          bit [0] = START
//          bit [1] = CLEAR_DONE
//          bit [2] = CLEAR_ERROR
//
//   0x04 STATUS
//          bit [0] = BUSY
//          bit [1] = DONE
//          bit [2] = ERROR
//          bits[7:4] = ERROR_CODE
//
//   0x08 SRC_ADDR
//          Source byte address
//
//   0x0C DST_ADDR
//          Destination byte address
//
//   0x10 LENGTH
//          Number of 32-bit words to transfer
//
//   0x14 IRQ_EN
//          bit [0] = interrupt enable
//=============================================================================

module dma_registers (

    input  logic        clk,
    input  logic        rst_n,

    // CPU CSR interface
    input  logic        csr_valid,
    input  logic        csr_write,
    input  logic [7:0]  csr_addr,
    input  logic [31:0] csr_wdata,
    output logic [31:0] csr_rdata,

    // DMA status inputs
    input  logic        dma_busy,
    input  logic        dma_done,
    input  logic        dma_error,
    input  logic [3:0]  dma_error_code,

    // Control outputs
    output logic        start_pulse,
    output logic        clear_done,
    output logic        clear_error,

    // Configuration registers
    output logic        irq_enable,
    output logic [31:0] src_addr,
    output logic [31:0] dst_addr,
    output logic [31:0] length_words
);

    //=========================================================================
    // Configuration registers
    //=========================================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            src_addr     <= 32'h00000000;
            dst_addr     <= 32'h00000000;
            length_words <= 32'h00000000;

            irq_enable   <= 1'b0;

            start_pulse  <= 1'b0;
            clear_done   <= 1'b0;
            clear_error  <= 1'b0;

        end
        else begin

            // Default: control signals are one-cycle pulses
            start_pulse <= 1'b0;
            clear_done  <= 1'b0;
            clear_error <= 1'b0;

            if (csr_valid && csr_write) begin

                case (csr_addr)

                    //=========================================================
                    // CTRL
                    //=========================================================
                    8'h00: begin

                        // START
                        if (csr_wdata[0] && !dma_busy) begin
                            start_pulse <= 1'b1;
                        end

                        // CLEAR DONE
                        if (csr_wdata[1]) begin
                            clear_done <= 1'b1;
                        end

                        // CLEAR ERROR
                        if (csr_wdata[2]) begin
                            clear_error <= 1'b1;
                        end

                    end

                    //=========================================================
                    // SRC_ADDR
                    //=========================================================
                    8'h08: begin
                        src_addr <= csr_wdata;
                    end

                    //=========================================================
                    // DST_ADDR
                    //=========================================================
                    8'h0C: begin
                        dst_addr <= csr_wdata;
                    end

                    //=========================================================
                    // LENGTH
                    //=========================================================
                    8'h10: begin
                        length_words <= csr_wdata;
                    end

                    //=========================================================
                    // IRQ ENABLE
                    //=========================================================
                    8'h14: begin
                        irq_enable <= csr_wdata[0];
                    end

                    default: begin
                    end

                endcase

            end

        end

    end


    //=========================================================================
    // CPU read interface
    //=========================================================================

    always_comb begin

        csr_rdata = 32'h00000000;

        if (csr_valid && !csr_write) begin

            case (csr_addr)

                // CTRL
                8'h00: begin
                    csr_rdata = 32'h00000000;
                end

                // STATUS
                8'h04: begin

                    csr_rdata = 32'h00000000;

                    csr_rdata[0]   = dma_busy;
                    csr_rdata[1]   = dma_done;
                    csr_rdata[2]   = dma_error;
                    csr_rdata[7:4] = dma_error_code;

                end

                // SRC
                8'h08: begin
                    csr_rdata = src_addr;
                end

                // DST
                8'h0C: begin
                    csr_rdata = dst_addr;
                end

                // LENGTH
                8'h10: begin
                    csr_rdata = length_words;
                end

                // IRQ ENABLE
                8'h14: begin
                    csr_rdata = {31'h0, irq_enable};
                end

                default: begin
                    csr_rdata = 32'h00000000;
                end

            endcase

        end

    end

endmodule