`timescale 1 ns / 1 ps
// `default_nettype none
// `define DEBUG

`ifdef DEBUG
  `define debug(debug_command) debug_command
`else
  `define debug(debug_command)
`endif

module picorv32_alu #(
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
	// from IO
	input  clk,
	input  resetn,
	// from Instruction Decoder
	input  instr_and,
	input  instr_andi,
	input  instr_beq,
	input  instr_bge,
	input  instr_bgeu,
	input  instr_bne,
	input  instr_or,
	input  instr_ori,
	input  instr_sub,
	input  instr_xor,
	input  instr_xori,
	input  is_compare,
	input  is_lui_auipc_jal_jalr_addi_add_sub,
	input  is_slti_blt_slt,
	input  is_sltiu_bltu_sltu,
	// from FSM
	// from Datapath
	input [31:0] reg_op1,
	input [31:0] reg_op2,
	output reg [31:0] alu_out,
	output reg  alu_out_0
	);
	
	reg [31:0] alu_add_sub;
	reg  alu_eq;
	reg  alu_lts;
	reg  alu_ltu;
	
	generate if (TWO_CYCLE_ALU) begin
		always @(posedge clk) begin
			if(!resetn) begin
				alu_add_sub <= 0;
				alu_eq <= 0;
				alu_lts <= 0;
				alu_ltu <= 0;
			end else begin
				alu_add_sub <= instr_sub ? reg_op1 - reg_op2 : reg_op1 + reg_op2;
				alu_eq <= reg_op1 == reg_op2;
				alu_lts <= $signed(reg_op1) < $signed(reg_op2);
				alu_ltu <= reg_op1 < reg_op2;
			end
		end
	end else begin
		always @* begin
			alu_add_sub = instr_sub ? reg_op1 - reg_op2 : reg_op1 + reg_op2;
			alu_eq = reg_op1 == reg_op2;
			alu_lts = $signed(reg_op1) < $signed(reg_op2);
			alu_ltu = reg_op1 < reg_op2;
		end
	end endgenerate

	always @* begin
		(* parallel_case, full_case *)
		case (1'b1)
			instr_beq:
				alu_out_0 = alu_eq;
			instr_bne:
				alu_out_0 = !alu_eq;
			instr_bge:
				alu_out_0 = !alu_lts;
			instr_bgeu:
				alu_out_0 = !alu_ltu;
			is_slti_blt_slt:
				alu_out_0 = alu_lts;
			is_sltiu_bltu_sltu:
				alu_out_0 = alu_ltu;
			default:
				alu_out_0 = 'b0;//'bx;
		endcase

		(* parallel_case, full_case *)
		case (1'b1)
			is_lui_auipc_jal_jalr_addi_add_sub:
				alu_out = alu_add_sub;
			is_compare:
				alu_out = alu_out_0;
			instr_xori || instr_xor:
				alu_out = reg_op1 ^ reg_op2;
			instr_ori || instr_or:
				alu_out = reg_op1 | reg_op2;
			instr_andi || instr_and:
				alu_out = reg_op1 & reg_op2;
			default:
				alu_out = 'b0;//'bx;
		endcase
	end
endmodule
