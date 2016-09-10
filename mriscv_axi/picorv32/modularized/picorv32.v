/*
 *  PicoRV32 -- A Small RISC-V (RV32I) Processor Core
 *
 *  Copyright (C) 2015  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`timescale 1 ns / 1 ps
// `default_nettype none
// `define DEBUG

`ifdef DEBUG
  `define debug(debug_command) debug_command
`else
  `define debug(debug_command)
`endif


/***************************************************************
 * picorv32
 ***************************************************************/

module picorv32 #(
	parameter [ 0:0] ENABLE_COUNTERS = 1,
	parameter [ 0:0] ENABLE_REGS_16_31 = 1,
	parameter [ 0:0] ENABLE_REGS_DUALPORT = 1,
	parameter [ 0:0] LATCHED_MEM_RDATA = 0,
	parameter [ 0:0] TWO_STAGE_SHIFT = 1,
	parameter [ 0:0] TWO_CYCLE_COMPARE = 0,
	parameter [ 0:0] TWO_CYCLE_ALU = 0,
	parameter [ 0:0] CATCH_MISALIGN = 1,
	parameter [ 0:0] CATCH_ILLINSN = 1,
	parameter [ 0:0] ENABLE_PCPI = 0,
	parameter [ 0:0] ENABLE_MUL = 1,
	parameter [ 0:0] ENABLE_IRQ = 1,
	parameter [ 0:0] ENABLE_IRQ_QREGS = 1,
	parameter [ 0:0] ENABLE_IRQ_TIMER = 1,
	parameter [31:0] MASKED_IRQ = 32'h 0000_0000,
	parameter [31:0] LATCHED_IRQ = 32'h ffff_ffff,
	parameter [31:0] PROGADDR_RESET = 32'h 0000_0000,
	parameter [31:0] PROGADDR_IRQ = 32'h 0000_0010
) (
	input clk, resetn,
	output wire trap,

	output wire        mem_valid,
	output wire        mem_instr,
	input             mem_ready,

	output wire [31:0] mem_addr,
	output wire [31:0] mem_wdata,
	output wire [ 3:0] mem_wstrb,
	input      [31:0] mem_rdata,

	// Look-Ahead Interface
	output            mem_la_read,
	output            mem_la_write,
	output     [31:0] mem_la_addr,
	output wire [31:0] mem_la_wdata,
	output wire [ 3:0] mem_la_wstrb,

	// Pico Co-Processor Interface (PCPI)
	/*output wire        pcpi_valid,
	output wire [31:0] pcpi_insn,
	output     [31:0] pcpi_rs1,
	output     [31:0] pcpi_rs2,
	input             pcpi_wr,
	input      [31:0] pcpi_rd,
	input             pcpi_wait,
	input             pcpi_ready,*/

	// IRQ Interface
	input      [31:0] irq,
	output wire [31:0] eoi
);

	wire        pcpi_valid;
	wire [31:0] pcpi_insn;
	wire     [31:0] pcpi_rs1;
	wire     [31:0] pcpi_rs2;
	wire             pcpi_wr;
	wire      [31:0] pcpi_rd;
	wire             pcpi_wait;
	wire             pcpi_ready;
	
	localparam integer irq_timer = 0;
	localparam integer irq_sbreak = 1;
	localparam integer irq_buserror = 2;

	localparam integer irqregs_offset = ENABLE_REGS_16_31 ? 32 : 16;
	localparam integer regfile_size = (ENABLE_REGS_16_31 ? 32 : 16) + 4*ENABLE_IRQ*ENABLE_IRQ_QREGS;
	localparam integer regindex_bits = (ENABLE_REGS_16_31 ? 5 : 4) + ENABLE_IRQ*ENABLE_IRQ_QREGS;

	localparam WITH_PCPI = ENABLE_PCPI || ENABLE_MUL;

	wire [63:0] count_cycle, count_instr;
	wire [31:0] reg_pc, reg_next_pc, reg_op1, reg_op2, reg_out;
	wire [31:0] cpuregs [0:regfile_size-1];
	wire [4:0] reg_sh;

	assign pcpi_rs1 = reg_op1;
	assign pcpi_rs2 = reg_op2;

	wire [31:0] next_pc;

	wire irq_active;
	wire [31:0] irq_mask;
	wire [31:0] irq_pending;
	wire [31:0] timer;

	wire        pcpi_int_wr;
	wire [31:0] pcpi_int_rd;
	wire        pcpi_int_wait;
	wire        pcpi_int_ready;
	
	// The wordsize, Read/Write in specific wordsize. 0->32, 1->16, 2->8
	wire [1:0] mem_wordsize;	
	// The word itself 
	wire [31:0] mem_rdata_word;
	wire [31:0] mem_rdata_q;
	wire mem_do_prefetch;
	wire mem_do_rinst;
	wire mem_do_rdata;
	wire mem_do_wdata;

	wire mem_busy;
	wire mem_done;
	wire [31:0] mem_rdata_latched;
	
	wire instr_lui, instr_auipc, instr_jal, instr_jalr;
	wire instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu;
	wire instr_lb, instr_lh, instr_lw, instr_lbu, instr_lhu, instr_sb, instr_sh, instr_sw;
	wire instr_addi, instr_slti, instr_sltiu, instr_xori, instr_ori, instr_andi, instr_slli, instr_srli, instr_srai;
	wire instr_add, instr_sub, instr_sll, instr_slt, instr_sltu, instr_xor, instr_srl, instr_sra, instr_or, instr_and;
	wire instr_rdcycle, instr_rdcycleh, instr_rdinstr, instr_rdinstrh;
	wire instr_getq, instr_setq, instr_retirq, instr_maskirq, instr_waitirq, instr_timer;
	wire instr_trap;

	wire [regindex_bits-1:0] decoded_rd, decoded_rs1, decoded_rs2;
	wire [31:0] decoded_imm, decoded_imm_uj;
	wire decoder_trigger;
	wire decoder_trigger_q;
	wire decoder_pseudo_trigger;

	wire is_lui_auipc_jal;
	wire is_lb_lh_lw_lbu_lhu;
	wire is_slli_srli_srai;
	wire is_jalr_addi_slti_sltiu_xori_ori_andi;
	wire is_sb_sh_sw;
	wire is_sll_srl_sra;
	wire is_lui_auipc_jal_jalr_addi_add_sub;
	wire is_slti_blt_slt;
	wire is_sltiu_bltu_sltu;
	wire is_beq_bne_blt_bge_bltu_bgeu;
	wire is_lbu_lhu_lw;
	wire is_alu_reg_imm;
	wire is_alu_reg_reg;
	wire is_compare;
	
	wire is_rdcycle_rdcycleh_rdinstr_rdinstrh;
	wire [63:0] ascii_instr;

	localparam cpu_state_trap   = 8'b10000000;
	localparam cpu_state_fetch  = 8'b01000000;
	localparam cpu_state_ld_rs1 = 8'b00100000;
	localparam cpu_state_ld_rs2 = 8'b00010000;
	localparam cpu_state_exec   = 8'b00001000;
	localparam cpu_state_shift  = 8'b00000100;
	localparam cpu_state_stmem  = 8'b00000010;
	localparam cpu_state_ldmem  = 8'b00000001;

	wire [7:0] cpu_state;
	wire [1:0] irq_state;

	reg [127:0] ascii_state;
	
	always @* begin
		if (cpu_state == cpu_state_trap)  	    ascii_state = "trap";
		else if (cpu_state == cpu_state_fetch)  ascii_state = "fetch";
		else if (cpu_state == cpu_state_ld_rs1) ascii_state = "ld_rs1";
		else if (cpu_state == cpu_state_ld_rs2) ascii_state = "ld_rs2";
		else if (cpu_state == cpu_state_exec)   ascii_state = "exec";
		else if (cpu_state == cpu_state_shift)  ascii_state = "shift";
		else if (cpu_state == cpu_state_stmem)  ascii_state = "stmem";
		else if (cpu_state == cpu_state_ldmem)  ascii_state = "ldmem";
		else ascii_state = "";
	end

	wire pcpi_timeout;

	wire do_waitirq;

	wire [31:0] alu_out, alu_out_q;
	wire alu_wait, alu_wait_2, alu_out_0;
	
