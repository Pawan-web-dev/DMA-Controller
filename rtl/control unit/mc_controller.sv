// ============================================================
// File: mc_controller.sv   [NEW]
//
// Multicycle RV32I control FSM.
//
// Why this replaces controller.sv / main_decoder.sv:
// main_decoder.sv asserts ALL control signals for an instruction
// in a single combinational shot - correct for a single-cycle
// datapath, where the whole instruction really does happen in
// one clock. A multicycle datapath needs a DIFFERENT set of
// control signals active in different clock cycles for the same
// instruction (fetch this cycle, decode next, execute after
// that...), which a flat combinational decoder cannot express.
// That's a state machine's job, so this file is new rather than
// a patch to the old one. main_decoder.sv/controller.sv are left
// untouched in case you build the single-cycle version too.
//
// Supported instructions: lw, sw, R-type (add/sub/and/or/xor/
// slt/sll/srl), I-type ALU (addi/andi/ori/xori/slti/slli/srli),
// beq, jal.
//
// NOT implemented yet (extend here later): jalr, bne/blt/bge/
// bltu/bgeu, lui, auipc, fence, ecall/ebreak, csr instructions.
// An unrecognized opcode is currently just skipped (decode falls
// straight back to fetch) rather than trapping - fine for a
// teaching/bring-up core, not spec-correct illegal-instruction
// behavior.
//
// mem_ready is the ONLY thing this FSM waits on for a bus
// transaction - it does not assume any fixed number of cycles.
// Whatever sits behind the bus (a plain SRAM wrapper today, an
// AXI-Lite/APB/Wishbone bridge later, or a bus that's currently
// granted to DMA instead) just needs to hold mem_ready low until
// the transaction is really done.
// ============================================================

