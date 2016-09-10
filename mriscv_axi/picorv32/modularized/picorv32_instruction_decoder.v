`timescale 1 ns / 1 ps
// `default_nettype none
// `define DEBUG

`ifdef DEBUG
  `define debug(debug_command) debug_command
`else
  `define debug(debug_command)
`endif

module picorv32_instruction_decoder #(
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
	parameter  irqregs_offset = 32,
	parameter  regindex_bits = 6
) (
	// from IO
	input  clk,
	input  resetn,
	// from Memory Interface
	input  mem_do_rinst,
	input  mem_done,
	input [31:0] mem_rdata_latched,
	input [31:0] mem_rdata_q,
	// from FSM, ALU, Datapath
	output reg [63:0] ascii_instr,
	output reg [31:0] decoded_imm,
	output reg [31:0] decoded_imm_uj,
	output reg [regindex_bits-1:0] decoded_rd,
	output reg [regindex_bits-1:0] decoded_rs1,
	output reg [regindex_bits-1:0] decoded_rs2,
	output reg  instr_add,
	output reg  instr_addi,
	output reg  instr_and,
	output reg  instr_andi,
	output reg  instr_auipc,
	output reg  instr_beq,
	output reg  instr_bge,
	output reg  instr_bgeu,
	output reg  instr_blt,
	output reg  instr_bltu,
	output reg  instr_bne,
	output reg  instr_getq,
	output reg  instr_jal,
	output reg  instr_jalr,
	output reg  instr_lb,
	output reg  instr_lbu,
	output reg  instr_lh,
	output reg  instr_lhu,
	output reg  instr_lui,
	output reg  instr_lw,
	output reg  instr_maskirq,
	output reg  instr_or,
	output reg  instr_ori,
	output reg  instr_rdcycle,
	output reg  instr_rdcycleh,
	output reg  instr_rdinstr,
	output reg  instr_rdinstrh,
	output reg  instr_retirq,
	output reg  instr_sb,
	output reg  instr_setq,
	output reg  instr_sh,
	output reg  instr_sll,
	output reg  instr_slli,
	output reg  instr_slt,
	output reg  instr_slti,
	output reg  instr_sltiu,
	output reg  instr_sltu,
	output reg  instr_sra,
	output reg  instr_srai,
	output reg  instr_srl,
	output reg  instr_srli,
	output reg  instr_sub,
	output reg  instr_sw,
	output reg  instr_timer,
	output      instr_trap,
	output reg  instr_waitirq,
	output reg  instr_xor,
	output reg  instr_xori,
	output reg  is_alu_reg_imm,
	output reg  is_alu_reg_reg,
	output reg  is_beq_bne_blt_bge_bltu_bgeu,
	output reg  is_compare,
	output reg  is_jalr_addi_slti_sltiu_xori_ori_andi,
	output reg  is_lb_lh_lw_lbu_lhu,
	output reg  is_lbu_lhu_lw,
	output reg  is_lui_auipc_jal,
	output reg  is_lui_auipc_jal_jalr_addi_add_sub,
	output      is_rdcycle_rdcycleh_rdinstr_rdinstrh,
	output reg  is_sb_sh_sw,
	output reg  is_sll_srl_sra,
	output reg  is_slli_srli_srai,
	output reg  is_slti_blt_slt,
	output reg  is_sltiu_bltu_sltu,
	output reg [31:0] pcpi_insn,
	input  decoder_pseudo_trigger,
	input  decoder_trigger,
	input  decoder_trigger_q
	);
	
	
	reg [63:0] new_ascii_instr;

	assign instr_trap = (CATCH_ILLINSN || ENABLE_PCPI) && !{instr_lui, instr_auipc, instr_jal, instr_jalr,
			instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu,
			instr_lb, instr_lh, instr_lw, instr_lbu, instr_lhu, instr_sb, instr_sh, instr_sw,
			instr_addi, instr_slti, instr_sltiu, instr_xori, instr_ori, instr_andi, instr_slli, instr_srli, instr_srai,
			instr_add, instr_sub, instr_sll, instr_slt, instr_sltu, instr_xor, instr_srl, instr_sra, instr_or, instr_and,
			instr_rdcycle, instr_rdcycleh, instr_rdinstr, instr_rdinstrh,
			instr_getq, instr_setq, instr_retirq, instr_maskirq, instr_waitirq, instr_timer};
	
	assign is_rdcycle_rdcycleh_rdinstr_rdinstrh = |{instr_rdcycle, instr_rdcycleh, instr_rdinstr, instr_rdinstrh};

	always @* begin
		if (instr_lui)      new_ascii_instr = "lui";
		else if (instr_auipc)    new_ascii_instr = "auipc";
		else if (instr_jal)      new_ascii_instr = "jal";
		else if (instr_jalr)     new_ascii_instr = "jalr";

		else if (instr_beq)      new_ascii_instr = "beq";
		else if (instr_bne)      new_ascii_instr = "bne";
		else if (instr_blt)      new_ascii_instr = "blt";
		else if (instr_bge)      new_ascii_instr = "bge";
		else if (instr_bltu)     new_ascii_instr = "bltu";
		else if (instr_bgeu)     new_ascii_instr = "bgeu";

		else if (instr_lb)       new_ascii_instr = "lb";
		else if (instr_lh)       new_ascii_instr = "lh";
		else if (instr_lw)       new_ascii_instr = "lw";
		else if (instr_lbu)      new_ascii_instr = "lbu";
		else if (instr_lhu)      new_ascii_instr = "lhu";
		else if (instr_sb)       new_ascii_instr = "sb";
		else if (instr_sh)       new_ascii_instr = "sh";
		else if (instr_sw)       new_ascii_instr = "sw";

		else if (instr_addi)     new_ascii_instr = "addi";
		else if (instr_slti)     new_ascii_instr = "slti";
		else if (instr_sltiu)    new_ascii_instr = "sltiu";
		else if (instr_xori)     new_ascii_instr = "xori";
		else if (instr_ori)      new_ascii_instr = "ori";
		else if (instr_andi)     new_ascii_instr = "andi";
		else if (instr_slli)     new_ascii_instr = "slli";
		else if (instr_srli)     new_ascii_instr = "srli";
		else if (instr_srai)     new_ascii_instr = "srai";

		else if (instr_add)      new_ascii_instr = "add";
		else if (instr_sub)      new_ascii_instr = "sub";
		else if (instr_sll)      new_ascii_instr = "sll";
		else if (instr_slt)      new_ascii_instr = "slt";
		else if (instr_sltu)     new_ascii_instr = "sltu";
		else if (instr_xor)      new_ascii_instr = "xor";
		else if (instr_srl)      new_ascii_instr = "srl";
		else if (instr_sra)      new_ascii_instr = "sra";
		else if (instr_or)       new_ascii_instr = "or";
		else if (instr_and)      new_ascii_instr = "and";

		else if (instr_rdcycle)  new_ascii_instr = "rdcycle";
		else if (instr_rdcycleh) new_ascii_instr = "rdcycleh";
		else if (instr_rdinstr)  new_ascii_instr = "rdinstr";
		else if (instr_rdinstrh) new_ascii_instr = "rdinstrh";

		else if (instr_getq)     new_ascii_instr = "getq";
		else if (instr_setq)     new_ascii_instr = "setq";
		else if (instr_retirq)   new_ascii_instr = "retirq";
		else if (instr_maskirq)  new_ascii_instr = "maskirq";
		else if (instr_waitirq)  new_ascii_instr = "waitirq";
		else if (instr_timer)    new_ascii_instr = "timer";
		
		else new_ascii_instr = "";

		if(!resetn) 
			ascii_instr = "";
		else if (decoder_trigger_q)
			ascii_instr = new_ascii_instr;
		else
			ascii_instr = ascii_instr;
	end

	always @(posedge clk) begin
		if (!resetn) begin
			is_lui_auipc_jal <= 1'b0;
			is_lui_auipc_jal_jalr_addi_add_sub <= 1'b0;
			is_slti_blt_slt <= 1'b0;
			is_sltiu_bltu_sltu <= 1'b0;
			is_lbu_lhu_lw <= 1'b0;
			is_compare <= 1'b0;
			instr_lui     <= 1'b0;
			instr_auipc   <= 1'b0;
			instr_jal     <= 1'b0;
			instr_jalr    <= 1'b0;
			instr_retirq  <= 1'b0;
			instr_waitirq <= 1'b0;
			is_beq_bne_blt_bge_bltu_bgeu <= 1'b0;
			is_lb_lh_lw_lbu_lhu          <= 1'b0;
			is_sb_sh_sw                  <= 1'b0;
			is_alu_reg_imm               <= 1'b0;
			is_alu_reg_reg               <= 1'b0;
			decoded_imm_uj				 <= {32{1'b0}};
			decoded_rd					 <= {regindex_bits{1'b0}};
			decoded_rs1					 <= {regindex_bits{1'b0}};
			decoded_rs2					 <= {regindex_bits{1'b0}};
			pcpi_insn				 	 <= {32{1'b0}};
			instr_beq   <= 1'b0;
			instr_bne   <= 1'b0;
			instr_blt   <= 1'b0;
			instr_bge   <= 1'b0;
			instr_bltu  <= 1'b0;
			instr_bgeu  <= 1'b0;

			instr_lb    <= 1'b0;
			instr_lh    <= 1'b0;
			instr_lw    <= 1'b0;
			instr_lbu   <= 1'b0;
			instr_lhu   <= 1'b0;

			instr_sb    <= 1'b0;
			instr_sh    <= 1'b0;
			instr_sw    <= 1'b0;

			instr_addi  <= 1'b0;
			instr_slti  <= 1'b0;
			instr_sltiu <= 1'b0;
			instr_xori  <= 1'b0;
			instr_ori   <= 1'b0;
			instr_andi  <= 1'b0;

			instr_slli  <= 1'b0;
			instr_srli  <= 1'b0;
			instr_srai  <= 1'b0;

			instr_add   <= 1'b0;
			instr_sub   <= 1'b0;
			instr_sll   <= 1'b0;
			instr_slt   <= 1'b0;
			instr_sltu  <= 1'b0;
			instr_xor   <= 1'b0;
			instr_srl   <= 1'b0;
			instr_sra   <= 1'b0;
			instr_or    <= 1'b0;
			instr_and   <= 1'b0;

			instr_rdcycle  <= 1'b0;
			instr_rdcycleh <= 1'b0;
			instr_rdinstr  <= 1'b0;
			instr_rdinstrh <= 1'b0;

			instr_getq    <= 1'b0;
			instr_setq    <= 1'b0;
			instr_maskirq <= 1'b0;
			instr_timer   <= 1'b0;

			is_slli_srli_srai <= 1'b0;

			is_jalr_addi_slti_sltiu_xori_ori_andi <= 1'b0;

			is_sll_srl_sra <= 1'b0;

			decoded_imm <= {32{1'b0}};
		end else begin
			is_lui_auipc_jal <= |{instr_lui, instr_auipc, instr_jal};
			is_lui_auipc_jal_jalr_addi_add_sub <= |{instr_lui, instr_auipc, instr_jal, instr_jalr, instr_addi, instr_add, instr_sub};
			is_slti_blt_slt <= |{instr_slti, instr_blt, instr_slt};
			is_sltiu_bltu_sltu <= |{instr_sltiu, instr_bltu, instr_sltu};
			is_lbu_lhu_lw <= |{instr_lbu, instr_lhu, instr_lw};
			is_compare <= |{is_beq_bne_blt_bge_bltu_bgeu, instr_slti, instr_slt, instr_sltiu, instr_sltu};

			if (mem_do_rinst && mem_done) begin
				instr_lui     <= mem_rdata_latched[6:0] == 7'b0110111;
				instr_auipc   <= mem_rdata_latched[6:0] == 7'b0010111;
				instr_jal     <= mem_rdata_latched[6:0] == 7'b1101111;
				instr_jalr    <= mem_rdata_latched[6:0] == 7'b1100111;
				instr_retirq  <= mem_rdata_latched[6:0] == 7'b0001011 && mem_rdata_latched[31:25] == 7'b0000010 && ENABLE_IRQ;
				instr_waitirq <= mem_rdata_latched[6:0] == 7'b0001011 && mem_rdata_latched[31:25] == 7'b0000100 && ENABLE_IRQ;

				is_beq_bne_blt_bge_bltu_bgeu <= mem_rdata_latched[6:0] == 7'b1100011;
				is_lb_lh_lw_lbu_lhu          <= mem_rdata_latched[6:0] == 7'b0000011;
				is_sb_sh_sw                  <= mem_rdata_latched[6:0] == 7'b0100011;
				is_alu_reg_imm               <= mem_rdata_latched[6:0] == 7'b0010011;
				is_alu_reg_reg               <= mem_rdata_latched[6:0] == 7'b0110011;

				{ decoded_imm_uj[31:20], decoded_imm_uj[10:1], decoded_imm_uj[11], decoded_imm_uj[19:12], decoded_imm_uj[0] } <= $signed({mem_rdata_latched[31:12], 1'b0});

				decoded_rd <= mem_rdata_latched[11:7];
				decoded_rs2 <= mem_rdata_latched[24:20];

				if (mem_rdata_latched[6:0] == 7'b0001011 && mem_rdata_latched[31:25] == 7'b0000000 && ENABLE_IRQ && ENABLE_IRQ_QREGS)
					decoded_rs1[regindex_bits-1] <= 1; // instr_getq
				else if (mem_rdata_latched[6:0] == 7'b0001011 && mem_rdata_latched[31:25] == 7'b0000010 && ENABLE_IRQ)
					decoded_rs1 <= ENABLE_IRQ_QREGS ? irqregs_offset : 3; // instr_retirq
				else
					decoded_rs1 <= mem_rdata_latched[19:15];
					
			end

			if (decoder_trigger && !decoder_pseudo_trigger) begin
				if (WITH_PCPI) begin
					pcpi_insn <= mem_rdata_q;
				end

				instr_beq   <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b000;
				instr_bne   <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b001;
				instr_blt   <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b100;
				instr_bge   <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b101;
				instr_bltu  <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b110;
				instr_bgeu  <= is_beq_bne_blt_bge_bltu_bgeu && mem_rdata_q[14:12] == 3'b111;

				instr_lb    <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b000;
				instr_lh    <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b001;
				instr_lw    <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b010;
				instr_lbu   <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b100;
				instr_lhu   <= is_lb_lh_lw_lbu_lhu && mem_rdata_q[14:12] == 3'b101;

				instr_sb    <= is_sb_sh_sw && mem_rdata_q[14:12] == 3'b000;
				instr_sh    <= is_sb_sh_sw && mem_rdata_q[14:12] == 3'b001;
				instr_sw    <= is_sb_sh_sw && mem_rdata_q[14:12] == 3'b010;

				instr_addi  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b000;
				instr_slti  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b010;
				instr_sltiu <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b011;
				instr_xori  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b100;
				instr_ori   <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b110;
				instr_andi  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b111;

				instr_slli  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b001 && mem_rdata_q[31:25] == 7'b0000000;
				instr_srli  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0000000;
				instr_srai  <= is_alu_reg_imm && mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0100000;

				instr_add   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b000 && mem_rdata_q[31:25] == 7'b0000000;
				instr_sub   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b000 && mem_rdata_q[31:25] == 7'b0100000;
				instr_sll   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b001 && mem_rdata_q[31:25] == 7'b0000000;
				instr_slt   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b010 && mem_rdata_q[31:25] == 7'b0000000;
				instr_sltu  <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b011 && mem_rdata_q[31:25] == 7'b0000000;
				instr_xor   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b100 && mem_rdata_q[31:25] == 7'b0000000;
				instr_srl   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0000000;
				instr_sra   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0100000;
				instr_or    <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b110 && mem_rdata_q[31:25] == 7'b0000000;
				instr_and   <= is_alu_reg_reg && mem_rdata_q[14:12] == 3'b111 && mem_rdata_q[31:25] == 7'b0000000;

				instr_rdcycle  <= ((mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11000000000000000010) ||
								   (mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11000000000100000010)) && ENABLE_COUNTERS;
				instr_rdcycleh <= ((mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11001000000000000010) ||
								   (mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11001000000100000010)) && ENABLE_COUNTERS;
				instr_rdinstr  <=  (mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11000000001000000010) && ENABLE_COUNTERS;
				instr_rdinstrh <=  (mem_rdata_q[6:0] == 7'b1110011 && mem_rdata_q[31:12] == 'b11001000001000000010) && ENABLE_COUNTERS;

				instr_getq    <= mem_rdata_q[6:0] == 7'b0001011 && mem_rdata_q[31:25] == 7'b0000000 && ENABLE_IRQ && ENABLE_IRQ_QREGS;
				instr_setq    <= mem_rdata_q[6:0] == 7'b0001011 && mem_rdata_q[31:25] == 7'b0000001 && ENABLE_IRQ && ENABLE_IRQ_QREGS;
				instr_maskirq <= mem_rdata_q[6:0] == 7'b0001011 && mem_rdata_q[31:25] == 7'b0000011 && ENABLE_IRQ;
				instr_timer   <= mem_rdata_q[6:0] == 7'b0001011 && mem_rdata_q[31:25] == 7'b0000101 && ENABLE_IRQ && ENABLE_IRQ_TIMER;

				is_slli_srli_srai <= is_alu_reg_imm && |{
					mem_rdata_q[14:12] == 3'b001 && mem_rdata_q[31:25] == 7'b0000000,
					mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0000000,
					mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0100000
				};

				is_jalr_addi_slti_sltiu_xori_ori_andi <= instr_jalr || is_alu_reg_imm && |{
					mem_rdata_q[14:12] == 3'b000,
					mem_rdata_q[14:12] == 3'b010,
					mem_rdata_q[14:12] == 3'b011,
					mem_rdata_q[14:12] == 3'b100,
					mem_rdata_q[14:12] == 3'b110,
					mem_rdata_q[14:12] == 3'b111
				};

				is_sll_srl_sra <= is_alu_reg_reg && |{
					mem_rdata_q[14:12] == 3'b001 && mem_rdata_q[31:25] == 7'b0000000,
					mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0000000,
					mem_rdata_q[14:12] == 3'b101 && mem_rdata_q[31:25] == 7'b0100000
				};

				(* parallel_case *)
				case (1'b1)
					instr_jal:
						decoded_imm <= decoded_imm_uj;
					|{instr_lui, instr_auipc}:
						decoded_imm <= mem_rdata_q[31:12] << 12;
					|{instr_jalr, is_lb_lh_lw_lbu_lhu, is_alu_reg_imm}:
						decoded_imm <= $signed(mem_rdata_q[31:20]);
					is_beq_bne_blt_bge_bltu_bgeu:
						decoded_imm <= $signed({mem_rdata_q[31], mem_rdata_q[7], mem_rdata_q[30:25], mem_rdata_q[11:8], 1'b0});
					is_sb_sh_sw:
						decoded_imm <= $signed({mem_rdata_q[31:25], mem_rdata_q[11:7]});
					default:
						decoded_imm <= 1'b0;//1'bx;
				endcase
			end
		end
	end
endmodule