picorv32_pcpi #(
	.ENABLE_COUNTERS(ENABLE_COUNTERS),
	.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
	.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
	.LATCHED_MEM_RDATA(LATCHED_MEM_RDATA),
	.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
	.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
	.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
	.CATCH_MISALIGN(CATCH_MISALIGN),
	.CATCH_ILLINSN(CATCH_ILLINSN),
	.ENABLE_PCPI(ENABLE_PCPI),
	.ENABLE_MUL(ENABLE_MUL),
	.ENABLE_IRQ(ENABLE_IRQ),
	.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
	.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
	.MASKED_IRQ(MASKED_IRQ),
	.LATCHED_IRQ(LATCHED_IRQ),
	.PROGADDR_RESET(PROGADDR_RESET),
	.PROGADDR_IRQ(PROGADDR_IRQ)
) picorv32_pcpi_inst (
	.pcpi_int_rd(pcpi_int_rd),
	.pcpi_int_ready(pcpi_int_ready),
	.pcpi_int_wait(pcpi_int_wait),
	.pcpi_int_wr(pcpi_int_wr),
	.clk(clk),
	.pcpi_insn(pcpi_insn),
	.pcpi_rd(pcpi_rd),
	.pcpi_ready(pcpi_ready),
	.pcpi_rs1(pcpi_rs1),
	.pcpi_rs2(pcpi_rs2),
	.pcpi_valid(pcpi_valid),
	.pcpi_wait(pcpi_wait),
	.pcpi_wr(pcpi_wr),
	.resetn(resetn)
	);
	
