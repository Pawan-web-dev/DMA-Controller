module ahb_master #(
    parameter int ADDR_WIDTH    = 32,
    parameter int DATA_WIDTH    = 32,
    parameter int MAX_BURST_LEN = 128,
    parameter int LEN_WIDTH     = $clog2(MAX_BURST_LEN + 1)
)(
    input  logic                  HCLK,
    input  logic                  HRESETn,
    input  logic                  HREADY,
    input  logic [DATA_WIDTH-1:0] HRDATA,
    input  logic                  HRESP,

    output logic [ADDR_WIDTH-1:0] HADDR,
    output logic [1:0]            HTRANS,
    output logic                  HWRITE,
    output logic [2:0]            HSIZE,
    output logic [2:0]            HBURST,
    output logic [DATA_WIDTH-1:0] HWDATA,

    input  logic                  req_start,
    input  logic                  req_write,
    input  logic [LEN_WIDTH-1:0]  req_burst_len,
    input  logic [ADDR_WIDTH-1:0] req_addr,

    input  logic [DATA_WIDTH-1:0] req_wdata  [0:MAX_BURST_LEN-1],
    output logic [DATA_WIDTH-1:0] resp_rdata [0:MAX_BURST_LEN-1],

    output logic                  req_done,
    output logic                  req_error,
    output logic                  req_reject
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_BURST0,
        ST_BURST,
        ST_ERR_COMP
    } state_e;

    localparam logic [1:0] HTRANS_IDLE   = 2'b00;
    localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
    localparam logic [1:0] HTRANS_SEQ    = 2'b11;

    localparam logic [2:0] HSIZE_VAL =
        (DATA_WIDTH ==   8) ? 3'b000 :
        (DATA_WIDTH ==  16) ? 3'b001 :
        (DATA_WIDTH ==  32) ? 3'b010 :
        (DATA_WIDTH ==  64) ? 3'b011 :
        (DATA_WIDTH == 128) ? 3'b100 : 3'b010;

    localparam logic [ADDR_WIDTH-1:0] ADDR_INCR = DATA_WIDTH / 8;

    state_e               state;
    logic [LEN_WIDTH-1:0] beat_cnt;
    logic [LEN_WIDTH-1:0] active_burst_len;
    logic                 is_write;

    wire req_len_valid = (req_burst_len > 0) && (req_burst_len <= MAX_BURST_LEN);

    function automatic logic [2:0] hburst_encode(input logic [LEN_WIDTH-1:0] len);
        case (len)
            1:       hburst_encode = 3'b000;
            4:       hburst_encode = 3'b011;
            8:       hburst_encode = 3'b101;
            16:      hburst_encode = 3'b111;
            default: hburst_encode = 3'b001;
        endcase
    endfunction

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state            <= ST_IDLE;
            HADDR            <= '0;
            HTRANS           <= HTRANS_IDLE;
            HWRITE           <= 1'b0;
            HSIZE            <= HSIZE_VAL;
            HBURST           <= 3'b000;
            HWDATA           <= '0;
            req_done         <= 1'b0;
            req_error        <= 1'b0;
            req_reject       <= 1'b0;
            beat_cnt         <= '0;
            active_burst_len <= '0;
            is_write         <= 1'b0;
        end else if (HREADY) begin
            req_reject <= 1'b0;

            unique case (state)

                ST_IDLE: begin
                    req_done  <= 1'b0;
                    req_error <= 1'b0;
                    if (req_start && req_len_valid) begin
                        HADDR            <= req_addr;
                        HWRITE           <= req_write;
                        HSIZE            <= HSIZE_VAL;
                        HTRANS           <= HTRANS_NONSEQ;
                        is_write         <= req_write;
                        active_burst_len <= req_burst_len;
                        beat_cnt         <= '0;
                        HBURST           <= hburst_encode(req_burst_len);
                        if (req_write)
                            HWDATA <= req_wdata[0];
                        state <= ST_BURST0;
                    end else begin
                        HTRANS <= HTRANS_IDLE;
                        if (req_start && !req_len_valid)
                            req_reject <= 1'b1;
                    end
                end

                ST_BURST0: begin
                    if (active_burst_len > 1) begin
                        HTRANS <= HTRANS_SEQ;
                        HADDR  <= HADDR + ADDR_INCR;
                    end else begin
                        HTRANS <= HTRANS_IDLE;
                    end
                    state <= ST_BURST;
                end

                ST_BURST: begin
                    if (HRESP) begin
                        HTRANS <= HTRANS_IDLE;
                        state  <= ST_ERR_COMP;
                    end else if (!is_write) begin
                        resp_rdata[beat_cnt] <= HRDATA;

                        if (beat_cnt == (active_burst_len - 1'b1)) begin
                            HTRANS   <= HTRANS_IDLE;
                            req_done <= 1'b1;
                            state    <= ST_IDLE;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                            if ((beat_cnt + 2) < active_burst_len) begin
                                HTRANS <= HTRANS_SEQ;
                                HADDR  <= HADDR + ADDR_INCR;
                            end else begin
                                HTRANS <= HTRANS_IDLE;
                            end
                        end
                    end else begin
                        if (beat_cnt == (active_burst_len - 1'b1)) begin
                            HTRANS   <= HTRANS_IDLE;
                            req_done <= 1'b1;
                            state    <= ST_IDLE;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                            HWDATA   <= req_wdata[beat_cnt + 1'b1];
                            if ((beat_cnt + 2) < active_burst_len) begin
                                HTRANS <= HTRANS_SEQ;
                                HADDR  <= HADDR + ADDR_INCR;
                            end else begin
                                HTRANS <= HTRANS_IDLE;
                            end
                        end
                    end
                end

                ST_ERR_COMP: begin
                    HTRANS    <= HTRANS_IDLE;
                    req_done  <= 1'b1;
                    req_error <= 1'b1;
                    state     <= ST_IDLE;
                end

                default: begin
                    HTRANS <= HTRANS_IDLE;
                    state  <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
