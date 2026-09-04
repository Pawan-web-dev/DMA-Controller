module dma_test_memory #(
    parameter int DEPTH = 256
)(
    input  logic        clk,

    // DMA memory interface
    input  logic        mem_valid,
    input  logic        mem_write,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    output logic [31:0] mem_rdata,
    output logic        mem_ready,
    output logic        mem_error,

    // Testbench initialization interface
    input  logic        init_we,
    input  logic [31:0] init_addr,
    input  logic [31:0] init_wdata
);

    logic [31:0] mem [0:DEPTH-1];

    logic [31:0] mem_index;

    assign mem_index = mem_addr >> 2;


    //============================================================
    // Read / ready / error
    //============================================================
    always_comb begin

        mem_rdata = 32'h00000000;
        mem_ready = 1'b0;
        mem_error = 1'b0;

        if (mem_valid) begin

            mem_ready = 1'b1;

            if ((mem_addr[1:0] != 2'b00) ||
                (mem_index >= DEPTH)) begin

                mem_error = 1'b1;

            end
            else if (!mem_write) begin

                mem_rdata = mem[mem_index];

            end

        end

    end


    //============================================================
    // ONLY this block writes the memory array
    //============================================================
    always_ff @(posedge clk) begin

        // Testbench initialization
        if (init_we) begin

            if ((init_addr[1:0] == 2'b00) &&
                ((init_addr >> 2) < DEPTH)) begin

                mem[init_addr >> 2] <= init_wdata;

            end

        end

        // DMA write
        else if (mem_valid &&
                 mem_write &&
                 mem_ready &&
                 !mem_error) begin

            mem[mem_index] <= mem_wdata;

        end

    end

endmodule