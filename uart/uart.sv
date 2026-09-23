module baud_gen #(
    parameter SYS_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  logic clk,
    input  logic reset,
    output logic baud_tick,
    output logic tick_16x
);

    localparam int M_16X = SYS_FREQ / (BAUD_RATE * 16);

    initial begin
        if (M_16X <= 0) begin
            $fatal(1, "baud_gen: invalid SYS_FREQ/BAUD_RATE combination (M_16X=%0d)", M_16X);
        end
    end

    logic [$clog2(M_16X)-1:0] count_16x;
    logic [3:0] count_1x;

    always_ff @(posedge clk) begin
        if (reset) begin
            count_16x <= '0;
            tick_16x  <= 1'b0;
        end else begin
            if (count_16x == (M_16X - 1)) begin
                count_16x <= '0;
                tick_16x  <= 1'b1;
            end else begin
                count_16x <= count_16x + 1'b1;
                tick_16x  <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            count_1x  <= '0;
            baud_tick <= 1'b0;
        end else if (tick_16x) begin
            if (count_1x == 4'd15) begin
                count_1x  <= '0;
                baud_tick <= 1'b1;
            end else begin
                count_1x  <= count_1x + 1'b1;
                baud_tick <= 1'b0;
            end
        end else begin
            baud_tick <= 1'b0;
        end
    end

endmodule

module uart_tx #(
    parameter DATABITS    = 8,
    parameter PARITY_EN   = 1,
    parameter PARITY_TYPE = 0
)(
    input  logic                   clk,
    input  logic                   reset,
    input  logic [DATABITS-1:0]    data_in,
    input  logic                   tx_en,
    input  logic                   baud_tick,
    output logic                   tx_data,
    output logic                   tx_busy
);

    typedef enum logic [2:0] {IDLE, START, DATA, PARITY, STOP} state_tx;
    state_tx CS;

    logic [$clog2(DATABITS)-1:0] bit_count;
    logic [DATABITS-1:0]         data_reg;
    logic                        parity_bit;

    logic tx_en_d;
    logic tx_en_rise;
    logic tx_en_latched;

    always_ff @(posedge clk) begin
        if (reset)
            tx_en_d <= 1'b0;
        else
            tx_en_d <= tx_en;
    end

    assign tx_en_rise = tx_en & ~tx_en_d;

    always_ff @(posedge clk) begin
        if (reset)
            tx_en_latched <= 1'b0;
        else if (!tx_busy && tx_en_rise)
            tx_en_latched <= 1'b1;
        else if (CS == START)
            tx_en_latched <= 1'b0;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            CS         <= IDLE;
            bit_count  <= '0;
            data_reg   <= '0;
            tx_busy    <= 1'b0;
            parity_bit <= 1'b0;
        end else if (baud_tick) begin
            case (CS)
                IDLE: begin
                    if (tx_en_latched) begin
                        CS         <= START;
                        tx_busy    <= 1'b1;
                        data_reg   <= data_in;
                        bit_count  <= '0;
                        parity_bit <= (PARITY_TYPE == 0) ? ^data_in : ~(^data_in);
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                START: CS <= DATA;

                DATA: begin
                    if (bit_count == DATABITS-1)
                        CS <= PARITY_EN ? PARITY : STOP;
                    else
                        bit_count <= bit_count + 1'b1;
                end

                PARITY: CS <= STOP;

                STOP: begin
                    CS      <= IDLE;
                    tx_busy <= 1'b0;
                end

                default: CS <= IDLE;
            endcase
        end
    end

    always_comb begin
        case (CS)
            START:   tx_data = 1'b0;
            DATA:    tx_data = data_reg[bit_count];
            PARITY:  tx_data = parity_bit;
            default: tx_data = 1'b1;
        endcase
    end

endmodule

