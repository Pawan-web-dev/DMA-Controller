`ifndef AHB_PKG_SV
`define AHB_PKG_SV

package ahb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // =========================================================
    // Request-level sequence item
    // =========================================================
    class ahb_burst_item extends uvm_sequence_item;
        rand bit          write;
        rand int unsigned len;
        rand bit [31:0]   addr;
        rand bit [31:0]   wdata[];
        bit  [31:0]       rdata[];
        bit               error;
        bit               reject;

        constraint c_len  { len inside {[1:16]}; wdata.size() == len; }
        constraint c_addr { addr[1:0] == 2'b00; }

        `uvm_object_utils_begin(ahb_burst_item)
            `uvm_field_int (write, UVM_DEFAULT)
            `uvm_field_int (len,   UVM_DEFAULT)
            `uvm_field_int (addr,  UVM_DEFAULT)
            `uvm_field_array_int(wdata, UVM_DEFAULT)
            `uvm_field_array_int(rdata, UVM_DEFAULT)
            `uvm_field_int (error, UVM_DEFAULT)
            `uvm_field_int (reject,UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "ahb_burst_item");
            super.new(name);
        endfunction
    endclass

    // =========================================================
    // Beat-level item
    // =========================================================
    class ahb_beat extends uvm_sequence_item;
        bit [31:0] addr;
        bit [31:0] data;
        bit        write;
        bit [2:0]  size;
        bit [2:0]  burst;
        bit        is_non_seq;

        `uvm_object_utils_begin(ahb_beat)
            `uvm_field_int(addr,       UVM_DEFAULT)
            `uvm_field_int(data,       UVM_DEFAULT)
            `uvm_field_int(write,      UVM_DEFAULT)
            `uvm_field_int(size,       UVM_DEFAULT)
            `uvm_field_int(burst,      UVM_DEFAULT)
            `uvm_field_int(is_non_seq, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "ahb_beat");
            super.new(name);
        endfunction
    endclass

    // =========================================================
    // Driver
    // =========================================================
    class ahb_driver extends uvm_driver #(ahb_burst_item);
        `uvm_component_utils(ahb_driver)
        virtual ahb_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif))
                `uvm_fatal("DRV", "virtual ahb_if not set")
        endfunction

        task run_phase(uvm_phase phase);
            ahb_burst_item req;
            vif.req_start     <= 1'b0;
            vif.req_write     <= 1'b0;
            vif.req_burst_len <= '0;
            vif.req_addr      <= '0;
            wait (vif.HRESETn === 1'b1);
            @(negedge vif.HCLK);
            forever begin
                seq_item_port.get_next_item(req);
                drive_burst(req);
                seq_item_port.item_done();
            end
        endtask

        task drive_burst(ahb_burst_item req);
            @(negedge vif.HCLK);
            vif.req_addr      <= req.addr;
            vif.req_write     <= req.write;
            vif.req_burst_len <= req.len[4:0];
            for (int i = 0; i < req.len; i++)
                vif.req_wdata[i] <= req.wdata[i];
            vif.req_start     <= 1'b1;
            @(negedge vif.HCLK);
            vif.req_start     <= 1'b0;
            while (vif.req_done !== 1'b1) @(negedge vif.HCLK);
            req.error  = vif.req_error;
            req.reject = vif.req_reject;
            if (!req.write) begin
                req.rdata = new[req.len];
                for (int i = 0; i < req.len; i++)
                    req.rdata[i] = vif.resp_rdata[i];
            end
        endtask
    endclass

    // =========================================================
    // Monitor
    // =========================================================
    class ahb_monitor extends uvm_component;
        `uvm_component_utils(ahb_monitor)
        virtual ahb_if vif;
        uvm_analysis_port #(ahb_beat) ap;
        int unsigned beats_seen;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif))
                `uvm_fatal("MON", "virtual ahb_if not set")
        endfunction

        task run_phase(uvm_phase phase);
            ahb_beat b;
            wait (vif.HRESETn === 1'b1);
            forever begin
                @(posedge vif.HCLK);
                if (vif.HTRANS inside {2'b10, 2'b11} && vif.HREADYOUT === 1'b1) begin
                    b = ahb_beat::type_id::create("b");
                    b.addr       = vif.HADDR;
                    b.write      = vif.HWRITE;
                    b.size       = vif.HSIZE;
                    b.burst      = vif.HBURST;
                    b.is_non_seq = (vif.HTRANS == 2'b10);
                    b.data       = vif.HWRITE ? vif.HWDATA : vif.HRDATA;
                    ap.write(b);
                    beats_seen++;
                end
            end
        endtask
    endclass

    // =========================================================
    // Agent
    // =========================================================
    class ahb_agent extends uvm_agent;
        `uvm_component_utils(ahb_agent)
        ahb_driver    drv;
        ahb_monitor   mon;
        uvm_sequencer #(ahb_burst_item) sqr;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv = ahb_driver   ::type_id::create("drv", this);
            mon = ahb_monitor  ::type_id::create("mon", this);
            sqr = uvm_sequencer#(ahb_burst_item)::type_id::create("sqr", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    // =========================================================
    // Scoreboard
    // =========================================================
    class ahb_scoreboard extends uvm_component;
        `uvm_component_utils(ahb_scoreboard)
        uvm_analysis_imp #(ahb_beat, ahb_scoreboard) imp;

        bit [31:0] fifo[$];
        int        max_depth = 4;
        int        num_writes, num_reads, num_errors;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            imp = new("imp", this);
        endfunction

        function void write(ahb_beat b);
            bit [31:0] expected;
            if (b.write) begin
                if (fifo.size() >= max_depth)
                    `uvm_error("SCB", $sformatf("FIFO overflow (size=%0d data=%08h)",
                                                fifo.size(), b.data))
                fifo.push_back(b.data);
                num_writes++;
            end else begin
                if (fifo.size() == 0) begin
                    `uvm_error("SCB", $sformatf("FIFO underflow (data=%08h)", b.data))
                end else begin
                    expected = fifo.pop_front();
                    if (b.data !== expected)
                        `uvm_error("SCB", $sformatf("Read mismatch: exp=%08h got=%08h",
                                                    expected, b.data))
                end
                num_reads++;
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SCB", $sformatf(
                "writes=%0d reads=%0d errors=%0d fifo_left=%0d",
                num_writes, num_reads, num_errors, fifo.size()), UVM_LOW)
        endfunction
    endclass

    // =========================================================
    // Beat-level coverage
    // =========================================================
    class ahb_bus_cov extends uvm_subscriber #(ahb_beat);
        `uvm_component_utils(ahb_bus_cov)
        ahb_beat b;

        covergroup cg_bus;
            option.per_instance = 1;
            cp_write : coverpoint b.write;
            cp_size  : coverpoint b.size {
                bins b32 = {3'b010};
                // 64-bit not supported by this DUT
            }
            cp_burst : coverpoint b.burst {
                bins single = {3'b000};
                bins incr   = {3'b001};
                bins wrap4  = {3'b011};
                bins wrap8  = {3'b101};
                bins wrap16 = {3'b111};
            }
            cp_trans : coverpoint b.is_non_seq {
                bins nonseq = {1'b1};
                bins seq    = {1'b0};
            }
            cx_wr_burst : cross cp_write, cp_burst;
            cx_wr_trans : cross cp_write, cp_trans;
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            cg_bus = new();
        endfunction

        function void write(ahb_beat t);
            b = t;
            cg_bus.sample();
        endfunction
    endclass

    // =========================================================
    // Scenario coverage
    // =========================================================
    class ahb_scenario_cov extends uvm_component;
        `uvm_component_utils(ahb_scenario_cov)
        virtual ahb_if vif;

        covergroup cg_scn;
            option.per_instance = 1;
            cp_ws  : coverpoint vif.cfg_wait_states {
                bins ws0 = {2'd0}; bins ws1 = {2'd1};
                bins ws2 = {2'd2}; bins ws3 = {2'd3};
            }
            cp_rej : coverpoint vif.req_reject   { bins seen = {1'b1}; }
            cp_err : coverpoint vif.req_error    { bins seen = {1'b1}; }
            cp_inj : coverpoint vif.inject_error { bins on   = {1'b1}; }
            cx_ws_rej : cross cp_ws, cp_rej;
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            cg_scn = new();
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif))
                `uvm_fatal("SCOV", "vif not set")
        endfunction

        task run_phase(uvm_phase phase);
            wait (vif.HRESETn === 1'b1);
            forever begin
                @(posedge vif.HCLK);
                if (vif.HRESETn) cg_scn.sample();
            end
        endtask
    endclass

    // =========================================================
    // Environment
    // =========================================================
    class ahb_env extends uvm_env;
        `uvm_component_utils(ahb_env)
        ahb_agent        agent;
        ahb_scoreboard   scb;
        ahb_bus_cov      bcov;
        ahb_scenario_cov scov;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = ahb_agent      ::type_id::create("agent", this);
            scb   = ahb_scoreboard ::type_id::create("scb",   this);
            bcov  = ahb_bus_cov    ::type_id::create("bcov",  this);
            scov  = ahb_scenario_cov::type_id::create("scov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.ap.connect(scb.imp);
            agent.mon.ap.connect(bcov.analysis_export);
        endfunction
    endclass

    // =========================================================
    // Sequences
    // =========================================================
    class ahb_base_seq extends uvm_sequence #(ahb_burst_item);
        `uvm_object_utils(ahb_base_seq)
        function new(string name = "ahb_base_seq"); super.new(name); endfunction
    endclass

    class ahb_burst_seq extends ahb_base_seq;
        `uvm_object_utils(ahb_burst_seq)
        rand bit          write;
        rand int unsigned len;
        rand bit [31:0]   addr;
        rand bit [31:0]   seed;

        constraint c_len  { len inside {1,2,4,8,16}; }
        constraint c_addr { addr[1:0] == 2'b00; addr[7:0] inside {[8'h00:8'hF0]}; }

        function new(string name = "ahb_burst_seq"); super.new(name); endfunction

        task body();
            ahb_burst_item req;
            req = ahb_burst_item::type_id::create("req");
            start_item(req);
            req.write = write;
            req.len   = len;
            req.addr  = addr;
            req.wdata = new[len];
            for (int i = 0; i < len; i++) req.wdata[i] = seed + i;
            finish_item(req);
        endtask
    endclass

    class ahb_write_seq extends ahb_base_seq;
        `uvm_object_utils(ahb_write_seq)
        int unsigned len  = 1;
        bit [31:0]   addr = 32'h1000;
        bit [31:0]   seed = 32'hA000_0000;
        function new(string name = "ahb_write_seq"); super.new(name); endfunction
        task body();
            ahb_burst_item req;
            req = ahb_burst_item::type_id::create("req");
            start_item(req);
            req.write = 1'b1;
            req.len   = len;
            req.addr  = addr;
            req.wdata = new[len];
            for (int i = 0; i < len; i++) req.wdata[i] = seed + i;
            finish_item(req);
        endtask
    endclass

    class ahb_read_seq extends ahb_base_seq;
        `uvm_object_utils(ahb_read_seq)
        int unsigned len  = 1;
        bit [31:0]   addr = 32'h1000;
        function new(string name = "ahb_read_seq"); super.new(name); endfunction
        task body();
            ahb_burst_item req;
            req = ahb_burst_item::type_id::create("req");
            start_item(req);
            req.write = 1'b0;
            req.len   = len;
            req.addr  = addr;
            req.wdata = new[len];
            foreach (req.wdata[i]) req.wdata[i] = '0;
            finish_item(req);
        endtask
    endclass

    class ahb_fifo_fill_drain_seq extends ahb_base_seq;
        `uvm_object_utils(ahb_fifo_fill_drain_seq)
        int unsigned depth = 4;
        bit [31:0]   addr  = 32'h2000;
        bit [31:0]   seed  = 32'hB000_0000;
        function new(string name = "ahb_fifo_fill_drain_seq"); super.new(name); endfunction
        task body();
            ahb_burst_item req;
            req = ahb_burst_item::type_id::create("wr");
            start_item(req);
            req.write = 1'b1; req.len = depth; req.addr = addr;
            req.wdata = new[depth];
            for (int i = 0; i < depth; i++) req.wdata[i] = seed + i;
            finish_item(req);

            req = ahb_burst_item::type_id::create("rd");
            start_item(req);
            req.write = 1'b0; req.len = depth; req.addr = addr;
            req.wdata = new[depth];
            foreach (req.wdata[i]) req.wdata[i] = '0;
            finish_item(req);
        endtask
    endclass

    // =========================================================
    // Tests
    // =========================================================
    class ahb_base_test extends uvm_test;
        `uvm_component_utils(ahb_base_test)
        ahb_env env;
        virtual ahb_if vif_local;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = ahb_env::type_id::create("env", this);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
        endfunction

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif_local))
                `uvm_fatal("TEST", "vif not set")
            wait (vif_local.HRESETn === 1'b1);
            @(negedge vif_local.HCLK);
            run_scenario(phase);
            phase.drop_objection(this);
        endtask

        virtual task run_scenario(uvm_phase phase); endtask
    endclass

    class ahb_sanity_test extends ahb_base_test;
        `uvm_component_utils(ahb_sanity_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        task run_scenario(uvm_phase phase);
            ahb_write_seq wr;
            ahb_read_seq  rd;
            for (int l = 1; l <= 2; l++) begin
                wr = ahb_write_seq::type_id::create("wr");
                wr.len  = l;
                wr.addr = 32'h1000 + (l << 4);
                wr.seed = 32'hA000_0000 + (l << 8);
                wr.start(env.agent.sqr);

                rd = ahb_read_seq::type_id::create("rd");
                rd.len  = l;
                rd.addr = wr.addr;
                rd.start(env.agent.sqr);
            end
        endtask
    endclass

    class ahb_fifo_test extends ahb_base_test;
        `uvm_component_utils(ahb_fifo_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        task run_scenario(uvm_phase phase);
            ahb_fifo_fill_drain_seq seq;
            seq = ahb_fifo_fill_drain_seq::type_id::create("seq");
            seq.depth = 4;
            seq.addr  = 32'h2000;
            seq.start(env.agent.sqr);
        endtask
    endclass

    class ahb_wait_test extends ahb_base_test;
        `uvm_component_utils(ahb_wait_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        task run_scenario(uvm_phase phase);
            virtual ahb_if vif;
            ahb_fifo_fill_drain_seq seq;
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif))
                `uvm_fatal("WAIT", "vif not set")
            for (int ws = 0; ws <= 3; ws++) begin
                vif.cfg_wait_states = ws[1:0];
                repeat (4) @(posedge vif.HCLK);

                seq = ahb_fifo_fill_drain_seq::type_id::create($sformatf("seq_ws%0d", ws));
                seq.depth = 4;
                seq.addr  = 32'h3000 + (ws << 8);
                seq.seed  = 32'hC000_0000 + (ws << 8);
                seq.start(env.agent.sqr);

                @(negedge vif.HCLK);
                vif.req_addr      <= 32'h3F00 + (ws << 4);
                vif.req_write     <= 1'b1;
                vif.req_burst_len <= 5'd0;
                vif.req_start     <= 1'b1;
                repeat (2) @(negedge vif.HCLK);
                vif.req_start     <= 1'b0;
                repeat (4) @(negedge vif.HCLK);
            end
            vif.cfg_wait_states = 2'd0;
        endtask
    endclass

    class ahb_invalid_test extends ahb_base_test;
        `uvm_component_utils(ahb_invalid_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        task run_scenario(uvm_phase phase);
            virtual ahb_if vif;
            ahb_write_seq wr;
            ahb_read_seq  rd;
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif))
                `uvm_fatal("INV", "vif not set")

            @(negedge vif.HCLK);
            vif.req_addr      <= 32'h4000;
            vif.req_write     <= 1'b1;
            vif.req_burst_len <= 5'd0;
            vif.req_start     <= 1'b1;
            repeat (3) @(negedge vif.HCLK);
            vif.req_start <= 1'b0;
            repeat (4) @(negedge vif.HCLK);

            @(negedge vif.HCLK);
            vif.req_addr      <= 32'h4100;
            vif.req_write     <= 1'b1;
            vif.req_burst_len <= 5'd17;
            vif.req_start     <= 1'b1;
            repeat (3) @(negedge vif.HCLK);
            vif.req_start <= 1'b0;
            repeat (4) @(negedge vif.HCLK);

            wr = ahb_write_seq::type_id::create("wr");
            wr.len  = 1;
            wr.addr = 32'h4200;
            wr.seed = 32'hD000_0000;
            wr.start(env.agent.sqr);

            rd = ahb_read_seq::type_id::create("rd");
            rd.len  = 1;
            rd.addr = 32'h4200;
            rd.start(env.agent.sqr);
        endtask
    endclass

    class ahb_error_test extends ahb_base_test;
        `uvm_component_utils(ahb_error_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        task run_scenario(uvm_phase phase);
            virtual ahb_if vif;
            ahb_read_seq  rd;
            ahb_write_seq wr2;
            ahb_read_seq  rd2;
            int           drain_len;
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif))
                `uvm_fatal("ERR", "vif not set")

            fork
                begin
                    ahb_write_seq wr;
                    wr = ahb_write_seq::type_id::create("wr");
                    wr.len  = 4;
                    wr.addr = 32'h5000;
                    wr.seed = 32'hE000_0000;
                    wr.start(env.agent.sqr);
                end
                begin
                    wait (vif.HTRANS inside {2'b10, 2'b11});
                    repeat (2) @(negedge vif.HCLK);
                    vif.inject_error <= 1'b1;
                    @(negedge vif.HCLK);
                    vif.inject_error <= 1'b0;
                end
            join

            repeat (6) @(posedge vif.HCLK);

            drain_len = env.scb.fifo.size();
            `uvm_info("ERR_TST",
                $sformatf("Draining %0d beats after HRESP abort", drain_len), UVM_LOW)

            if (drain_len > 0) begin
                rd = ahb_read_seq::type_id::create("rd");
                rd.len  = drain_len;
                rd.addr = 32'h5000;
                rd.start(env.agent.sqr);
            end

            wr2 = ahb_write_seq::type_id::create("wr2");
            wr2.len  = 1;
            wr2.addr = 32'h5100;
            wr2.seed = 32'hF000_0000;
            wr2.start(env.agent.sqr);

            rd2 = ahb_read_seq::type_id::create("rd2");
            rd2.len  = 1;
            rd2.addr = 32'h5100;
            rd2.start(env.agent.sqr);
        endtask
    endclass

    class ahb_random_test extends ahb_base_test;
        `uvm_component_utils(ahb_random_test)
        rand int unsigned num_pairs;
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        task run_scenario(uvm_phase phase);
            virtual ahb_if vif;
            ahb_write_seq wr;
            ahb_read_seq  rd;
            int           len;
            bit [31:0]    addr;
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif))
                `uvm_fatal("RND", "vif not set")

            num_pairs = 30;
            for (int i = 0; i < num_pairs; i++) begin
                case (i % 8)
                    0: vif.cfg_wait_states = 2'd0;
                    3: vif.cfg_wait_states = 2'd1;
                    5: vif.cfg_wait_states = 2'd2;
                    7: vif.cfg_wait_states = 2'd3;
                    default: ;
                endcase

                case ($urandom_range(0,5))
                    0: len = 1;
                    1: len = 2;
                    2: len = 4;
                    3: len = 8;
                    default: len = 16;   // hits wrap16
                endcase
                addr = 32'h6000 + (i << 8);

                wr = ahb_write_seq::type_id::create($sformatf("wr_%0d", i));
                wr.len  = len;
                wr.addr = addr;
                wr.seed = 32'h6000_0000 + (i << 8);
                wr.start(env.agent.sqr);

                rd = ahb_read_seq::type_id::create($sformatf("rd_%0d", i));
                rd.len  = len;
                rd.addr = addr;
                rd.start(env.agent.sqr);
            end
            vif.cfg_wait_states = 2'd0;
        endtask
    endclass

endpackage

`endif