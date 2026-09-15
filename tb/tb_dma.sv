`timescale 1ns/1ps

module tb_dma;

    logic clk;
    logic rst_n;

    logic        csr_valid;
    logic        csr_write;
    logic [7:0]  csr_addr;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;

    logic        mem_valid;
    logic        mem_write;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        mem_ready;
    logic        mem_error;

    logic       irq;
    logic       busy;
    logic       done;
    logic       error;
    logic [3:0] error_code;

    logic        init_we;
    logic [31:0] init_addr;
    logic [31:0] init_wdata;

    dma_controller dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .csr_valid (csr_valid),
        .csr_write (csr_write),
        .csr_addr  (csr_addr),
        .csr_wdata (csr_wdata),
        .csr_rdata (csr_rdata),
        .mem_valid (mem_valid),
        .mem_write (mem_write),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready),
        .mem_error (mem_error),
        .irq       (irq),
        .busy      (busy),
        .done      (done),
        .error     (error),
        .error_code(error_code)
    );

    dma_test_memory #(.DEPTH(256)) memory (
        .clk       (clk),
        .mem_valid (mem_valid),
        .mem_write (mem_write),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready),
        .mem_error (mem_error),
        .init_we   (init_we),
        .init_addr (init_addr),
        .init_wdata(init_wdata)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic csr_write_reg(input logic [7:0] addr, input logic [31:0] data);
        begin
            @(negedge clk);
            csr_valid = 1'b1;
            csr_write = 1'b1;
            csr_addr  = addr;
            csr_wdata = data;
            @(negedge clk);
            csr_valid = 1'b0;
            csr_write = 1'b0;
            csr_addr  = 8'h00;
            csr_wdata = 32'h0;
        end
    endtask

    task automatic init_memory_word(input logic [31:0] addr, input logic [31:0] data);
        begin
            @(negedge clk);
            init_we    = 1'b1;
            init_addr  = addr;
            init_wdata = data;
            @(negedge clk);
            init_we    = 1'b0;
            init_addr  = 32'h0;
            init_wdata = 32'h0;
        end
    endtask

    task automatic check_word(input integer index, input logic [31:0] expected);
        begin
            if (memory.mem[index] !== expected)
                $error("FAIL mem[%0d] = 0x%08h, expected = 0x%08h", index, memory.mem[index], expected);
            else
                $display("PASS mem[%0d] = 0x%08h", index, memory.mem[index]);
        end
    endtask

    initial begin
        rst_n      = 1'b0;
        csr_valid  = 1'b0;
        csr_write  = 1'b0;
        csr_addr   = 8'h00;
        csr_wdata  = 32'h0;
        init_we    = 1'b0;
        init_addr  = 32'h0;
        init_wdata = 32'h0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        init_memory_word(32'h00000100, 32'h11111111);
        init_memory_word(32'h00000104, 32'h22222222);
        init_memory_word(32'h00000108, 32'h33333333);
        init_memory_word(32'h0000010C, 32'h44444444);

        $display("DMA 4-WORD COPY TEST");

        csr_write_reg(8'h08, 32'h00000100);
        csr_write_reg(8'h0C, 32'h00000200);
        csr_write_reg(8'h10, 32'd4);
        csr_write_reg(8'h14, 32'h00000001);
        csr_write_reg(8'h00, 32'h00000001);

        wait (done == 1'b1);
        @(posedge clk);

        check_word(128, 32'h11111111);
        check_word(129, 32'h22222222);
        check_word(130, 32'h33333333);
        check_word(131, 32'h44444444);

        if (error)
            $error("DMA ERROR! error_code = %0d", error_code);
        else
            $display("PASS: No DMA error");

        if (irq)
            $display("PASS: IRQ asserted");
        else
            $error("FAIL: IRQ not asserted");

        csr_write_reg(8'h00, 32'h00000002);

        $display("DMA TEST COMPLETE");
        #20;
        $finish;
    end

endmodule