picorv32_memory_interface #(
	.ENABLE_COUNTERS(ENABLE_COUNTERS),
	.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
	.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
	.LATCHED_MEM_RDATA(LATCHED_MEM_RDATA),
	.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
	.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
	.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
	.CATCH_MISALIGN(CATCH_MISALIGN),
	.CATCH_ILLINSN(CATCH_ILLINSN),
	.ENABLE_PCPI(ENABLE_PCPI),
	.ENABLE_MUL(ENABLE_MUL),
	.ENABLE_IRQ(ENABLE_IRQ),
	.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
	.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
	.MASKED_IRQ(MASKED_IRQ),
	.LATCHED_IRQ(LATCHED_IRQ),
	.PROGADDR_RESET(PROGADDR_RESET),
	.PROGADDR_IRQ(PROGADDR_IRQ)
) picorv32_memory_interface_inst (
	.mem_addr(mem_addr),
	.mem_done(mem_done),
	.mem_instr(mem_instr),
	.mem_la_addr(mem_la_addr),
	.mem_la_read(mem_la_read),
	.mem_la_wdata(mem_la_wdata),
	.mem_la_write(mem_la_write),
	.mem_la_wstrb(mem_la_wstrb),
	.mem_rdata_latched(mem_rdata_latched),
	.mem_rdata_q(mem_rdata_q),
	.mem_rdata_word(mem_rdata_word),
	.mem_valid(mem_valid),
	.mem_wdata(mem_wdata),
	.mem_wstrb(mem_wstrb),
	.clk(clk),
	.mem_do_prefetch(mem_do_prefetch),
	.mem_do_rdata(mem_do_rdata),
	.mem_do_rinst(mem_do_rinst),
	.mem_do_wdata(mem_do_wdata),
	.mem_rdata(mem_rdata),
	.mem_ready(mem_ready),
	.mem_wordsize(mem_wordsize),
	.next_pc(next_pc),
	.reg_op1(reg_op1),
	.reg_op2(reg_op2),
	.resetn(resetn)
	);
	
