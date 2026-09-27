`ifndef AHB_SVA_SV
`define AHB_SVA_SV

module ahb_master_sva #(
    parameter int ADDR_WIDTH    = 32,
    parameter int DATA_WIDTH    = 32,
    parameter int MAX_BURST_LEN = 128
) (
    input logic HCLK,
    input logic HRESETn,
    input logic HREADY,
    input logic [ADDR_WIDTH-1:0] HADDR,
    input logic [1:0]            HTRANS,
    input logic                  HWRITE,
    input logic [2:0]            HSIZE,
    input logic [2:0]            HBURST,
    input logic [DATA_WIDTH-1:0] HWDATA,
    input logic [ADDR_WIDTH-1:0] req_addr,
    input logic                  req_write,
    input logic                  req_start,
    input logic                  req_done,
    input logic                  req_error,
    input logic                  req_reject
);
    default clocking cb @(posedge HCLK); endclocking
    default disable iff (!HRESETn);

    // ---- Continuous (silent on PASS, loud on FAIL) ----
    a_htrans_valid: assert property (HTRANS inside {2'b00, 2'b10, 2'b11})
        else $error("[%0t] SVA FAIL: a_htrans_valid (HTRANS=%b)", $time, HTRANS);

    a_stable_when_stalled: assert property (
        !HREADY |=> ($stable(HADDR)  && $stable(HTRANS) &&
                     $stable(HWRITE) && $stable(HSIZE)  &&
                     $stable(HBURST) && $stable(HWDATA))
    ) else $error("[%0t] SVA FAIL: a_stable_when_stalled (HREADY low but signals changed)", $time);

    a_burst_attrs_stable: assert property (
        HTRANS == 2'b11 |=> ($stable(HBURST) && $stable(HSIZE) && $stable(HWRITE))
    ) else $error("[%0t] SVA FAIL: a_burst_attrs_stable", $time);

    // ---- Sparse (PASS and FAIL both visible) ----
    a_addr_captured: assert property (
        (req_start && (HTRANS == 2'b00)) |=>
        (HTRANS == 2'b10 && HADDR == $past(req_addr) &&
                           HWRITE == $past(req_write))
    ) $display("[%0t] SVA PASS: a_addr_captured  (HADDR=%08h HWRITE=%b)",
               $time, HADDR, HWRITE);
      else $error("[%0t] SVA FAIL: a_addr_captured (expected HADDR=%08h HWRITE=%b, got HADDR=%08h HWRITE=%b)",
                  $time, $past(req_addr), $past(req_write), HADDR, HWRITE);

    a_done_on_error: assert property (req_error |-> req_done)
        $display("[%0t] SVA PASS: a_done_on_error (req_done asserted with req_error)", $time);
      else $error("[%0t] SVA FAIL: a_done_on_error (req_error without req_done)", $time);

    a_reject_pulse: assert property (req_reject |=> !req_reject)
        $display("[%0t] SVA PASS: a_reject_pulse (single-cycle pulse)", $time);
      else $error("[%0t] SVA FAIL: a_reject_pulse (req_reject held >1 cycle)", $time);

    a_done_after_idle: assert property (req_done |-> HTRANS == 2'b00)
        $display("[%0t] SVA PASS: a_done_after_idle (req_done while HTRANS=IDLE)", $time);
      else $error("[%0t] SVA FAIL: a_done_after_idle (req_done with HTRANS=%b)", $time, HTRANS);

endmodule

module ahb_slave_sva #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 128
) (
    input logic HCLK,
    input logic HRESETn,
    input logic HREADYOUT,
    input logic [1:0] HTRANS,
    input logic [1:0] cfg_wait_states,
    input logic       HRESP_slave,
    input logic [DATA_WIDTH-1:0] HRDATA,
    input logic       fifo_empty,
    input logic       fifo_full
);
    default clocking cb @(posedge HCLK); endclocking
    default disable iff (!HRESETn);

    a_hresp_okay: assert property (HRESP_slave == 1'b0)
        else $error("[%0t] SVA FAIL: a_hresp_okay (HRESP=%b)", $time, HRESP_slave);

    a_rdata_zero_when_empty: assert property (fifo_empty |-> HRDATA == '0)
        else $error("[%0t] SVA FAIL: a_rdata_zero_when_empty (HRDATA=%08h while empty)",
                    $time, HRDATA);

    a_wait_min: assert property ($rose(HREADYOUT == 1'b0) |-> cfg_wait_states > 0)
        $display("[%0t] SVA PASS: a_wait_min (HREADYOUT low, cfg_wait_states=%0d)",
                 $time, cfg_wait_states);
      else $error("[%0t] SVA FAIL: a_wait_min (HREADYOUT low with cfg_wait_states=0)", $time);

endmodule

bind ahb_master ahb_master_sva #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .MAX_BURST_LEN(MAX_BURST_LEN)
) u_master_sva (
    .HCLK(HCLK), .HRESETn(HRESETn), .HREADY(HREADY),
    .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE),
    .HSIZE(HSIZE), .HBURST(HBURST), .HWDATA(HWDATA),
    .req_addr(req_addr), .req_write(req_write), .req_start(req_start),
    .req_done(req_done), .req_error(req_error), .req_reject(req_reject)
);

bind ahb_slave ahb_slave_sva #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)
) u_slave_sva (
    .HCLK(HCLK), .HRESETn(HRESETn), .HREADYOUT(HREADYOUT),
    .HTRANS(HTRANS), .cfg_wait_states(cfg_wait_states),
    .HRESP_slave(HRESP), .HRDATA(HRDATA),
    .fifo_empty(fifo_empty), .fifo_full(fifo_full)
);

`endif