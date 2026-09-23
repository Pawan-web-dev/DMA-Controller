// ============================================================
// File: rv_datapath_mc.sv   [NEW]
//
// Multicycle RV32I datapath.
//
// A multicycle design needs a few extra registers beyond a
// single-cycle datapath - IR, a PC "snapshot" (address of the
// instruction currently in IR), A, B, ALUOut, MDR - so a value
// computed in one state survives into a later state even while
// a bus transaction is stalled for an unknown number of cycles
// in between.
//
// Memory is intentionally NOT instantiated here. This module
// only drives/reads a plain bus port (bus_addr/bus_wdata/
// bus_rdata). Memory, peripherals, and (once added) the DMA/
// arbiter all live outside the core, on the other side of that
// port - matching the "memory is not inside the core" decision.
//
// Design note: branch target and jal target are both computed
// with ONE shared adder (PCS + imm_ext), because whichever
// opcode is currently in IR already selects the correct
// immediate type (B-type for beq, J-type for jal) via imm_src -
// no separate adder or extra muxing needed for that.
// ============================================================

module rv_datapath_mc (
    input  logic        clk,
    input  logic        rst_n,

    // ---- control inputs (from mc_controller) ----
    input  logic        ir_write,
    input  logic        pcs_write,
    input  logic        reg_a_write,
    input  logic        reg_b_write,
    input  logic        alu_out_write,
    input  logic        mdr_write,

    input  logic        alu_src_b_sel,
    input  logic [2:0]  alu_control,

    input  logic        i_or_d,
    input  logic [1:0]  pc_src,
    input  logic        pc_write,

    input  logic        reg_write,
    input  logic [1:0]  result_src,

    // ---- status outputs (to mc_controller) ----
    output logic [6:0]  op,
    output logic [2:0]  funct3,
    output logic        funct7b5,
    output logic        zero_f,

    // ---- bus port (shared instruction/data port) ----
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    input  logic [31:0] bus_rdata
);

    // ---- architectural / hidden registers ----
    logic [31:0] PC, PC_next;
    logic [31:0] IR;
    logic [31:0] PCS;      // address of the instruction currently in IR
    logic [31:0] A, B;
    logic [31:0] ALUOut;
    logic [31:0] MDR;

    // ---- instruction field extraction (combinational; IR is
    //      held steady for an instruction's whole state sequence,
    //      so this is safe to leave purely combinational) ----
    assign op       = IR[6:0];
    assign funct3   = IR[14:12];
    assign funct7b5 = IR[30];

    logic [4:0] rs1, rs2, rd;
    assign rs1 = IR[19:15];
    assign rs2 = IR[24:20];
    assign rd  = IR[11:7];

    // ---- immediate-type select, straight from opcode ----
    logic [1:0] imm_src;
    always_comb begin
        case (op)
            7'b0100011: imm_src = 2'b01; // sw  -> S-type
            7'b1100011: imm_src = 2'b10; // beq -> B-type
            7'b1101111: imm_src = 2'b11; // jal -> J-type
            default:    imm_src = 2'b00; // lw, I-type ALU (R-type: unused) -> I-type
        endcase
    end

    logic [31:0] imm_ext;
    imm_extend u_extend (
        .instr (IR[31:7]),
        .immsrc(imm_src),
        .immext(imm_ext)
    );

    // ---- register file ----
    logic [31:0] Ra, Rb, wb_data;
    reg_file u_regfile (
        .clk (clk),
        .we  (reg_write),
        .wd  (wb_data),
        .rs_1(rs1),
        .rs_2(rs2),
        .rd  (rd),
        .Ra  (Ra),
        .Rb  (Rb)
    );

    // ---- ALU ----
    logic [31:0] alu_src_b, alu_out;
    mux_2to1 u_alu_b_mux (.sel(alu_src_b_sel), .A(B), .B(imm_ext), .Y(alu_src_b));
    ALU u_alu (
        .src_A     (A),
        .src_B     (alu_src_b),
        .ALU_select(alu_control),
        .ALU_out   (alu_out),
        .zero_f    (zero_f)
    );

    // ---- PC-relative target adder (shared by branch and jal) ----
    logic [31:0] pc_plus4, target_addr;
    adder_pc u_pc4      (.A(PC),  .Y(pc_plus4));
    adder    u_pc_target(.A(PCS), .B(imm_ext), .Y(target_addr));

    mux_3to1 u_pc_mux (
        .sel(pc_src),
        .A  (pc_plus4),    // 00
        .B  (target_addr), // 01 - branch taken
        .C  (target_addr), // 10 - jal
        .Y  (PC_next)
    );

    // ---- bus address / writeback muxes ----
    mux_2to1 u_addr_mux (.sel(i_or_d), .A(PC), .B(ALUOut), .Y(bus_addr));
    assign bus_wdata = B;

    mux_3to1 u_wb_mux (
        .sel(result_src),
        .A  (ALUOut), // 00
        .B  (MDR),     // 01
        .C  (PC),      // 10 - jal link (PCS + 4, already sitting in PC)
        .Y  (wb_data)
    );

    // ---- registers ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            PC     <= 32'b0;
            IR     <= 32'b0;
            PCS    <= 32'b0;
            A      <= 32'b0;
            B      <= 32'b0;
            ALUOut <= 32'b0;
            MDR    <= 32'b0;
        end else begin
            if (pc_write)      PC     <= PC_next;
            if (ir_write)      IR     <= bus_rdata;
            if (pcs_write)     PCS    <= PC;   // old PC value, before this cycle's +4
            if (reg_a_write)   A      <= Ra;
            if (reg_b_write)   B      <= Rb;
            if (alu_out_write) ALUOut <= alu_out;
            if (mdr_write)     MDR    <= bus_rdata;
        end
    end

endmodule
