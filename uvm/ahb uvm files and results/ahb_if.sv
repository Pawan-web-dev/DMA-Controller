`ifndef AHB_IF_SV
`define AHB_IF_SV

interface ahb_if #(
    parameter int ADDR_WIDTH    = 32,
    parameter int DATA_WIDTH    = 32,
    parameter int MAX_BURST_LEN = 16
) (
    input logic HCLK,
    input logic HRESETn
);
    localparam int LEN_WIDTH = $clog2(MAX_BURST_LEN + 1);

    // AHB bus
    logic [ADDR_WIDTH-1:0] HADDR;
    logic [1:0]            HTRANS;
    logic                  HWRITE;
    logic [2:0]            HSIZE;
    logic [2:0]            HBURST;
    logic [DATA_WIDTH-1:0] HWDATA;
    logic [DATA_WIDTH-1:0] HRDATA;
    logic                  HREADYOUT;
    logic                  HRESP_slave;
    logic                  HRESP;

    // Request side
    logic                          req_start;
    logic                          req_write;
    logic [LEN_WIDTH-1:0]          req_burst_len;
    logic [ADDR_WIDTH-1:0]         req_addr;
    logic [DATA_WIDTH-1:0]         req_wdata  [0:MAX_BURST_LEN-1];
    logic [DATA_WIDTH-1:0]         resp_rdata [0:MAX_BURST_LEN-1];
    logic                          req_done;
    logic                          req_error;
    logic                          req_reject;

    // Config / injection
    logic [1:0]                    cfg_wait_states;
    logic                          inject_error;

    assign HRESP = HRESP_slave | inject_error;
endinterface

`endif