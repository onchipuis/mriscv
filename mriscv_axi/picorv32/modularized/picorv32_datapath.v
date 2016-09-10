`timescale 1 ns / 1 ps
// `default_nettype none
// `define DEBUG

`ifdef DEBUG
  `define debug(debug_command) debug_command
`else
  `define debug(debug_command)
`endif

module picorv32_datapath #(
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
	parameter [31:0] PROGADDR_IRQ = 32'h 0000_0010,
	parameter  WITH_PCPI = 1,
	parameter  irq_buserror = 2,
	parameter  irq_sbreak = 1,
	parameter  irq_timer = 0,
	parameter  irqregs_offset = 32,
	parameter  regfile_size = 36,
	parameter  regindex_bits = 6,
	parameter  [7:0] cpu_state_exec =   8'b10000000,
	parameter  [7:0] cpu_state_fetch =  8'b01000000,
	parameter  [7:0] cpu_state_ld_rs1 = 8'b00100000,
	parameter  [7:0] cpu_state_ld_rs2 = 8'b00010000,
	parameter  [7:0] cpu_state_ldmem =  8'b00001000,
	parameter  [7:0] cpu_state_shift =  8'b00000100,
	parameter  [7:0] cpu_state_stmem =  8'b00000010,
	parameter  [7:0] cpu_state_trap =   8'b00000001
) (
	// from IO
	input  clk,
	input  resetn,
	input [31:0] irq,
	output reg [31:0] eoi,
	output reg  trap,
	// from PCPI
	output reg  pcpi_timeout,
	output reg  pcpi_valid,
	input [31:0] pcpi_int_rd,
	input  pcpi_int_ready,
	input  pcpi_int_wait,
	input  pcpi_int_wr,
	// from Memory Interface
	output [31:0] next_pc,
	output reg  mem_do_prefetch,
	output reg  mem_do_rdata,
	output reg  mem_do_rinst,
	output reg  mem_do_wdata,
	output reg [1:0] mem_wordsize,
	input  mem_done,
	input [31:0] mem_rdata_word,
	// from Instruction Decoder
	output reg  decoder_pseudo_trigger,
	output reg  decoder_trigger,
	output reg  decoder_trigger_q,
	input  instr_getq,
	input  instr_jal,
	input  instr_jalr,
	input  instr_lb,
	input  instr_lbu,
	input  instr_lh,
	input  instr_lhu,
	input  instr_lui,
	input  instr_lw,
	input  instr_maskirq,
	input  instr_rdcycle,
	input  instr_rdcycleh,
	input  instr_rdinstr,
	input  instr_rdinstrh,
	input  instr_retirq,
	input  instr_sb,
	input  instr_setq,
	input  instr_sh,
	input  instr_sll,
	input  instr_slli,
	input  instr_sra,
	input  instr_srai,
	input  instr_srl,
	input  instr_srli,
	input  instr_sw,
	input  instr_timer,
	input  instr_trap,
	input  instr_waitirq,
	input  is_beq_bne_blt_bge_bltu_bgeu,
	input  is_jalr_addi_slti_sltiu_xori_ori_andi,
	input  is_lb_lh_lw_lbu_lhu,
	input  is_lbu_lhu_lw,
	input  is_lui_auipc_jal,
	input  is_rdcycle_rdcycleh_rdinstr_rdinstrh,
	input  is_sb_sh_sw,
	input  is_slli_srli_srai,
	input [31:0] decoded_imm,
	input [31:0] decoded_imm_uj,
	input [regindex_bits-1:0] decoded_rd,
	input [regindex_bits-1:0] decoded_rs1,
	input [regindex_bits-1:0] decoded_rs2,
	input [63:0] ascii_instr,
	// from ALU
	input [31:0] alu_out,
	input  alu_out_0,
	output reg [31:0] reg_op1,
	output reg [31:0] reg_op2,
	// from FSM
	output reg  alu_wait,
	output reg  alu_wait_2,
	output reg  do_waitirq,
	output reg  irq_active,
	output reg [31:0] irq_mask,
	output reg [31:0] irq_pending,
	output reg [1:0] irq_state,
	output reg [31:0] reg_pc,
	output reg [4:0] reg_sh,
	input [7:0] cpu_state
   );
   
	// FILTERED INTERNAL
   
	reg [31:0] alu_out_0_q;
	reg [31:0] alu_out_q;
	reg  latched_branch;
	reg  latched_is_lb;
	reg  latched_is_lh;
	reg  latched_is_lu;
	reg [regindex_bits-1:0] latched_rd;
	reg  latched_stalu;
	reg  latched_store;
	reg  set_mem_do_rdata;
	reg  set_mem_do_rinst;
	reg  set_mem_do_wdata;
	reg [63:0] count_cycle;
	reg [63:0] count_instr;
	reg [31:0] current_pc;
	reg [31:0] next_irq_pending;
	reg [3:0] pcpi_timeout_counter;
	reg [31:0] reg_next_pc;
	reg [31:0] reg_out;
	reg [31:0] timer;
   
	reg [31:0] cpuregs [0:regfile_size-1];
	
	
	assign next_pc = latched_store && latched_branch ? reg_out : reg_next_pc;
	integer idx;
	always @(posedge clk) begin
		if (!resetn) begin
			trap <= 0;
			reg_sh <= 'b0;
			reg_out <= 'b0;
			set_mem_do_rinst = 0;
			set_mem_do_rdata = 0;
			set_mem_do_wdata = 0;
			alu_out_0_q <= 'b0;
			alu_out_q <= 'b0;
			alu_wait <= 0;
			alu_wait_2 <= 0;
			pcpi_timeout_counter <= ~0;
			pcpi_timeout <= 0;
			count_cycle <= 0;
			next_irq_pending = 0;
			irq_pending <= 0;
			timer <= 0;
			reg_pc <= PROGADDR_RESET;
			reg_next_pc <= PROGADDR_RESET;
			//if (ENABLE_COUNTERS)
				count_instr <= 0;
			latched_store <= 0;
			latched_stalu <= 0;
			latched_branch <= 0;
			latched_is_lu <= 0;
			latched_is_lh <= 0;
			latched_is_lb <= 0;
			latched_rd <= 0;
			pcpi_valid <= 0;
			irq_active <= 0;
			irq_mask <= ~0;
			next_irq_pending = 0;
			irq_state <= 0;
			eoi <= 0;
			timer <= 0;
			decoder_trigger_q <= 0;
			decoder_trigger <= 0;
			decoder_pseudo_trigger <= 0;
			do_waitirq <= 0;
			mem_do_prefetch <= 0;
			mem_do_rinst <= 0;
			mem_do_rdata <= 0;
			mem_do_wdata <= 0;
			mem_wordsize <= 0;
			reg_op1 <= 0;
			reg_op2 <= 0;
			current_pc = PROGADDR_RESET;
			for(idx = 0; idx < regfile_size; idx = idx + 1)
				cpuregs[idx] <= 0;
		end else begin
			trap <= 0;
			reg_sh <= 'b0;
			reg_out <= 'b0;
			set_mem_do_rinst = 0;
			set_mem_do_rdata = 0;
			set_mem_do_wdata = 0;

			alu_out_0_q <= alu_out_0;
			alu_out_q <= alu_out;

			alu_wait <= 0;
			alu_wait_2 <= 0;

			if (WITH_PCPI && CATCH_ILLINSN) begin
				if (/*resetn && */pcpi_valid && !pcpi_int_wait) begin
					if (pcpi_timeout_counter)
						pcpi_timeout_counter <= pcpi_timeout_counter - 1;
				end else
					pcpi_timeout_counter <= ~0;
				pcpi_timeout <= !pcpi_timeout_counter;
			end

			if (ENABLE_COUNTERS)
				count_cycle <= /*resetn ?*/ count_cycle + 1 /*: 0*/;

			next_irq_pending = ENABLE_IRQ ? irq_pending & LATCHED_IRQ : 'b0; // 'bx;

			if (ENABLE_IRQ && ENABLE_IRQ_TIMER && timer) begin
				if (timer - 1 == 0)
					next_irq_pending[irq_timer] = 1;
				timer <= timer - 1;
			end

			if (ENABLE_IRQ) begin
				next_irq_pending = next_irq_pending | irq;
			end

			decoder_trigger_q <= decoder_trigger;
			decoder_trigger <= mem_do_rinst && mem_done;
			decoder_pseudo_trigger <= 0;
			do_waitirq <= 0;

			(* parallel_case, full_case *)
			case (cpu_state)
				cpu_state_trap: begin
					trap <= 1;
				end

				cpu_state_fetch: begin
					mem_do_rinst <= !decoder_trigger && !do_waitirq;
					mem_wordsize <= 0;

					current_pc = reg_next_pc;

					(* parallel_case *)
					case (1'b1)
						latched_branch: begin
							current_pc = latched_store ? (latched_stalu ? alu_out_q : reg_out) : reg_next_pc;
							`debug($display("ST_RD:  %2d 0x%08x, BRANCH 0x%08x", latched_rd, reg_pc + 4, current_pc);)
							cpuregs[latched_rd] <= reg_pc + 4;
						end
						latched_store && !latched_branch: begin
							`debug($display("ST_RD:  %2d 0x%08x", latched_rd, latched_stalu ? alu_out_q : reg_out);)
							cpuregs[latched_rd] <= latched_stalu ? alu_out_q : reg_out;
						end
						ENABLE_IRQ && irq_state[0]: begin
							cpuregs[latched_rd] <= current_pc;
							current_pc = PROGADDR_IRQ;
							irq_active <= 1;
							mem_do_rinst <= 1;
						end
						ENABLE_IRQ && irq_state[1]: begin
							eoi <= irq_pending & ~irq_mask;
							cpuregs[latched_rd] <= irq_pending & ~irq_mask;
							next_irq_pending = next_irq_pending & irq_mask;
						end
					endcase

					reg_pc <= current_pc;
					reg_next_pc <= current_pc;

					latched_store <= 0;
					latched_stalu <= 0;
					latched_branch <= 0;
					latched_is_lu <= 0;
					latched_is_lh <= 0;
					latched_is_lb <= 0;
					latched_rd <= decoded_rd;

					if (ENABLE_IRQ && ((decoder_trigger && !irq_active && |(irq_pending & ~irq_mask)) || irq_state)) begin
						irq_state <=
							irq_state == 2'b00 ? 2'b01 :
							irq_state == 2'b01 ? 2'b10 : 2'b00;
						if (ENABLE_IRQ_QREGS)
							latched_rd <= irqregs_offset | irq_state[0];
						else
							latched_rd <= irq_state[0] ? 4 : 3;
					end else
					if (ENABLE_IRQ && (decoder_trigger || do_waitirq) && instr_waitirq) begin
						if (irq_pending) begin
							latched_store <= 1;
							reg_out <= irq_pending;
							reg_next_pc <= current_pc + 4;
							mem_do_rinst <= 1;
						end else
							do_waitirq <= 1;
					end else
					if (decoder_trigger) begin
						`debug($display("-- %-0t", $time);)
						reg_next_pc <= current_pc + 4;
						if (ENABLE_COUNTERS)
							count_instr <= count_instr + 1;
						if (instr_jal) begin
							`debug($display("DECODE: 0x%08x jal", current_pc);)
							mem_do_rinst <= 1;
							reg_next_pc <= current_pc + decoded_imm_uj;
							latched_branch <= 1;
						end else begin
							mem_do_rinst <= 0;
							mem_do_prefetch <= !instr_jalr && !instr_retirq;
						end
					end
				end

				cpu_state_ld_rs1: begin
					reg_op1 <= 'b0;//'bx;
					reg_op2 <= 'b0;//'bx;
					`debug($display("DECODE: 0x%08x %-0s", reg_pc, ascii_instr ? ascii_instr : "UNKNOWN");)

					(* parallel_case *)
					case (1'b1)
						(CATCH_ILLINSN || WITH_PCPI) && instr_trap: begin
							if (WITH_PCPI) begin
								`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
								reg_op1 <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
								if (ENABLE_REGS_DUALPORT) begin
									pcpi_valid <= 1;
									`debug($display("LD_RS2: %2d 0x%08x", decoded_rs2, decoded_rs2 ? cpuregs[decoded_rs2] : 0);)
									reg_sh <= decoded_rs2 ? cpuregs[decoded_rs2] : 0;
									reg_op2 <= decoded_rs2 ? cpuregs[decoded_rs2] : 0;
									if (pcpi_int_ready) begin
										mem_do_rinst <= 1;
										pcpi_valid <= 0;
										reg_out <= pcpi_int_rd;
										latched_store <= pcpi_int_wr;
									end else
									if (CATCH_ILLINSN && pcpi_timeout) begin
										`debug($display("SBREAK OR UNSUPPORTED INSN AT 0x%08x", reg_pc);)
										if (ENABLE_IRQ && !irq_mask[irq_sbreak] && !irq_active) begin
											next_irq_pending[irq_sbreak] = 1;
										end 
									end
								end 
							end else begin
								`debug($display("SBREAK OR UNSUPPORTED INSN AT 0x%08x", reg_pc);)
								if (ENABLE_IRQ && !irq_mask[irq_sbreak] && !irq_active) begin
									next_irq_pending[irq_sbreak] = 1;
								end 
							end
						end
						ENABLE_COUNTERS && is_rdcycle_rdcycleh_rdinstr_rdinstrh: begin
							(* parallel_case, full_case *)
							case (1'b1)
								instr_rdcycle:
									reg_out <= count_cycle[31:0];
								instr_rdcycleh:
									reg_out <= count_cycle[63:32];
								instr_rdinstr:
									reg_out <= count_instr[31:0];
								instr_rdinstrh:
									reg_out <= count_instr[63:32];
							endcase
							latched_store <= 1;
						end
						is_lui_auipc_jal: begin
							reg_op1 <= instr_lui ? 0 : reg_pc;
							reg_op2 <= decoded_imm;
							if (TWO_CYCLE_ALU)
								alu_wait <= 1;
							else
								mem_do_rinst <= mem_do_prefetch;
						end
						ENABLE_IRQ && ENABLE_IRQ_QREGS && instr_getq: begin
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							reg_out <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
							latched_store <= 1;
						end
						ENABLE_IRQ && ENABLE_IRQ_QREGS && instr_setq: begin
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							reg_out <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
							latched_rd <= latched_rd | irqregs_offset;
							latched_store <= 1;
						end
						ENABLE_IRQ && instr_retirq: begin
							eoi <= 0;
							irq_active <= 0;
							latched_branch <= 1;
							latched_store <= 1;
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							reg_out <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
						end
						ENABLE_IRQ && instr_maskirq: begin
							latched_store <= 1;
							reg_out <= irq_mask;
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							irq_mask <= (decoded_rs1 ? cpuregs[decoded_rs1] : 0) | MASKED_IRQ;
						end
						ENABLE_IRQ && ENABLE_IRQ_TIMER && instr_timer: begin
							latched_store <= 1;
							reg_out <= timer;
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							timer <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
						end
						is_lb_lh_lw_lbu_lhu: begin
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							reg_op1 <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
							mem_do_rinst <= 1;
						end
						is_slli_srli_srai: begin
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							reg_op1 <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
							reg_sh <= decoded_rs2;
						end
						is_jalr_addi_slti_sltiu_xori_ori_andi: begin
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							reg_op1 <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
							reg_op2 <= decoded_imm;
							if (TWO_CYCLE_ALU)
								alu_wait <= 1;
							else
								mem_do_rinst <= mem_do_prefetch;
						end
						default: begin
							`debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, decoded_rs1 ? cpuregs[decoded_rs1] : 0);)
							reg_op1 <= decoded_rs1 ? cpuregs[decoded_rs1] : 0;
							if (ENABLE_REGS_DUALPORT) begin
								`debug($display("LD_RS2: %2d 0x%08x", decoded_rs2, decoded_rs2 ? cpuregs[decoded_rs2] : 0);)
								reg_sh <= decoded_rs2 ? cpuregs[decoded_rs2] : 0;
								reg_op2 <= decoded_rs2 ? cpuregs[decoded_rs2] : 0;
								(* parallel_case *)
								case (1'b1)
									is_sb_sh_sw: begin
										mem_do_rinst <= 1;
									end
									default: begin
										if (TWO_CYCLE_ALU || (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu)) begin
											alu_wait_2 <= TWO_CYCLE_ALU && (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu);
											alu_wait <= 1;
										end else
											mem_do_rinst <= mem_do_prefetch;
									end
								endcase
							end 
						end
					endcase
				end

				cpu_state_ld_rs2: begin
					`debug($display("LD_RS2: %2d 0x%08x", decoded_rs2, decoded_rs2 ? cpuregs[decoded_rs2] : 0);)
					reg_sh <= decoded_rs2 ? cpuregs[decoded_rs2] : 0;
					reg_op2 <= decoded_rs2 ? cpuregs[decoded_rs2] : 0;

					(* parallel_case *)
					case (1'b1)
						WITH_PCPI && instr_trap: begin
							pcpi_valid <= 1;
							if (pcpi_int_ready) begin
								mem_do_rinst <= 1;
								pcpi_valid <= 0;
								reg_out <= pcpi_int_rd;
								latched_store <= pcpi_int_wr;
							end else
							if (CATCH_ILLINSN && pcpi_timeout) begin
								`debug($display("SBREAK OR UNSUPPORTED INSN AT 0x%08x", reg_pc);)
								if (ENABLE_IRQ && !irq_mask[irq_sbreak] && !irq_active) begin
									next_irq_pending[irq_sbreak] = 1;
								end 
							end
						end
						is_sb_sh_sw: begin
							mem_do_rinst <= 1;
						end
						default: begin
							if (TWO_CYCLE_ALU || (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu)) begin
								alu_wait_2 <= TWO_CYCLE_ALU && (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu);
								alu_wait <= 1;
							end else
								mem_do_rinst <= mem_do_prefetch;
						end
					endcase
				end

				cpu_state_exec: begin
					latched_store <= TWO_CYCLE_COMPARE ? alu_out_0_q : alu_out_0;
					latched_branch <= TWO_CYCLE_COMPARE ? alu_out_0_q : alu_out_0;
					reg_out <= reg_pc + decoded_imm;
					if ((TWO_CYCLE_ALU || TWO_CYCLE_COMPARE) && (alu_wait || alu_wait_2)) begin
						mem_do_rinst <= mem_do_prefetch && !alu_wait_2;
						alu_wait <= alu_wait_2;
					end else
					if (is_beq_bne_blt_bge_bltu_bgeu) begin
						latched_rd <= 0;
						if (TWO_CYCLE_COMPARE ? alu_out_0_q : alu_out_0) begin
							decoder_trigger <= 0;
							set_mem_do_rinst = 1;
						end
					end else begin
						latched_branch <= instr_jalr;
						latched_store <= 1;
						latched_stalu <= 1;
					end
				end

				cpu_state_shift: begin
					latched_store <= 1;
					if (reg_sh == 0) begin
						reg_out <= reg_op1;
						mem_do_rinst <= mem_do_prefetch;
					end else if (TWO_STAGE_SHIFT && reg_sh >= 4) begin
						(* parallel_case, full_case *)
						case (1'b1)
							instr_slli || instr_sll: reg_op1 <= reg_op1 << 4;
							instr_srli || instr_srl: reg_op1 <= reg_op1 >> 4;
							instr_srai || instr_sra: reg_op1 <= $signed(reg_op1) >>> 4;
						endcase
						reg_sh <= reg_sh - 4;
					end else begin
						(* parallel_case, full_case *)
						case (1'b1)
							instr_slli || instr_sll: reg_op1 <= reg_op1 << 1;
							instr_srli || instr_srl: reg_op1 <= reg_op1 >> 1;
							instr_srai || instr_sra: reg_op1 <= $signed(reg_op1) >>> 1;
						endcase
						reg_sh <= reg_sh - 1;
					end
				end

				cpu_state_stmem: begin
					if (!mem_do_prefetch || mem_done) begin
						if (!mem_do_wdata) begin
							(* parallel_case, full_case *)
							case (1'b1)
								instr_sb: mem_wordsize <= 2;
								instr_sh: mem_wordsize <= 1;
								instr_sw: mem_wordsize <= 0;
							endcase
							reg_op1 <= reg_op1 + decoded_imm;
							set_mem_do_wdata = 1;
						end
						if (!mem_do_prefetch && mem_done) begin
							decoder_trigger <= 1;
							decoder_pseudo_trigger <= 1;
						end
					end
				end

				cpu_state_ldmem: begin
					latched_store <= 1;
					if (!mem_do_prefetch || mem_done) begin
						if (!mem_do_rdata) begin
							(* parallel_case, full_case *)
							case (1'b1)
								instr_lb || instr_lbu: mem_wordsize <= 2;
								instr_lh || instr_lhu: mem_wordsize <= 1;
								instr_lw: mem_wordsize <= 0;
							endcase
							latched_is_lu <= is_lbu_lhu_lw;
							latched_is_lh <= instr_lh;
							latched_is_lb <= instr_lb;
							reg_op1 <= reg_op1 + decoded_imm;
							set_mem_do_rdata = 1;
						end
						if (!mem_do_prefetch && mem_done) begin
							(* parallel_case, full_case *)
							case (1'b1)
								latched_is_lu: reg_out <= mem_rdata_word;
								latched_is_lh: reg_out <= $signed(mem_rdata_word[15:0]);
								latched_is_lb: reg_out <= $signed(mem_rdata_word[7:0]);
							endcase
							decoder_trigger <= 1;
							decoder_pseudo_trigger <= 1;
						end
					end
				end
			endcase

			if (CATCH_MISALIGN /*&& resetn*/ && (mem_do_rdata || mem_do_wdata)) begin
				if (mem_wordsize == 0 && reg_op1[1:0] != 0) begin
					`debug($display("MISALIGNED WORD: 0x%08x", reg_op1);)
					if (ENABLE_IRQ && !irq_mask[irq_buserror] && !irq_active) begin
						next_irq_pending[irq_buserror] = 1;
					end
				end
				if (mem_wordsize == 1 && reg_op1[0] != 0) begin
					`debug($display("MISALIGNED HALFWORD: 0x%08x", reg_op1);)
					if (ENABLE_IRQ && !irq_mask[irq_buserror] && !irq_active) begin
						next_irq_pending[irq_buserror] = 1;
					end 
				end
			end
			if (CATCH_MISALIGN /*&& resetn*/ && mem_do_rinst && reg_pc[1:0] != 0) begin
				`debug($display("MISALIGNED INSTRUCTION: 0x%08x", reg_pc);)
				if (ENABLE_IRQ && !irq_mask[irq_buserror] && !irq_active) begin
					next_irq_pending[irq_buserror] = 1;
				end 
			end

			if (/*!resetn || */mem_done) begin
				mem_do_prefetch <= 0;
				mem_do_rinst <= 0;
				mem_do_rdata <= 0;
				mem_do_wdata <= 0;
			end

			if (set_mem_do_rinst)
				mem_do_rinst <= 1;
			if (set_mem_do_rdata)
				mem_do_rdata <= 1;
			if (set_mem_do_wdata)
				mem_do_wdata <= 1;

			irq_pending <= next_irq_pending & ~MASKED_IRQ;

			reg_pc[1:0] <= 0;
			reg_next_pc[1:0] <= 0;
			current_pc = 'b0;//'bx;
		
		end
	end
endmodule