picorv32_instruction_decoder #(
	.ENABLE_COUNTERS(ENABLE_COUNTERS),
	.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
	.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
	.LATCHED_MEM_RDATA(LATCHED_MEM_RDATA),
	.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
	.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
	.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
	.CATCH_MISALIGN(CATCH_MISALIGN),
	.CATCH_ILLINSN(CATCH_ILLINSN),
	.ENABLE_PCPI(ENABLE_PCPI),
	.ENABLE_MUL(ENABLE_MUL),
	.ENABLE_IRQ(ENABLE_IRQ),
	.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
	.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
	.MASKED_IRQ(MASKED_IRQ),
	.LATCHED_IRQ(LATCHED_IRQ),
	.PROGADDR_RESET(PROGADDR_RESET),
	.PROGADDR_IRQ(PROGADDR_IRQ),
	.WITH_PCPI(WITH_PCPI),
	.irqregs_offset(irqregs_offset),
	.regindex_bits(regindex_bits)
) picorv32_instruction_decoder_inst (
	.ascii_instr(ascii_instr),
	.decoded_imm(decoded_imm),
	.decoded_imm_uj(decoded_imm_uj),
	.decoded_rd(decoded_rd),
	.decoded_rs1(decoded_rs1),
	.decoded_rs2(decoded_rs2),
	.instr_add(instr_add),
	.instr_addi(instr_addi),
	.instr_and(instr_and),
	.instr_andi(instr_andi),
	.instr_auipc(instr_auipc),
	.instr_beq(instr_beq),
	.instr_bge(instr_bge),
	.instr_bgeu(instr_bgeu),
	.instr_blt(instr_blt),
	.instr_bltu(instr_bltu),
	.instr_bne(instr_bne),
	.instr_getq(instr_getq),
	.instr_jal(instr_jal),
	.instr_jalr(instr_jalr),
	.instr_lb(instr_lb),
	.instr_lbu(instr_lbu),
	.instr_lh(instr_lh),
	.instr_lhu(instr_lhu),
	.instr_lui(instr_lui),
	.instr_lw(instr_lw),
	.instr_maskirq(instr_maskirq),
	.instr_or(instr_or),
	.instr_ori(instr_ori),
	.instr_rdcycle(instr_rdcycle),
	.instr_rdcycleh(instr_rdcycleh),
	.instr_rdinstr(instr_rdinstr),
	.instr_rdinstrh(instr_rdinstrh),
	.instr_retirq(instr_retirq),
	.instr_sb(instr_sb),
	.instr_setq(instr_setq),
	.instr_sh(instr_sh),
	.instr_sll(instr_sll),
	.instr_slli(instr_slli),
	.instr_slt(instr_slt),
	.instr_slti(instr_slti),
	.instr_sltiu(instr_sltiu),
	.instr_sltu(instr_sltu),
	.instr_sra(instr_sra),
	.instr_srai(instr_srai),
	.instr_srl(instr_srl),
	.instr_srli(instr_srli),
	.instr_sub(instr_sub),
	.instr_sw(instr_sw),
	.instr_timer(instr_timer),
	.instr_trap(instr_trap),
	.instr_waitirq(instr_waitirq),
	.instr_xor(instr_xor),
	.instr_xori(instr_xori),
	.is_alu_reg_imm(is_alu_reg_imm),
	.is_alu_reg_reg(is_alu_reg_reg),
	.is_beq_bne_blt_bge_bltu_bgeu(is_beq_bne_blt_bge_bltu_bgeu),
	.is_compare(is_compare),
	.is_jalr_addi_slti_sltiu_xori_ori_andi(is_jalr_addi_slti_sltiu_xori_ori_andi),
	.is_lb_lh_lw_lbu_lhu(is_lb_lh_lw_lbu_lhu),
	.is_lbu_lhu_lw(is_lbu_lhu_lw),
	.is_lui_auipc_jal(is_lui_auipc_jal),
	.is_lui_auipc_jal_jalr_addi_add_sub(is_lui_auipc_jal_jalr_addi_add_sub),
	.is_rdcycle_rdcycleh_rdinstr_rdinstrh(is_rdcycle_rdcycleh_rdinstr_rdinstrh),
	.is_sb_sh_sw(is_sb_sh_sw),
	.is_sll_srl_sra(is_sll_srl_sra),
	.is_slli_srli_srai(is_slli_srli_srai),
	.is_slti_blt_slt(is_slti_blt_slt),
	.is_sltiu_bltu_sltu(is_sltiu_bltu_sltu),
	.pcpi_insn(pcpi_insn),
	.clk(clk),
	.decoder_pseudo_trigger(decoder_pseudo_trigger),
	.decoder_trigger(decoder_trigger),
	.decoder_trigger_q(decoder_trigger_q),
	.mem_do_rinst(mem_do_rinst),
	.mem_done(mem_done),
	.mem_rdata_latched(mem_rdata_latched),
	.mem_rdata_q(mem_rdata_q),
	.resetn(resetn)
	);
	
