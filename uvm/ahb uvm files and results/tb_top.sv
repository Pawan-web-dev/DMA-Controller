`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import ahb_pkg::*;
    `include "uvm_macros.svh"

    localparam int ADDR_WIDTH    = 32;
    localparam int DATA_WIDTH    = 32;
    localparam int MAX_BURST_LEN = 16;
    localparam int FIFO_DEPTH    = 4;
    localparam time CLK_PERIOD   = 10ns;

    logic HCLK;
    logic HRESETn;

    initial HCLK = 1'b0;
    always #(CLK_PERIOD/2) HCLK = ~HCLK;

    ahb_if #(
        .ADDR_WIDTH   (ADDR_WIDTH),
        .DATA_WIDTH   (DATA_WIDTH),
        .MAX_BURST_LEN(MAX_BURST_LEN)
    ) vif (
        .HCLK   (HCLK),
        .HRESETn(HRESETn)
    );

    ahb_master #(
        .ADDR_WIDTH   (ADDR_WIDTH),
        .DATA_WIDTH   (DATA_WIDTH),
        .MAX_BURST_LEN(MAX_BURST_LEN)
    ) u_master (
        .HCLK(HCLK), .HRESETn(HRESETn), .HREADY(vif.HREADYOUT),
        .HRDATA(vif.HRDATA), .HRESP(vif.HRESP),
        .HADDR(vif.HADDR), .HTRANS(vif.HTRANS), .HWRITE(vif.HWRITE),
        .HSIZE(vif.HSIZE), .HBURST(vif.HBURST), .HWDATA(vif.HWDATA),
        .req_start(vif.req_start), .req_write(vif.req_write),
        .req_burst_len(vif.req_burst_len), .req_addr(vif.req_addr),
        .req_wdata(vif.req_wdata), .resp_rdata(vif.resp_rdata),
        .req_done(vif.req_done), .req_error(vif.req_error),
        .req_reject(vif.req_reject)
    );

    ahb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_slave (
        .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(1'b1),
        .HADDR(vif.HADDR), .HTRANS(vif.HTRANS), .HWRITE(vif.HWRITE),
        .HSIZE(vif.HSIZE), .HBURST(vif.HBURST), .HWDATA(vif.HWDATA),
        .HREADY(vif.HREADYOUT), .HRDATA(vif.HRDATA),
        .HREADYOUT(vif.HREADYOUT), .HRESP(vif.HRESP_slave),
        .cfg_wait_states(vif.cfg_wait_states)
    );

    initial begin
        HRESETn             = 1'b0;
        vif.cfg_wait_states = 2'd0;
        vif.inject_error    = 1'b0;
        vif.req_start       = 1'b0;
        vif.req_write       = 1'b0;
        vif.req_burst_len   = '0;
        vif.req_addr        = '0;
        repeat (5) @(posedge HCLK);
        HRESETn = 1'b1;
        @(negedge HCLK);
    end

    initial begin
        uvm_config_db#(virtual ahb_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        #(CLK_PERIOD * 20000);
        `uvm_fatal("TB", "testbench timeout")
    end

endmodule