module uart_rx #(
    parameter DATABITS    = 8,
    parameter PARITY_EN   = 1,
    parameter PARITY_TYPE = 0
)(
    input  logic                 clk,
    input  logic                 reset,
    input  logic                 tick_16x,
    input  logic                 rx_data,
    output logic [DATABITS-1:0]  data_out,
    output logic                 rx_done,
    output logic                 parity_error,
    output logic                 stop_error
);

    logic rx_sync0, rx_sync1;
    always_ff @(posedge clk) begin
        if (reset) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx_data;
            rx_sync1 <= rx_sync0;
        end
    end

    typedef enum logic [2:0] {IDLE, START, DATA, PARITY, STOP} state_rx;
    state_rx CS;

    logic [3:0] sample_count;
    logic [$clog2(DATABITS)-1:0] bit_count;
    logic [DATABITS-1:0] data_reg;
    logic parity_calc;
    logic parity_received;

    always_comb begin
        parity_calc = (PARITY_TYPE == 0) ? ^data_reg : ~(^data_reg);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            CS              <= IDLE;
            sample_count    <= '0;
            bit_count       <= '0;
            data_reg        <= '0;
            data_out        <= '0;
            rx_done         <= 1'b0;
            parity_error    <= 1'b0;
            stop_error      <= 1'b0;
            parity_received <= 1'b0;
        end else begin
            rx_done <= 1'b0;

            if (tick_16x) begin
                case (CS)
                    IDLE: begin
                        if (rx_sync1 == 1'b0) begin
                            CS           <= START;
                            sample_count <= '0;
                            parity_error <= 1'b0;
                            stop_error   <= 1'b0;
                        end
                    end

                    START: begin
                        sample_count <= sample_count + 1'b1;
                        if (sample_count == 4'd7) begin
                            if (rx_sync1 == 1'b0) begin
                                CS           <= DATA;
                                sample_count <= '0;
                                bit_count    <= '0;
                            end else begin
                                CS <= IDLE;
                            end
                        end
                    end

                    DATA: begin
                        sample_count <= sample_count + 1'b1;
                        if (sample_count == 4'd15) begin
                            sample_count        <= '0;
                            data_reg[bit_count] <= rx_sync1;
                            if (bit_count == DATABITS - 1)
                                CS <= PARITY_EN ? PARITY : STOP;
                            else
                                bit_count <= bit_count + 1'b1;
                        end
                    end

                    PARITY: begin
                        sample_count <= sample_count + 1'b1;
                        if (sample_count == 4'd15) begin
                            sample_count    <= '0;
                            parity_received <= rx_sync1;
                            CS              <= STOP;
                        end
                    end

                    STOP: begin
                        sample_count <= sample_count + 1'b1;
                        if (sample_count == 4'd15) begin
                            stop_error <= (rx_sync1 != 1'b1);
                            if (PARITY_EN)
                                parity_error <= (parity_received != parity_calc);
                            data_out <= data_reg;
                            rx_done  <= 1'b1;
                            CS       <= IDLE;
                        end
                    end

                    default: CS <= IDLE;
                endcase
            end
        end
    end

endmodule

module uart_top #(
    parameter SYS_FREQ    = 50_000_000,
    parameter BAUD_RATE   = 9600,
    parameter DATABITS    = 8,
    parameter PARITY_EN   = 1,
    parameter PARITY_TYPE = 0
)(
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  tx_en,
    input  logic [DATABITS-1:0]   tx_data_in,
    input  logic                  rx_data,
    output logic                  tx_data,
    output logic                  tx_done,
    output logic [DATABITS-1:0]   rx_data_out,
    output logic                  rx_done,
    output logic                  error_flag,
    output logic                  baud_tick,
    output logic                  tick_16x
);

    logic tx_busy, stop_error, parity_error;

    baud_gen #(
        .SYS_FREQ (SYS_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) baud_inst (.*);

    uart_tx #(
        .DATABITS   (DATABITS),
        .PARITY_EN  (PARITY_EN),
        .PARITY_TYPE(PARITY_TYPE)
    ) tx_inst (
        .clk      (clk),
        .reset    (reset),
        .data_in  (tx_data_in),
        .tx_en    (tx_en),
        .baud_tick(baud_tick),
        .tx_data  (tx_data),
        .tx_busy  (tx_busy)
    );

    uart_rx #(
        .DATABITS   (DATABITS),
        .PARITY_EN  (PARITY_EN),
        .PARITY_TYPE(PARITY_TYPE)
    ) rx_inst (
        .clk         (clk),
        .reset       (reset),
        .rx_data     (rx_data),
        .tick_16x    (tick_16x),
        .data_out    (rx_data_out),
        .rx_done     (rx_done),
        .parity_error(parity_error),
        .stop_error  (stop_error)
    );

    assign tx_done    = ~tx_busy;
    assign error_flag = parity_error | stop_error;

endmodule