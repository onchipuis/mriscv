`timescale 1 ns / 1 ps
// `default_nettype none
// `define DEBUG

`ifdef DEBUG
  `define debug(debug_command) debug_command
`else
  `define debug(debug_command)
`endif

module picorv32_pcpi #(
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
	// from FSM, Datapath
	output reg [31:0] pcpi_int_rd,
	output reg  pcpi_int_ready,
	output reg  pcpi_int_wait,
	output reg  pcpi_int_wr,
	input [31:0] pcpi_insn,
	input [31:0] pcpi_rd,
	input  pcpi_ready,
	input [31:0] pcpi_rs1,
	input [31:0] pcpi_rs2,
	input  pcpi_valid,
	input  pcpi_wait,
	input  pcpi_wr
	);
	
	wire     [31:0] pcpi_mul_rd;
	wire      pcpi_mul_ready;
	wire      pcpi_mul_wait;
	wire      pcpi_mul_wr;

	generate if (ENABLE_MUL) begin
		picorv32_pcpi_mul pcpi_mul (
			.clk       (clk            ),
			.resetn    (resetn         ),
			.pcpi_valid(pcpi_valid     ),
			.pcpi_insn (pcpi_insn      ),
			.pcpi_rs1  (pcpi_rs1       ),
			.pcpi_rs2  (pcpi_rs2       ),
			.pcpi_wr   (pcpi_mul_wr    ),
			.pcpi_rd   (pcpi_mul_rd    ),
			.pcpi_wait (pcpi_mul_wait  ),
			.pcpi_ready(pcpi_mul_ready )
		);
	end else begin
		assign pcpi_mul_wr = 0;
		assign pcpi_mul_rd = 1'b0;//1'bx;
		assign pcpi_mul_wait = 0;
		assign pcpi_mul_ready = 0;
	end endgenerate

	always @* begin
		pcpi_int_wr = 0;
		pcpi_int_rd = 1'b0;//1'bx;
		pcpi_int_wait  = |{ENABLE_PCPI && pcpi_wait,  ENABLE_MUL && pcpi_mul_wait};
		pcpi_int_ready = |{ENABLE_PCPI && pcpi_ready, ENABLE_MUL && pcpi_mul_ready};

		(* parallel_case *)
		case (1'b1)
			ENABLE_PCPI && pcpi_ready: begin
				pcpi_int_wr = pcpi_wr;
				pcpi_int_rd = pcpi_rd;
			end
			ENABLE_MUL && pcpi_mul_ready: begin
				pcpi_int_wr = pcpi_mul_wr;
				pcpi_int_rd = pcpi_mul_rd;
			end
		endcase
	end
endmodule
