// Created by: CKDUR
`timescale 1ns/1ns

module spi_axi_master #
	(
	parameter  			sword = 32,

	/*
	IMPLEMENTATION SETTINGS
	impl: 0,Classic  1,Simulation
	syncing: 0,ByCounterAndDecoder  1,ByMirrorShiftRegister
	*/
	parameter			impl = 0,
	parameter			syncing = 0
	)

	(
	// SPI INTERFACE
	input							CEB,
	input							SCLK,
	input 							DATA,
	output 							DOUT,
	// MISC
	input							RST,
	output 							PICORV_RST,
	// AXI4-lite master memory interface
	
	input			   CLK,
	output reg         axi_awvalid,
	input              axi_awready,
	output [sword-1:0] axi_awaddr,
	output [3-1:0]     axi_awprot,

	output reg         axi_wvalid,
	input              axi_wready,
	output [sword-1:0] axi_wdata,
	output [4-1:0]     axi_wstrb,

	input              axi_bvalid,
	output reg         axi_bready,

	output reg         axi_arvalid,
	input              axi_arready,
	output [sword-1:0] axi_araddr,
	output [3-1:0]     axi_arprot,

	input              axi_rvalid,
	output reg         axi_rready,
	input  [sword-1:0] axi_rdata
    );

	// HELPER
	function integer clogb2;
		input integer value;
		integer 	i;
		begin
			clogb2 = 0;
			for(i = 0; 2**i < value; i = i + 1)
			clogb2 = i + 1;
		end
	endfunction
	
	localparam numbit_instr = 2;			// Nop (00), Read(01), Write(10)
	localparam numbit_address = sword;
	localparam numbit_handshake = numbit_instr+numbit_address+sword;
	localparam numbit_posthandshake = numbit_handshake;
	reg	[numbit_handshake-1:0]	sft_reg;	// Because address + word width
	reg 						we;			// Instruction Write
	reg 						re;			// Instruction Read
	genvar						i;

	// Serial to paralell registers
	always @ (posedge SCLK)
	begin
		if(RST == 1'b0)
		begin
			sft_reg <= {numbit_handshake{1'b0}};					// RESET
		end else if(CEB == 1'b0)
		begin
			sft_reg <= {sft_reg[numbit_handshake-2:0], DATA};		// SHIFT
		end else
		begin
			sft_reg <= sft_reg;										// NOTHING
		end
	end

	// SPI SYNC
	/*
	sync
	+ + + + + + + + + + + + + + + + + + + + + + + + + + + +
	*/
	wire [numbit_posthandshake - 1:0] sync;
	generate if(syncing) begin
		localparam numbit_counter = clogb2(numbit_posthandshake);
		reg [numbit_counter - 1:0] counter;
		always @ (posedge SCLK)
		begin
			if(RST == 1'b0)
			begin
				counter <= {numbit_counter{1'b0}};		// RESET 
			end else 
			begin
				if(CEB == 1'b1)
				begin
					counter <= {numbit_counter{1'b0}};	// RESET
				end else
				begin
					counter <= counter+1;				// COUNTING
				end
			end
		end
		assign sync = (1 << counter);
	end else begin
		reg [numbit_posthandshake - 1:0] counter;
		always @ (posedge SCLK)
		begin
			if (RST == 1'b0)
			begin
				counter <= {{(numbit_posthandshake-1){1'b0}},1'b1};		// RESET 
			end else 
			begin
				if (CEB == 1'b1)
				begin
					counter <= {{(numbit_posthandshake-1){1'b0}},1'b1};	// RESET 
				end else
				begin
					counter <= counter << 1;						// SHIFTING
				end
			end
		end
		assign sync = counter;
	end
	endgenerate

	// we / re capturing
	always @ (posedge SCLK)
	begin
		if(RST == 1'b0)
		begin
			we <= 1'b0;					// RESET
			re <= 1'b0;
		end else if(CEB == 1'b0)
		begin
			if(sync[0] == 1'b1) begin	
				we <= DATA;
			end
			if(sync[1] == 1'b1) begin
				re <= DATA;
			end
		end
	end
	
	// A_ADDR and AWDATA capturing
	reg [sword-1:0] A_ADDR;
	reg [sword-1:0] WDATA;
	reg PICORV_RST_SPI;
	always @ (posedge SCLK)
	begin
		if(RST == 1'b0)
		begin
			A_ADDR <= {sword{1'b0}};
			WDATA <= {sword{1'b0}};
			PICORV_RST_SPI <= 1'b0;
		end else if(CEB == 1'b0)
		begin
			if(sync[numbit_instr+sword-1] == 1'b1 && (re ^ we)) begin	
				A_ADDR <= {sft_reg[sword-2:0], DATA};
			end
			if(sync[numbit_instr+sword+sword-1] == 1'b1 && we == 1'b1) begin
				WDATA <= {sft_reg[sword-2:0], DATA};
			end
			if(sync[numbit_instr+sword+sword-1] == 1'b1 && we == 1'b0 && re == 1'b0) begin
				PICORV_RST_SPI <= DATA;
			end
		end
	end
	
	// Logic and stuff
	wire ens, encap_status, encap_rdata, enos_status, enos_rdata, en_status, en_rdata, is_hand;
	wire encap, enos, rdata_notstatus;
	// Enable shifting
	assign ens = |sync[sword+2-1:2];
	// Enable output shifting for status data
	assign enos_status = ~we & ~re & ens;
	// Enable output shifting for read data
	assign enos_rdata = we & re & ens;
	// Enable capture for status data (Treat DATA as re)
	assign encap_status = ~we & ~DATA & sync[1];
	// Enable capture for read data (Treat DATA as re)
	assign encap_rdata = we & DATA & sync[1];
	// Enable output shifting (General)
	assign enos = enos_status | enos_rdata;
	// Enable capture (General)
	assign encap = encap_status | encap_rdata;
	// Enable status data (Info for FSM)
	assign en_status = enos_status | encap_status;
	// Enable read data (Info for FSM)
	assign en_rdata = enos_rdata | encap_rdata;
	// Is handshake (Info for FSM)
	assign is_hand = en_status | en_rdata;
	// Mux selector about capturing data
	assign rdata_notstatus = encap_rdata;
	
	// The status flags
	wire [sword-1:0] status;
	reg busy;	// TODO: FSM
	reg rbusy;
	reg wbusy;
	wire [2:0] status_sclk;
	bus_sync_sf #(.impl(0), .sword(3)) bus_sync_status(.CLK1(CLK), .CLK2(SCLK), .RST(RST), .data_in({rbusy, wbusy, busy}), .data_out(status_sclk));
	assign status = {{(sword-3){1'b0}}, status_sclk};
	
	// The data reading
	reg encap_data;	// TODO: FSM
	reg [sword-1:0] rdata;
	always @ (posedge CLK)
	begin
		if(RST == 1'b0)
		begin
			rdata <= {sword{1'b0}};		// RESET
		end else if(encap_data == 1'b1)
		begin
			rdata <= axi_rdata;				// CAPTURE
		end
	end
	wire [sword-1:0] rdata_sclk;
	bus_sync_sf #(.impl(0), .sword(sword)) bus_sync_rdata(.CLK1(CLK), .CLK2(SCLK), .RST(RST), .data_in(rdata), .data_out(rdata_sclk));
	
	// Assignment to the value to capture
	wire [sword-1:0] bus_rd;
	assign bus_rd = rdata_notstatus?rdata_sclk:status;

	// Capturing the value to put to Dout
	reg [sword-1:0] bus_cap;
	always @ (posedge SCLK)
	begin
		if(RST == 1'b0)
		begin
			bus_cap <= {sword{1'b0}};		// RESET
		end else if(encap == 1'b1)
		begin
			bus_cap <= bus_rd;				// CAPTURE
		end else if(enos == 1'b1)
		begin
			bus_cap <= bus_cap << 1;		// SHIFT
		end
	end

	// with reg for putting the Dout
	wire DOUTNOZ;
	assign DOUTNOZ = bus_cap[sword-1];
	
	// tri-state out
	wire enoz;
	assign enoz = enos;
	assign DOUT = enoz&!CEB?DOUTNOZ:1'bz;
	
	// Axi assignments
	wire [sword-1:0] A_ADDR_CLK;
	wire [sword-1:0] WDATA_CLK;
	bus_sync_sf #(.impl(1), .sword(sword+sword)) bus_sync_axi_bus(.CLK1(SCLK), .CLK2(CLK), .RST(RST), .data_in({A_ADDR, WDATA}), .data_out({A_ADDR_CLK, WDATA_CLK}));
	assign axi_araddr = A_ADDR_CLK;
	assign axi_awaddr = A_ADDR_CLK;
	assign axi_wdata = WDATA_CLK;
	assign axi_wstrb = 4'b1111;	// Write all, SPI must write all unless inside the handshake is the wstrb
	assign axi_awprot = 3'b000; // Unpriviliged access, Secure access, Data access
	assign axi_arprot = 3'b000; // Unpriviliged access, Secure access, Data access
	
	// THE FSM
	// Declare state register
	reg		[3:0]state;
	wire we_clk, re_clk, fini_spi_clk;
	// This is for sync the data with the fini_spi
	reg fini_spi;
	always @(posedge SCLK) begin
		if(RST == 1'b0) begin
			fini_spi <= 1'b0;
		end else begin
			fini_spi <= sync[numbit_instr+sword+sword-1];
		end
	end
	bus_sync_sf #(.impl(1), .sword(4)) bus_sync_state_machine(.CLK1(SCLK), .CLK2(CLK), .RST(RST), .data_in({PICORV_RST_SPI, we, re, fini_spi}), .data_out({PICORV_RST, we_clk, re_clk, fini_spi_clk}));
	
	// Declare states
	parameter st0_nothing = 0, st1_awvalid = 1, st2_wvalid = 2, st3_wwait = 3, st4_bready = 4, st5_arvalid = 5, st6_rwait = 6, st7_rready = 7, st8_wait_spi = 8;
	
	// Output depends only on the state
	always @ (state) begin
		case (state)
			st0_nothing: begin
				axi_arvalid = 1'b0;
				axi_awvalid = 1'b0;
				axi_wvalid = 1'b0;
				axi_rready = 1'b0;
				axi_bready = 1'b0;
				busy = 1'b0;
				rbusy = 1'b0;
				wbusy = 1'b0;
				encap_data = 1'b0; end
			st1_awvalid: begin
				axi_arvalid = 1'b0;
				axi_awvalid = 1'b1;
				axi_wvalid = 1'b0;
				axi_rready = 1'b0;
				axi_bready = 1'b0;
				busy = 1'b1;
				rbusy = 1'b0;
				wbusy = 1'b1;
				encap_data = 1'b0; end
			st2_wvalid: begin
				axi_arvalid = 1'b0;
				axi_awvalid = 1'b1;
				axi_wvalid = 1'b1;
				axi_rready = 1'b0;
				axi_bready = 1'b0;
				busy = 1'b1;
				rbusy = 1'b0;
				wbusy = 1'b1;
				encap_data = 1'b0; end
			st3_wwait: begin
				axi_arvalid = 1'b0;
				axi_awvalid = 1'b1;
				axi_wvalid = 1'b1;
				axi_rready = 1'b0;
				axi_bready = 1'b0;
				busy = 1'b1;
				rbusy = 1'b0;
				wbusy = 1'b1;
				encap_data = 1'b0; end
			st4_bready: begin
				axi_arvalid = 1'b0;
				axi_awvalid = 1'b1;
				axi_wvalid = 1'b1;
				axi_rready = 1'b0;
				axi_bready = 1'b1;
				busy = 1'b1;
				rbusy = 1'b0;
				wbusy = 1'b1;
				encap_data = 1'b0; end
			st5_arvalid: begin
				axi_arvalid = 1'b1;
				axi_awvalid = 1'b0;
				axi_wvalid = 1'b0;
				axi_rready = 1'b0;
				axi_bready = 1'b0;
				busy = 1'b1;
				rbusy = 1'b1;
				wbusy = 1'b0;
				encap_data = 1'b0; end
			st6_rwait: begin
				axi_arvalid = 1'b1;
				axi_awvalid = 1'b0;
				axi_wvalid = 1'b0;
				axi_rready = 1'b0;
				axi_bready = 1'b0;
				busy = 1'b1;
				rbusy = 1'b1;
				wbusy = 1'b0;
				encap_data = 1'b0; end
			st7_rready: begin
				axi_arvalid = 1'b1;
				axi_awvalid = 1'b0;
				axi_wvalid = 1'b0;
				axi_rready = 1'b1;
				axi_bready = 1'b0;
				busy = 1'b1;
				rbusy = 1'b1;
				wbusy = 1'b0;
				encap_data = 1'b1; end
			st8_wait_spi: begin
				axi_arvalid = 1'b0;
				axi_awvalid = 1'b0;
				axi_wvalid = 1'b0;
				axi_rready = 1'b0;
				axi_bready = 1'b0;
				busy = 1'b1;
				rbusy = 1'b0;
				wbusy = 1'b0;
				encap_data = 1'b0; end
			default: begin
				axi_arvalid = 1'b0;
				axi_awvalid = 1'b0;
				axi_wvalid = 1'b0;
				axi_rready = 1'b0;
				axi_bready = 1'b0;
				busy = 1'b0;
				rbusy = 1'b0;
				wbusy = 1'b0;
				encap_data = 1'b0; end
		endcase
	end
	
	// Determine the next state
	always @ (posedge CLK) begin
		if (RST == 1'b0)
			state <= st0_nothing;
		else
			case (state)
				st0_nothing:
					if(we_clk & ~re_clk & fini_spi_clk)
						state <= st1_awvalid;
					else if(re_clk & ~we_clk & fini_spi_clk)
						state <= st5_arvalid;
					else
						state <= st0_nothing;
				st1_awvalid:
					if (axi_awready)
						state <= st2_wvalid;
					else
						state <= st1_awvalid;
				st2_wvalid:
					if (axi_wready)
						state <= st3_wwait;
					else
						state <= st2_wvalid;
				st3_wwait:
					if (axi_bvalid)
						state <= st4_bready;
					else
						state <= st3_wwait;
				st4_bready:
					state <= st8_wait_spi;
				st5_arvalid:
					if (axi_arready)
						state <= st6_rwait;
					else
						state <= st5_arvalid;
				st6_rwait:
					if (axi_rvalid)
						state <= st7_rready;
					else
						state <= st6_rwait;
				st7_rready:
					state <= st8_wait_spi;
				st8_wait_spi:
					if(~fini_spi_clk)
						state <= st0_nothing;
					else
						state <= st8_wait_spi;
				default:
					state <= st0_nothing;
			endcase
	end

endmodule
