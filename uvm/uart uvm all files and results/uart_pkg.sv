// ============================================================================
// uart_pkg.sv - Complete UVM verification package
// ============================================================================
`ifndef UART_PKG_SV
`define UART_PKG_SV

package uart_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---------------------------------------------------------------
  // Global parameters
  // ---------------------------------------------------------------
  parameter int SYS_FREQ    = 50_000_000;
  parameter int BAUD_RATE   = 9600;
  parameter int DATABITS    = 8;
  parameter int PARITY_EN   = 1;
  parameter int PARITY_TYPE = 0;  // 0=even, 1=odd

  localparam int M_16X     = SYS_FREQ / (BAUD_RATE * 16);
  localparam int BIT_CLKS  = 16 * M_16X;  // exact DUT bit period

  // =================================================================
  // Transaction
  // =================================================================
  typedef enum {TX, RX} uart_dir_e;

  class uart_item extends uvm_sequence_item;

    rand uart_dir_e   dir;
    rand bit [7:0]    data;
    rand bit          inject_parity_error;
    rand bit          inject_stop_error;

    // Observed fields
    bit [7:0] data_in;        // expected (parallel in for TX / serial-derived for RX)
    bit [7:0] data_out;       // observed  (serial-derived for TX / parallel out for RX)
    bit       obs_parity_err;
    bit       obs_stop_err;
    bit       obs_frame_err;
    bit       obs_tx_done;
    bit       obs_rx_done;

    `uvm_object_utils_begin(uart_item)
      `uvm_field_enum(uart_dir_e, dir, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(inject_parity_error, UVM_ALL_ON)
      `uvm_field_int(inject_stop_error,  UVM_ALL_ON)
      `uvm_field_int(data_in,  UVM_ALL_ON)
      `uvm_field_int(data_out, UVM_ALL_ON)
      `uvm_field_int(obs_parity_err, UVM_ALL_ON)
      `uvm_field_int(obs_stop_err,  UVM_ALL_ON)
      `uvm_field_int(obs_frame_err, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_default {
      inject_parity_error dist {0 := 90, 1 := 10};
      inject_stop_error   dist {0 := 95, 1 := 5};
    }

    function new(string name = "uart_item");
      super.new(name);
    endfunction

  endclass

  typedef uvm_sequencer #(uart_item) uart_sequencer;

  // =================================================================
  // Driver
  // =================================================================
  class uart_driver extends uvm_driver #(uart_item);
    `uvm_component_utils(uart_driver)

    virtual uart_if vif;
    bit is_tx = 1;
    uvm_analysis_port #(uart_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
        `uvm_fatal("DRV", "No vif in config_db")
      void'(uvm_config_db#(bit)::get(this, "", "is_tx", is_tx));
    endfunction

    task run_phase(uvm_phase phase);
      // Reset values
      vif.drv_cb.tx_en      <= 0;
      vif.drv_cb.tx_data_in <= 0;
      vif.drv_cb.rx_data    <= 1;

      // Wait for reset sequence
      wait (vif.reset === 1'b1);
      repeat (5) @(vif.drv_cb);
      wait (vif.reset === 1'b0);
      repeat (2) @(vif.drv_cb);

      forever begin
        uart_item item;
        seq_item_port.get_next_item(item);
        if (is_tx) drive_tx(item);
        else       drive_rx(item);
        seq_item_port.item_done();
      end
    endtask

    task drive_tx(uart_item item);
      // Wait for TX idle
      while (vif.drv_cb.tx_busy) @(vif.drv_cb);

      vif.drv_cb.tx_data_in <= item.data;
      vif.drv_cb.tx_en      <= 1'b1;
      @(vif.drv_cb);
      vif.drv_cb.tx_en      <= 1'b0;

      // Publish expected to scoreboard
      item.data_in = item.data;
      ap.write(item);

      // Wait for completion
      wait (vif.tx_done === 1'b1);
      @(vif.drv_cb);
      while (vif.drv_cb.tx_busy) @(vif.drv_cb);
    endtask

    task drive_rx(uart_item item);
      bit pbit;
      bit sbit;

      // Publish expected to scoreboard
      item.data_in = item.data;
      ap.write(item);

      // START bit
      vif.drv_cb.rx_data <= 1'b0;
      repeat (BIT_CLKS) @(vif.drv_cb);

      // DATA bits (LSB first)
      for (int i = 0; i < DATABITS; i++) begin
        vif.drv_cb.rx_data <= item.data[i];
        repeat (BIT_CLKS) @(vif.drv_cb);
      end

      // PARITY
      if (PARITY_EN) begin
        pbit = (PARITY_TYPE == 0) ? ^item.data : ~(^item.data);
        if (item.inject_parity_error) pbit = ~pbit;
        vif.drv_cb.rx_data <= pbit;
        repeat (BIT_CLKS) @(vif.drv_cb);
      end

      // STOP
      sbit = item.inject_stop_error ? 1'b0 : 1'b1;
      vif.drv_cb.rx_data <= sbit;
      repeat (BIT_CLKS) @(vif.drv_cb);

      // Idle gap
      vif.drv_cb.rx_data <= 1'b1;
      repeat (BIT_CLKS) @(vif.drv_cb);
    endtask

  endclass

  // =================================================================
  // Monitor
  // =================================================================
  class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)

    virtual uart_if vif;
    bit is_tx = 1;
    uvm_analysis_port #(uart_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
        `uvm_fatal("MON", "No vif in config_db")
      void'(uvm_config_db#(bit)::get(this, "", "is_tx", is_tx));
    endfunction

    task run_phase(uvm_phase phase);
      wait (vif.reset === 1'b1);
      wait (vif.reset === 1'b0);
      forever begin
        if (is_tx) monitor_tx();
        else       monitor_rx();
      end
    endtask

    // -------------------------------------------------------------
    // TX monitor: reconstruct serial frame from tx_data
    // -------------------------------------------------------------
    task monitor_tx();
      uart_item item = uart_item::type_id::create("tx_obs_item");
      bit [7:0] rx_byte = '0;
      bit par_bit, stop_bit;
      bit par_calc;
      int half_bit = BIT_CLKS / 2;

      // Wait for start bit (tx_busy rise)
      @(vif.mon_cb iff vif.mon_cb.tx_busy);
      item.data_in = vif.tx_data_in;

      // Skip half bit period to reach middle of start bit
      repeat (half_bit) @(vif.mon_cb);

      // Sample DATA bits
      for (int i = 0; i < DATABITS; i++) begin
        repeat (BIT_CLKS) @(vif.mon_cb);
        rx_byte[i] = vif.mon_cb.tx_data;
      end

      // Sample PARITY
      par_bit = 1'b1;
      if (PARITY_EN) begin
        repeat (BIT_CLKS) @(vif.mon_cb);
        par_bit = vif.mon_cb.tx_data;
      end

      // Sample STOP
      repeat (BIT_CLKS) @(vif.mon_cb);
      stop_bit = vif.mon_cb.tx_data;

      item.dir              = TX;
      item.data_out         = rx_byte;
      par_calc              = (PARITY_TYPE == 0) ? ^rx_byte : ~(^rx_byte);
      item.obs_parity_err   = PARITY_EN ? (par_bit != par_calc) : 1'b0;
      item.obs_stop_err     = (stop_bit !== 1'b1);

      ap.write(item);
    endtask

    // -------------------------------------------------------------
    // RX monitor: capture rx_data_out and error flags
    // -------------------------------------------------------------
    task monitor_rx();
      uart_item item = uart_item::type_id::create("rx_obs_item");

      // Wait for rx_done
      @(vif.mon_cb iff vif.mon_cb.rx_done);

      item.dir            = RX;
      item.data_out       = vif.mon_cb.rx_data_out;
      item.obs_parity_err = vif.mon_cb.parity_error;
      item.obs_stop_err   = vif.mon_cb.stop_error;
      item.obs_frame_err  = vif.mon_cb.frame_error;
      item.obs_rx_done    = 1'b1;

      ap.write(item);
    endtask

  endclass

  // =================================================================
  // Agent
  // =================================================================
  class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)

    uart_driver                        drv;
    uart_monitor                       mon;
    uvm_sequencer #(uart_item)         sqr;

    bit is_tx = 1;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'(uvm_config_db#(bit)::get(this, "", "is_tx", is_tx));

      mon = uart_monitor::type_id::create("mon", this);
      uvm_config_db#(bit)::set(this, "mon", "is_tx", is_tx);

      if (get_is_active() == UVM_ACTIVE) begin
        drv = uart_driver::type_id::create("drv", this);
        uvm_config_db#(bit)::set(this, "drv", "is_tx", is_tx);
        sqr = uvm_sequencer #(uart_item)::type_id::create("sqr", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      if (get_is_active() == UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

  endclass

  // =================================================================
  // Scoreboard
  // =================================================================
  `uvm_analysis_imp_decl(_exp)
  `uvm_analysis_imp_decl(_obs)

  class uart_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(uart_scoreboard)

    uvm_analysis_imp_exp #(uart_item, uart_scoreboard) exp_imp;
    uvm_analysis_imp_obs #(uart_item, uart_scoreboard) obs_imp;

    uart_item exp_q[$];
    uart_item obs_q[$];

    int tx_pass, tx_fail, rx_pass, rx_fail;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      exp_imp = new("exp_imp", this);
      obs_imp = new("obs_imp", this);
    endfunction

    function void write_exp(uart_item item);
      exp_q.push_back(item);
    endfunction

    function void write_obs(uart_item item);
      obs_q.push_back(item);
    endfunction

    // Match by direction
    task run_phase(uvm_phase phase);
      uart_item e, o;
      forever begin
        wait (exp_q.size() > 0 && obs_q.size() > 0);
        e = exp_q.pop_front();

        // Find first observed with matching direction
        o = null;
        foreach (obs_q[i]) begin
          if (obs_q[i].dir == e.dir) begin
            o = obs_q[i];
            obs_q.delete(i);
            break;
          end
        end
        if (o == null) begin
          exp_q.push_front(e);
          #100ns;
          continue;
        end

        case (e.dir)
          TX: check_tx(e, o);
          RX: check_rx(e, o);
        endcase
      end
    endtask

    function void check_tx(uart_item e, uart_item o);
      if (e.data_in !== o.data_out) begin
        tx_fail++;
        `uvm_error("SB_TX", $sformatf("TX MISMATCH: exp=0x%02h obs=0x%02h",
                                      e.data_in, o.data_out))
      end else begin
        tx_pass++;
        `uvm_info("SB_TX", $sformatf("TX OK: data=0x%02h", o.data_out), UVM_HIGH)
      end
      if (o.obs_parity_err)
        `uvm_error("SB_TX", "TX parity error observed on serial line")
      if (o.obs_stop_err)
        `uvm_error("SB_TX", "TX stop bit not high")
    endfunction

    function void check_rx(uart_item e, uart_item o);
      if (e.data_in !== o.data_out) begin
        rx_fail++;
        `uvm_error("SB_RX", $sformatf("RX MISMATCH: exp=0x%02h obs=0x%02h",
                                      e.data_in, o.data_out))
      end else begin
        rx_pass++;
        `uvm_info("SB_RX", $sformatf("RX OK: data=0x%02h", o.data_out), UVM_HIGH)
      end

      if (e.inject_parity_error && PARITY_EN && !o.obs_parity_err)
        `uvm_error("SB_RX", "Expected parity_error but none observed")
      if (!e.inject_parity_error && PARITY_EN && o.obs_parity_err)
        `uvm_error("SB_RX", "Unexpected parity_error")

      if (e.inject_stop_error && !o.obs_stop_err)
        `uvm_error("SB_RX", "Expected stop_error but none observed")
      if (!e.inject_stop_error && o.obs_stop_err)
        `uvm_error("SB_RX", "Unexpected stop_error")
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SB", $sformatf("TX pass=%0d fail=%0d | RX pass=%0d fail=%0d",
                                tx_pass, tx_fail, rx_pass, rx_fail), UVM_LOW)
      if (tx_fail + rx_fail == 0)
        `uvm_info("SB", "*** TEST PASSED ***", UVM_LOW)
      else
        `uvm_error("SB", "*** TEST FAILED ***")
    endfunction

  endclass

  // =================================================================
  // Coverage Collector
  // =================================================================
  class uart_coverage extends uvm_subscriber #(uart_item);
    `uvm_component_utils(uart_coverage)

    uart_item item;

    covergroup cg_tx;
      option.per_instance = 1;
      cp_data: coverpoint item.data {
        bins zero     = {8'h00};
        bins ones     = {8'hFF};
        bins lo       = {[8'h01:8'h3F]};
        bins mid      = {[8'h40:8'hBF]};
        bins hi       = {[8'hC0:8'hFE]};
        bins walk[]   = {8'h01,8'h02,8'h04,8'h08,
                         8'h10,8'h20,8'h40,8'h80};
      }
      cp_parity_bit: coverpoint (^item.data) {
        bins even = {0};
        bins odd  = {1};
      }
      cx_data_par: cross cp_data, cp_parity_bit;
    endgroup

    covergroup cg_rx;
      option.per_instance = 1;
      cp_data: coverpoint item.data {
        bins zero = {8'h00};
        bins ones = {8'hFF};
        bins low  = {[8'h01:8'h7F]};
        bins high = {[8'h80:8'hFE]};
      }
      cp_perr: coverpoint item.obs_parity_err { bins no = {0}; bins yes = {1}; }
      cp_serr: coverpoint item.obs_stop_err   { bins no = {0}; bins yes = {1}; }
      cp_ferr: coverpoint item.obs_frame_err  { bins no = {0}; bins yes = {1}; }
      cx_err:  cross cp_perr, cp_serr;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_tx = new();
      cg_rx = new();
    endfunction

    function void write(uart_item t);
      item = t;
      if (t.dir == TX) cg_tx.sample();
      else             cg_rx.sample();
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("TX cov=%0.2f%%  RX cov=%0.2f%%",
                                 cg_tx.get_coverage(), cg_rx.get_coverage()),
                UVM_LOW)
    endfunction

  endclass

  // =================================================================
  // Environment
  // =================================================================
  class uart_env extends uvm_env;
    `uvm_component_utils(uart_env)

    uart_agent      tx_agent;
    uart_agent      rx_agent;
    uart_scoreboard sb;
    uart_coverage   cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      tx_agent = uart_agent::type_id::create("tx_agent", this);
      uvm_config_db#(bit)::set(this, "tx_agent", "is_tx", 1);

      rx_agent = uart_agent::type_id::create("rx_agent", this);
      uvm_config_db#(bit)::set(this, "rx_agent", "is_tx", 0);

      sb  = uart_scoreboard::type_id::create("sb", this);
      cov = uart_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      // Driver publishes expected
      tx_agent.drv.ap.connect(sb.exp_imp);
      rx_agent.drv.ap.connect(sb.exp_imp);
      // Monitor publishes observed
      tx_agent.mon.ap.connect(sb.obs_imp);
      rx_agent.mon.ap.connect(sb.obs_imp);
      // Coverage subscribes to observed traffic
      tx_agent.mon.ap.connect(cov.analysis_export);
      rx_agent.mon.ap.connect(cov.analysis_export);
    endfunction

  endclass

  // =================================================================
  // Sequences
  // =================================================================
  class uart_base_seq extends uvm_sequence #(uart_item);
    `uvm_object_utils(uart_base_seq)

    function new(string name = "uart_base_seq");
      super.new(name);
    endfunction

    task body();
    endtask

  endclass

  // -------------------- TX sequence -------------------------------
  class uart_tx_seq extends uart_base_seq;
    `uvm_object_utils(uart_tx_seq)

    rand int unsigned num_tx = 20;

    function new(string name = "uart_tx_seq");
      super.new(name);
    endfunction

    task body();
      uart_item req;
      repeat (num_tx) begin
        req = uart_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {dir == TX;})
          `uvm_error("SEQ", "Randomize failed")
        finish_item(req);
      end
    endtask

  endclass

  // -------------------- RX sequence -------------------------------
  class uart_rx_seq extends uart_base_seq;
    `uvm_object_utils(uart_rx_seq)

    rand int unsigned num_rx = 20;

    function new(string name = "uart_rx_seq");
      super.new(name);
    endfunction

    task body();
      uart_item req;
      repeat (num_rx) begin
        req = uart_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
              dir == RX;
              inject_parity_error == 0;
              inject_stop_error   == 0;
            })
          `uvm_error("SEQ", "Randomize failed")
        finish_item(req);
      end
    endtask

  endclass

  // -------------------- Error injection sequence ------------------
  class uart_err_seq extends uart_base_seq;
    `uvm_object_utils(uart_err_seq)

    rand int unsigned num = 20;

    function new(string name = "uart_err_seq");
      super.new(name);
    endfunction

    task body();
      uart_item req;
      repeat (num) begin
        req = uart_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
              dir == RX;
              inject_parity_error dist {0 := 50, 1 := 50};
              inject_stop_error   dist {0 := 50, 1 := 50};
            })
          `uvm_error("SEQ", "Randomize failed")
        finish_item(req);
      end
    endtask

  endclass

  // -------------------- Full-duplex random sequence ---------------
  class uart_full_seq extends uart_base_seq;
    `uvm_object_utils(uart_full_seq)

    rand int unsigned num_tx = 30;
    rand int unsigned num_rx = 30;

    function new(string name = "uart_full_seq");
      super.new(name);
    endfunction

    task body();
      fork
        begin
          uart_tx_seq tx_s;
          tx_s = uart_tx_seq::type_id::create("tx_s");
          tx_s.num_tx = num_tx;
          tx_s.start(m_sequencer);
        end
        begin
          uart_rx_seq rx_s;
          rx_s = uart_rx_seq::type_id::create("rx_s");
          rx_s.num_rx = num_rx;
          rx_s.start(m_sequencer);
        end
      join
    endtask

  endclass

  // =================================================================
  // Tests
  // =================================================================
  class uart_base_test extends uvm_test;
    `uvm_component_utils(uart_base_test)

    uart_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = uart_env::type_id::create("env", this);
    endfunction

    task reset_phase(uvm_phase phase);
      virtual uart_if vif;
      if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
        `uvm_fatal("TEST", "No vif")
      vif.reset <= 1'b1;
      repeat (20) @(posedge vif.clk);
      vif.reset <= 1'b0;
      repeat (20) @(posedge vif.clk);
    endtask

  endclass

  class uart_tx_test extends uart_base_test;
    `uvm_component_utils(uart_tx_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      uart_tx_seq s = uart_tx_seq::type_id::create("s");
      phase.raise_objection(this);
      s.start(env.tx_agent.sqr);
      #50000ns;
      phase.drop_objection(this);
    endtask
  endclass

  class uart_rx_test extends uart_base_test;
    `uvm_component_utils(uart_rx_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      uart_rx_seq s = uart_rx_seq::type_id::create("s");
      phase.raise_objection(this);
      s.start(env.rx_agent.sqr);
      #50000ns;
      phase.drop_objection(this);
    endtask
  endclass

  class uart_error_test extends uart_base_test;
    `uvm_component_utils(uart_error_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      uart_err_seq s = uart_err_seq::type_id::create("s");
      phase.raise_objection(this);
      s.start(env.rx_agent.sqr);
      #50000ns;
      phase.drop_objection(this);
    endtask
  endclass

  class uart_full_test extends uart_base_test;
    `uvm_component_utils(uart_full_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      uart_tx_seq tx_s = uart_tx_seq::type_id::create("tx_s");
      uart_rx_seq rx_s = uart_rx_seq::type_id::create("rx_s");
      phase.raise_objection(this);
      fork
        tx_s.start(env.tx_agent.sqr);
        rx_s.start(env.rx_agent.sqr);
      join
      #100000ns;
      phase.drop_objection(this);
    endtask
  endclass

endpackage : uart_pkg

`endif