module dma_error_handler (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       dma_error_in,
    input  logic [3:0] dma_error_code_in,
    input  logic       clear_error,
    output logic       dma_error,
    output logic [3:0] error_code,
    output logic       dma_reset_n
);

    assign dma_reset_n = rst_n;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_error  <= 1'b0;
            error_code <= 4'h0;
        end else if (clear_error) begin
            dma_error  <= 1'b0;
            error_code <= 4'h0;
        end else if (dma_error_in) begin
            dma_error  <= 1'b1;
            error_code <= dma_error_code_in;
        end
    end

endmodule
