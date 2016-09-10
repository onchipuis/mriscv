`timescale 1 ns / 1 ps
// `default_nettype none
// `define DEBUG

`ifdef DEBUG
  `define debug(debug_command) debug_command
`else
  `define debug(debug_command)
`endif

module picorv32_memory_interface #(
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
	input  clk,
	input  resetn,
	output reg [31:0] mem_addr,
	output      mem_done,
	output reg  mem_instr,
	output     [31:0] mem_la_addr,
	output      mem_la_read,
	output reg [31:0] mem_la_wdata,
	output      mem_la_write,
	output reg [ 3:0] mem_la_wstrb,
	output     [31:0] mem_rdata_latched,
	output reg [31:0] mem_rdata_q,
	output reg [31:0] mem_rdata_word,
	output reg  mem_valid,
	output reg [31:0] mem_wdata,
	output reg [ 3:0] mem_wstrb,
	input  mem_do_prefetch,
	input  mem_do_rdata,
	input  mem_do_rinst,
	input  mem_do_wdata,
	input [31:0] mem_rdata,
	input  mem_ready,
	input [1:0] mem_wordsize,
	input [31:0] next_pc,
	input [31:0] reg_op1,
	input [31:0] reg_op2
	);
	
	reg [1:0] mem_state;
	//wire      mem_busy;
	//assign mem_busy = |{mem_do_prefetch, mem_do_rinst, mem_do_rdata, mem_do_wdata};
	assign mem_done = resetn & ((mem_ready & |mem_state & (mem_do_rinst | mem_do_rdata | mem_do_wdata)) | (&mem_state & mem_do_rinst));

	assign mem_la_write = resetn && !mem_state && mem_do_wdata;
	assign mem_la_read = resetn && !mem_state && (mem_do_rinst || mem_do_prefetch || mem_do_rdata);
	assign mem_la_addr = (mem_do_prefetch || mem_do_rinst) ? next_pc : {reg_op1[31:2], 2'b00};

	assign mem_rdata_latched = ((mem_valid && mem_ready) || LATCHED_MEM_RDATA) ? mem_rdata : mem_rdata_q;

	always @* begin
		(* full_case *)
		case (mem_wordsize)
			0: begin
				mem_la_wdata = reg_op2;
				mem_la_wstrb = 4'b1111;
				mem_rdata_word = mem_rdata;
			end
			1: begin
				mem_la_wdata = {2{reg_op2[15:0]}};
				mem_la_wstrb = reg_op1[1] ? 4'b1100 : 4'b0011;
				case (reg_op1[1])
					1'b0: mem_rdata_word = mem_rdata[15: 0];
					1'b1: mem_rdata_word = mem_rdata[31:16];
				endcase
			end
			2: begin
				mem_la_wdata = {4{reg_op2[7:0]}};
				mem_la_wstrb = 4'b0001 << reg_op1[1:0];
				case (reg_op1[1:0])
					2'b00: mem_rdata_word = mem_rdata[ 7: 0];
					2'b01: mem_rdata_word = mem_rdata[15: 8];
					2'b10: mem_rdata_word = mem_rdata[23:16];
					2'b11: mem_rdata_word = mem_rdata[31:24];
				endcase
			end
		endcase
	end

	always @(posedge clk) begin
		if (!resetn) begin
			mem_rdata_q <= {32{1'b0}};
		end else begin 
			if (mem_valid && mem_ready) begin
				mem_rdata_q <= mem_rdata_latched;
			end else begin
				mem_rdata_q <= mem_rdata_q;
			end
		end
	end

	always @(posedge clk) begin
		if (!resetn) begin
			mem_state <= 0;
			mem_valid <= 0;
			mem_addr <= {32{1'b0}};
			mem_wstrb <= {4{1'b0}};
			mem_wdata <= {32{1'b0}};
			mem_instr <= 1'b0;
		end else case (mem_state)
			0: begin
				if (mem_do_prefetch || mem_do_rinst || mem_do_rdata) begin
					mem_valid <= 1;
					mem_instr <= mem_do_prefetch || mem_do_rinst;
					mem_wstrb <= 0;
					mem_state <= 1;
					mem_addr <= mem_la_addr;
					mem_wdata <= mem_la_wdata;
				end else if (mem_do_wdata) begin
					mem_valid <= 1;
					mem_instr <= 0;
					mem_state <= 2;
					mem_addr <= mem_la_addr;
					mem_wdata <= mem_la_wdata;
					mem_wstrb <= mem_la_wstrb;
				end else begin
					mem_valid <= mem_valid;
					mem_instr <= mem_instr;
					mem_state <= mem_state;
					mem_addr <= mem_la_addr;
					mem_wdata <= mem_la_wdata;
					mem_wstrb <= mem_la_wstrb;
				end
			end
			1: begin
				mem_instr <= mem_instr;
				mem_addr <= mem_addr;
				mem_wdata <= mem_wdata;
				mem_wstrb <= mem_wstrb;
				if (mem_ready) begin
					mem_valid <= 0;
					mem_state <= mem_do_rinst || mem_do_rdata ? 0 : 3;
				end else begin
					mem_valid <= mem_valid;
					mem_state <= mem_state;
				end
			end
			2: begin
				mem_instr <= mem_instr;
				mem_addr <= mem_addr;
				mem_wdata <= mem_wdata;
				mem_wstrb <= mem_wstrb;
				if (mem_ready) begin
					mem_valid <= 0;
					mem_state <= 0;
				end else begin
					mem_valid <= mem_valid;
					mem_state <= mem_state;
				end
			end
			3: begin
				mem_instr <= mem_instr;
				mem_addr <= mem_addr;
				mem_wdata <= mem_wdata;
				mem_wstrb <= mem_wstrb;
				mem_valid <= mem_valid;
				if (mem_do_rinst) begin
					mem_state <= 0;
				end else begin
					mem_state <= mem_state;
				end
			end
		endcase
	end
endmodule
