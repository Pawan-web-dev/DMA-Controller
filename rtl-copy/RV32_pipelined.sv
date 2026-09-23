

module rv32_pipelined (
    input clk, rst_n, clr,
);

    PC program_counter (.clk(clk), .rst_n(rst_n), .pc_next(), .pc_out());




endmodule