picorv32_alu #(
	.ENABLE_COUNTERS(ENABLE_COUNTERS),
	.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
	.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
	.LATCHED_MEM_RDATA(LATCHED_MEM_RDATA),
	.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
	.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
	.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
	.CATCH_MISALIGN(CATCH_MISALIGN),
	.CATCH_ILLINSN(CATCH_ILLINSN),
	.ENABLE_PCPI(ENABLE_PCPI),
	.ENABLE_MUL(ENABLE_MUL),
	.ENABLE_IRQ(ENABLE_IRQ),
	.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
	.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
	.MASKED_IRQ(MASKED_IRQ),
	.LATCHED_IRQ(LATCHED_IRQ),
	.PROGADDR_RESET(PROGADDR_RESET),
	.PROGADDR_IRQ(PROGADDR_IRQ)
) picorv32_alu_inst (
	.alu_out(alu_out),
	.alu_out_0(alu_out_0),
	.clk(clk),
	.instr_and(instr_and),
	.instr_andi(instr_andi),
	.instr_beq(instr_beq),
	.instr_bge(instr_bge),
	.instr_bgeu(instr_bgeu),
	.instr_bne(instr_bne),
	.instr_or(instr_or),
	.instr_ori(instr_ori),
	.instr_sub(instr_sub),
	.instr_xor(instr_xor),
	.instr_xori(instr_xori),
	.is_compare(is_compare),
	.is_lui_auipc_jal_jalr_addi_add_sub(is_lui_auipc_jal_jalr_addi_add_sub),
	.is_slti_blt_slt(is_slti_blt_slt),
	.is_sltiu_bltu_sltu(is_sltiu_bltu_sltu),
	.reg_op1(reg_op1),
	.reg_op2(reg_op2),
	.resetn(resetn)
	);
	