module mc_controller (
    input  logic        clk,
    input  logic        rst_n,

    // decoded instruction fields (IR fields, held by datapath)
    input  logic [6:0]  op,
    input  logic [2:0]  funct3,
    input  logic        funct7b5,

    // status from datapath
    input  logic        zero_f,     // valid in S_BRANCH (A - B)
    input  logic        mem_ready,  // bus handshake

    // ---- datapath control outputs ----
    output logic        ir_write,
    output logic        pcs_write,
    output logic        reg_a_write,
    output logic        reg_b_write,
    output logic        alu_out_write,
    output logic        mdr_write,

    output logic        alu_src_b_sel,  // 0 = B (reg), 1 = imm
    output logic [2:0]  alu_control,

    output logic        i_or_d,         // 0 = PC, 1 = ALUOut (bus address src)
    output logic        mem_req,
    output logic        mem_we,

    output logic        pc_write,
    output logic [1:0]  pc_src,         // 00 = +4, 01 = branch target, 10 = jal target

    output logic        reg_write,
    output logic [1:0]  result_src      // 00 = ALUOut, 01 = MDR, 10 = PC (jal link)
);

    typedef enum logic [3:0] {
        S_FETCH, S_DECODE,
        S_EXEC_ALU, S_ALU_WB,
        S_MEM_ADR, S_MEM_READ, S_MEM_WB, S_MEM_WRITE,
        S_BRANCH, S_JAL
    } state_t;

    state_t state, next_state;

    localparam logic [6:0] OP_LW    = 7'b0000011;
    localparam logic [6:0] OP_SW    = 7'b0100011;
    localparam logic [6:0] OP_RTYPE = 7'b0110011;
    localparam logic [6:0] OP_ITYPE = 7'b0010011;
    localparam logic [6:0] OP_BEQ   = 7'b1100011;
    localparam logic [6:0] OP_JAL   = 7'b1101111;

    // ---- state register ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) state <= S_FETCH;
        else        state <= next_state;
    end

    // ---- next-state logic ----
    // Holding next_state = state (the default) is what makes a
    // state "wait": as long as mem_ready is low, this evaluates
    // to no state change at all, for as many cycles as it takes.
    always_comb begin
        next_state = state;
        case (state)
            S_FETCH:    if (mem_ready) next_state = S_DECODE;
            S_DECODE:
                case (op)
                    OP_LW, OP_SW:  next_state = S_MEM_ADR;
                    OP_RTYPE,
                    OP_ITYPE:      next_state = S_EXEC_ALU;
                    OP_BEQ:        next_state = S_BRANCH;
                    OP_JAL:        next_state = S_JAL;
                    default:       next_state = S_FETCH; // unsupported op: skip
                endcase
            S_EXEC_ALU:  next_state = S_ALU_WB;
            S_ALU_WB:    next_state = S_FETCH;
            S_MEM_ADR:   next_state = (op == OP_SW) ? S_MEM_WRITE : S_MEM_READ;
            S_MEM_READ:  if (mem_ready) next_state = S_MEM_WB;
            S_MEM_WB:    next_state = S_FETCH;
            S_MEM_WRITE: if (mem_ready) next_state = S_FETCH;
            S_BRANCH:    next_state = S_FETCH;
            S_JAL:       next_state = S_FETCH;
            default:     next_state = S_FETCH;
        endcase
    end

    // ---- ALU control decode ----
    logic [1:0] alu_op;
    aludec u_aludec (
        .opb5      (op[5]),
        .funct3    (funct3),
        .funct7b5  (funct7b5),
        .ALUOp     (alu_op),
        .ALUControl(alu_control)
    );

    // ---- Moore outputs (state-dependent; zero_f only affects
    //      the branch decision, so this is technically Mealy on
    //      that one signal - everything else is pure Moore) ----
    always_comb begin
        ir_write      = 1'b0;
        pcs_write     = 1'b0;
        reg_a_write   = 1'b0;
        reg_b_write   = 1'b0;
        alu_out_write = 1'b0;
        mdr_write     = 1'b0;
        alu_src_b_sel = 1'b0;
        alu_op        = 2'b10;
        i_or_d        = 1'b0;
        mem_req       = 1'b0;
        mem_we        = 1'b0;
        pc_write      = 1'b0;
        pc_src        = 2'b00;
        reg_write     = 1'b0;
        result_src    = 2'b00;

        case (state)
            S_FETCH: begin
                mem_req = 1'b1;
                i_or_d  = 1'b0;             // address = PC
                if (mem_ready) begin
                    ir_write  = 1'b1;
                    pcs_write = 1'b1;       // snapshot address of this instruction
                    pc_write  = 1'b1;
                    pc_src    = 2'b00;      // PC <= PC + 4
                end
            end
            S_DECODE: begin
                reg_a_write = 1'b1;
                reg_b_write = 1'b1;
            end
            S_EXEC_ALU: begin
                alu_src_b_sel = (op == OP_ITYPE); // I-type: imm, R-type: reg B
                alu_op        = 2'b10;
                alu_out_write = 1'b1;
            end
            S_ALU_WB: begin
                reg_write  = 1'b1;
                result_src = 2'b00; // ALUOut
            end
            S_MEM_ADR: begin
                alu_src_b_sel = 1'b1;   // A + imm
                alu_op        = 2'b00;  // force add
                alu_out_write = 1'b1;
            end
            S_MEM_READ: begin
                mem_req = 1'b1;
                i_or_d  = 1'b1;         // address = ALUOut
                if (mem_ready) mdr_write = 1'b1;
            end
            S_MEM_WB: begin
                reg_write  = 1'b1;
                result_src = 2'b01; // MDR
            end
            S_MEM_WRITE: begin
                mem_req = 1'b1;
                mem_we  = 1'b1;
                i_or_d  = 1'b1;         // address = ALUOut
            end
            S_BRANCH: begin
                alu_op = 2'b01;         // force subtract -> zero_f
                if (zero_f) begin
                    pc_write = 1'b1;
                    pc_src   = 2'b01;   // PC <= PCS + immB
                end
            end
            S_JAL: begin
                reg_write  = 1'b1;
                result_src = 2'b10;     // link = PC (already PCS+4)
                pc_write   = 1'b1;
                pc_src     = 2'b10;     // PC <= PCS + immJ
            end
            default: ;
        endcase
    end

endmodule
