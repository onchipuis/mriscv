`timescale 1 ns / 1 ps
// `default_nettype none
// `define DEBUG

`ifdef DEBUG
  `define debug(debug_command) debug_command
`else
  `define debug(debug_command)
`endif

module picorv32_fsm #(
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
	// from PCPI
	input  pcpi_int_ready,
	input  pcpi_timeout,
	// from Memory Interface
	input  mem_do_prefetch,
	input  mem_do_rdata,
	input  mem_do_rinst,
	input  mem_do_wdata,
	input  mem_done,
	input [1:0] mem_wordsize,
	// from Instruction Decoder
	input  decoder_trigger,
	input  instr_getq,
	input  instr_jal,
	input  instr_maskirq,
	input  instr_retirq,
	input  instr_setq,
	input  instr_timer,
	input  instr_trap,
	input  instr_waitirq,
	input  is_beq_bne_blt_bge_bltu_bgeu,
	input  is_jalr_addi_slti_sltiu_xori_ori_andi,
	input  is_lb_lh_lw_lbu_lhu,
	input  is_lui_auipc_jal,
	input  is_rdcycle_rdcycleh_rdinstr_rdinstrh,
	input  is_sb_sh_sw,
	input  is_sll_srl_sra,
	input  is_slli_srli_srai,
	// from ALU
	input [31:0] reg_op1,
	// from Datapath
	output reg [7:0] cpu_state,
	input  alu_wait,
	input  alu_wait_2,
	input  do_waitirq,
	input  irq_active,
	input [31:0] irq_mask,
	input [31:0] irq_pending,
	input [1:0] irq_state,
	input [31:0] reg_pc,
	input [4:0] reg_sh
	);
	integer idx;
	always @(posedge clk) begin
		if (!resetn) begin
			cpu_state <= cpu_state_fetch;
		end else begin
			
			(* parallel_case, full_case *)
			case (cpu_state)
				cpu_state_trap: begin
					cpu_state <= cpu_state;
				end

				cpu_state_fetch: begin
					
					if (ENABLE_IRQ && ((decoder_trigger && !irq_active && |(irq_pending & ~irq_mask)) || irq_state)) begin
						cpu_state <= cpu_state;
					end else
					if (ENABLE_IRQ && (decoder_trigger || do_waitirq) && instr_waitirq) begin
						cpu_state <= cpu_state;
					end else
					if (decoder_trigger) begin
						if (!instr_jal) begin
							cpu_state <= cpu_state_ld_rs1;
						end
					end
				end

				cpu_state_ld_rs1: begin
					(* parallel_case *)
					case (1'b1)
						(CATCH_ILLINSN || WITH_PCPI) && instr_trap: begin
							if (WITH_PCPI) begin
								if (ENABLE_REGS_DUALPORT) begin
									if (pcpi_int_ready) begin
										cpu_state <= cpu_state_fetch;
									end else
									if (CATCH_ILLINSN && pcpi_timeout) begin
										if (ENABLE_IRQ && !irq_mask[irq_sbreak] && !irq_active) begin
											cpu_state <= cpu_state_fetch;
										end else
											cpu_state <= cpu_state_trap;
									end
								end else begin
									cpu_state <= cpu_state_ld_rs2;
								end
							end else begin
								if (ENABLE_IRQ && !irq_mask[irq_sbreak] && !irq_active) begin
									cpu_state <= cpu_state_fetch;
								end else
									cpu_state <= cpu_state_trap;
							end
						end
						ENABLE_COUNTERS && is_rdcycle_rdcycleh_rdinstr_rdinstrh: begin
							cpu_state <= cpu_state_fetch;
						end
						is_lui_auipc_jal: begin
							cpu_state <= cpu_state_exec;
						end
						ENABLE_IRQ && ENABLE_IRQ_QREGS && instr_getq: begin
							cpu_state <= cpu_state_fetch;
						end
						ENABLE_IRQ && ENABLE_IRQ_QREGS && instr_setq: begin
							cpu_state <= cpu_state_fetch;
						end
						ENABLE_IRQ && instr_retirq: begin
							cpu_state <= cpu_state_fetch;
						end
						ENABLE_IRQ && instr_maskirq: begin
							cpu_state <= cpu_state_fetch;
						end
						ENABLE_IRQ && ENABLE_IRQ_TIMER && instr_timer: begin
							cpu_state <= cpu_state_fetch;
						end
						is_lb_lh_lw_lbu_lhu: begin
							cpu_state <= cpu_state_ldmem;
						end
						is_slli_srli_srai: begin
							cpu_state <= cpu_state_shift;
						end
						is_jalr_addi_slti_sltiu_xori_ori_andi: begin
							cpu_state <= cpu_state_exec;
						end
						default: begin
							if (ENABLE_REGS_DUALPORT) begin
								(* parallel_case *)
								case (1'b1)
									is_sb_sh_sw: begin
										cpu_state <= cpu_state_stmem;
									end
									is_sll_srl_sra: begin
										cpu_state <= cpu_state_shift;
									end
									default: begin
										cpu_state <= cpu_state_exec;
									end
								endcase
							end else
								cpu_state <= cpu_state_ld_rs2;
						end
					endcase
				end

				cpu_state_ld_rs2: begin
					(* parallel_case *)
					case (1'b1)
						WITH_PCPI && instr_trap: begin
							if (pcpi_int_ready) begin
								cpu_state <= cpu_state_fetch;
							end else
							if (CATCH_ILLINSN && pcpi_timeout) begin
								if (ENABLE_IRQ && !irq_mask[irq_sbreak] && !irq_active) begin
									cpu_state <= cpu_state_fetch;
								end else
									cpu_state <= cpu_state_trap;
							end
						end
						is_sb_sh_sw: begin
							cpu_state <= cpu_state_stmem;
						end
						is_sll_srl_sra: begin
							cpu_state <= cpu_state_shift;
						end
						default: begin
							cpu_state <= cpu_state_exec;
						end
					endcase
				end

				cpu_state_exec: begin
					if ((TWO_CYCLE_ALU || TWO_CYCLE_COMPARE) && (alu_wait || alu_wait_2)) begin
						cpu_state <= cpu_state;
					end else
					if (is_beq_bne_blt_bge_bltu_bgeu) begin
						if (mem_done)
							cpu_state <= cpu_state_fetch;
					end else begin
						cpu_state <= cpu_state_fetch;
					end
				end

				cpu_state_shift: begin
					if (reg_sh == 0) begin
						cpu_state <= cpu_state_fetch;
					end
				end

				cpu_state_stmem: begin
					if (!mem_do_prefetch || mem_done) begin
						if (!mem_do_prefetch && mem_done) begin
							cpu_state <= cpu_state_fetch;
						end
					end
				end

				cpu_state_ldmem: begin
					if (!mem_do_prefetch || mem_done) begin
						if (!mem_do_prefetch && mem_done) begin
							cpu_state <= cpu_state_fetch;
						end
					end
				end
			endcase

			if (CATCH_MISALIGN /*&& resetn*/ && (mem_do_rdata || mem_do_wdata)) begin
				if (mem_wordsize == 0 && reg_op1[1:0] != 0) begin
					if (!(ENABLE_IRQ && !irq_mask[irq_buserror] && !irq_active)) begin
						cpu_state <= cpu_state_trap;
					end 
				end
				if (mem_wordsize == 1 && reg_op1[0] != 0) begin
					`debug($display("MISALIGNED HALFWORD: 0x%08x", reg_op1);)
					if (!(ENABLE_IRQ && !irq_mask[irq_buserror] && !irq_active)) begin
						cpu_state <= cpu_state_trap;
					end 
				end
			end
			if (CATCH_MISALIGN /*&& resetn*/ && mem_do_rinst && reg_pc[1:0] != 0) begin
				`debug($display("MISALIGNED INSTRUCTION: 0x%08x", reg_pc);)
				if (!(ENABLE_IRQ && !irq_mask[irq_buserror] && !irq_active)) begin
					cpu_state <= cpu_state_trap;
				end 
			end
		
		end
	end
endmodule