picorv32_fsm #(
	.ENABLE_COUNTERS(ENABLE_COUNTERS),
	.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
	.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
	.LATCHED_MEM_RDATA(LATCHED_MEM_RDATA),
	.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
	.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
	.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
	.CATCH_MISALIGN(CATCH_MISALIGN),
	.CATCH_ILLINSN(CATCH_ILLINSN),
	.ENABLE_PCPI(ENABLE_PCPI),
	.ENABLE_MUL(ENABLE_MUL),
	.ENABLE_IRQ(ENABLE_IRQ),
	.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
	.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
	.MASKED_IRQ(MASKED_IRQ),
	.LATCHED_IRQ(LATCHED_IRQ),
	.PROGADDR_RESET(PROGADDR_RESET),
	.PROGADDR_IRQ(PROGADDR_IRQ),
	.WITH_PCPI(WITH_PCPI),
	.irq_buserror(irq_buserror),
	.irq_sbreak(irq_sbreak),
	.cpu_state_exec(cpu_state_exec),
	.cpu_state_fetch(cpu_state_fetch),
	.cpu_state_ld_rs1(cpu_state_ld_rs1),
	.cpu_state_ld_rs2(cpu_state_ld_rs2),
	.cpu_state_ldmem(cpu_state_ldmem),
	.cpu_state_shift(cpu_state_shift),
	.cpu_state_stmem(cpu_state_stmem),
	.cpu_state_trap(cpu_state_trap)
) picorv32_fsm_inst (
	.cpu_state(cpu_state),
	.alu_wait(alu_wait),
	.alu_wait_2(alu_wait_2),
	.clk(clk),
	.decoder_trigger(decoder_trigger),
	.do_waitirq(do_waitirq),
	.instr_getq(instr_getq),
	.instr_jal(instr_jal),
	.instr_maskirq(instr_maskirq),
	.instr_retirq(instr_retirq),
	.instr_setq(instr_setq),
	.instr_timer(instr_timer),
	.instr_trap(instr_trap),
	.instr_waitirq(instr_waitirq),
	.irq_active(irq_active),
	.irq_mask(irq_mask),
	.irq_pending(irq_pending),
	.irq_state(irq_state),
	.is_beq_bne_blt_bge_bltu_bgeu(is_beq_bne_blt_bge_bltu_bgeu),
	.is_jalr_addi_slti_sltiu_xori_ori_andi(is_jalr_addi_slti_sltiu_xori_ori_andi),
	.is_lb_lh_lw_lbu_lhu(is_lb_lh_lw_lbu_lhu),
	.is_lui_auipc_jal(is_lui_auipc_jal),
	.is_rdcycle_rdcycleh_rdinstr_rdinstrh(is_rdcycle_rdcycleh_rdinstr_rdinstrh),
	.is_sb_sh_sw(is_sb_sh_sw),
	.is_sll_srl_sra(is_sll_srl_sra),
	.is_slli_srli_srai(is_slli_srli_srai),
	.mem_do_prefetch(mem_do_prefetch),
	.mem_do_rdata(mem_do_rdata),
	.mem_do_rinst(mem_do_rinst),
	.mem_do_wdata(mem_do_wdata),
	.mem_done(mem_done),
	.mem_wordsize(mem_wordsize),
	.pcpi_int_ready(pcpi_int_ready),
	.pcpi_timeout(pcpi_timeout),
	.reg_op1(reg_op1),
	.reg_pc(reg_pc),
	.reg_sh(reg_sh),
	.resetn(resetn)
	);
	
