//=============================================================================
// Module      : dma_error_handler
// Project     : RISC-V SoC with DMA Controller
//
// Description : Sticky DMA error storage.
//
// Error codes:
//   1 = Zero-length transfer
//   2 = Unaligned address
//   3 = Memory read error
//   4 = Memory write error
//   5 = Other/interconnect error
//=============================================================================

module dma_error_handler (

    input  logic       clk,
    input  logic       rst_n,

    // Error event from DMA FSM
    input  logic       dma_error_in,
    input  logic [3:0] dma_error_code_in,

    // Software clear
    input  logic       clear_error,

    // Sticky error status
    output logic       dma_error,
    output logic [3:0] error_code,

    // DMA reset indication
    output logic       dma_reset_n
);


    // Reset is passed through to the DMA domain
    assign dma_reset_n = rst_n;


    //=========================================================================
    // Sticky error register
    //=========================================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            dma_error <= 1'b0;
            error_code <= 4'h0;

        end

        else begin

            // Clear has priority
            if (clear_error) begin

                dma_error <= 1'b0;
                error_code <= 4'h0;

            end

            // New error
            else if (dma_error_in) begin

                dma_error <= 1'b1;
                error_code <= dma_error_code_in;

            end

        end

    end

endmodule