picorv32_datapath #(
	.ENABLE_COUNTERS(ENABLE_COUNTERS),
	.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
	.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
	.LATCHED_MEM_RDATA(LATCHED_MEM_RDATA),
	.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
	.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
	.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
	.CATCH_MISALIGN(CATCH_MISALIGN),
	.CATCH_ILLINSN(CATCH_ILLINSN),
	.ENABLE_PCPI(ENABLE_PCPI),
	.ENABLE_MUL(ENABLE_MUL),
	.ENABLE_IRQ(ENABLE_IRQ),
	.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
	.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
	.MASKED_IRQ(MASKED_IRQ),
	.LATCHED_IRQ(LATCHED_IRQ),
	.PROGADDR_RESET(PROGADDR_RESET),
	.PROGADDR_IRQ(PROGADDR_IRQ),
	.WITH_PCPI(WITH_PCPI),
	.irq_buserror(irq_buserror),
	.irq_sbreak(irq_sbreak),
	.irq_timer(irq_timer),
	.irqregs_offset(irqregs_offset),
	.regfile_size(regfile_size),
	.regindex_bits(regindex_bits),
	.cpu_state_exec(cpu_state_exec),
	.cpu_state_fetch(cpu_state_fetch),
	.cpu_state_ld_rs1(cpu_state_ld_rs1),
	.cpu_state_ld_rs2(cpu_state_ld_rs2),
	.cpu_state_ldmem(cpu_state_ldmem),
	.cpu_state_shift(cpu_state_shift),
	.cpu_state_stmem(cpu_state_stmem),
	.cpu_state_trap(cpu_state_trap)
) picorv32_datapath_inst (
	.alu_wait(alu_wait),
	.alu_wait_2(alu_wait_2),
	.decoder_pseudo_trigger(decoder_pseudo_trigger),
	.decoder_trigger(decoder_trigger),
	.decoder_trigger_q(decoder_trigger_q),
	.do_waitirq(do_waitirq),
	.eoi(eoi),
	.irq_active(irq_active),
	.irq_mask(irq_mask),
	.irq_pending(irq_pending),
	.irq_state(irq_state),
	.mem_do_prefetch(mem_do_prefetch),
	.mem_do_rdata(mem_do_rdata),
	.mem_do_rinst(mem_do_rinst),
	.mem_do_wdata(mem_do_wdata),
	.mem_wordsize(mem_wordsize),
	.pcpi_timeout(pcpi_timeout),
	.pcpi_valid(pcpi_valid),
	.reg_op1(reg_op1),
	.reg_op2(reg_op2),
	.reg_pc(reg_pc),
	.reg_sh(reg_sh),
	.trap(trap),
	.next_pc(next_pc),
	.alu_out(alu_out),
	.alu_out_0(alu_out_0),
	.ascii_instr(ascii_instr),
	.clk(clk),
	.cpu_state(cpu_state),
	.decoded_imm(decoded_imm),
	.decoded_imm_uj(decoded_imm_uj),
	.decoded_rd(decoded_rd),
	.decoded_rs1(decoded_rs1),
	.decoded_rs2(decoded_rs2),
	.instr_getq(instr_getq),
	.instr_jal(instr_jal),
	.instr_jalr(instr_jalr),
	.instr_lb(instr_lb),
	.instr_lbu(instr_lbu),
	.instr_lh(instr_lh),
	.instr_lhu(instr_lhu),
	.instr_lui(instr_lui),
	.instr_lw(instr_lw),
	.instr_maskirq(instr_maskirq),
	.instr_rdcycle(instr_rdcycle),
	.instr_rdcycleh(instr_rdcycleh),
	.instr_rdinstr(instr_rdinstr),
	.instr_rdinstrh(instr_rdinstrh),
	.instr_retirq(instr_retirq),
	.instr_sb(instr_sb),
	.instr_setq(instr_setq),
	.instr_sh(instr_sh),
	.instr_sll(instr_sll),
	.instr_slli(instr_slli),
	.instr_sra(instr_sra),
	.instr_srai(instr_srai),
	.instr_srl(instr_srl),
	.instr_srli(instr_srli),
	.instr_sw(instr_sw),
	.instr_timer(instr_timer),
	.instr_trap(instr_trap),
	.instr_waitirq(instr_waitirq),
	.irq(irq),
	.is_beq_bne_blt_bge_bltu_bgeu(is_beq_bne_blt_bge_bltu_bgeu),
	.is_jalr_addi_slti_sltiu_xori_ori_andi(is_jalr_addi_slti_sltiu_xori_ori_andi),
	.is_lb_lh_lw_lbu_lhu(is_lb_lh_lw_lbu_lhu),
	.is_lbu_lhu_lw(is_lbu_lhu_lw),
	.is_lui_auipc_jal(is_lui_auipc_jal),
	.is_rdcycle_rdcycleh_rdinstr_rdinstrh(is_rdcycle_rdcycleh_rdinstr_rdinstrh),
	.is_sb_sh_sw(is_sb_sh_sw),
	.is_slli_srli_srai(is_slli_srli_srai),
	.mem_done(mem_done),
	.mem_rdata_word(mem_rdata_word),
	.pcpi_int_rd(pcpi_int_rd),
	.pcpi_int_ready(pcpi_int_ready),
	.pcpi_int_wait(pcpi_int_wait),
	.pcpi_int_wr(pcpi_int_wr),
	.resetn(resetn)
);

endmodule
