// Created by: CKDUR
`timescale 1ns/1ns

module spi_axi_slave #
	(
	parameter  			sword = 32,
	parameter			numbit_divisor = 1,	// The SCLK will be CLK/2^(numbit_divisor-1)

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
	output							CEB,
	output							SCLK,
	output 							DATA,
	// MISC
	input							RST,
	// AXI4-lite slave memory interface
	
	input			  CLK,
	input         	  axi_awvalid,
	output            axi_awready,
	input [sword-1:0] axi_awaddr,
	input [3-1:0]     axi_awprot,

	input         	  axi_wvalid,
	output reg        axi_wready,
	input [sword-1:0] axi_wdata,
	input [4-1:0]     axi_wstrb,

	output reg        axi_bvalid,
	input         	  axi_bready,

	input         	  axi_arvalid,
	output            axi_arready,
	input [sword-1:0] axi_araddr,
	input [3-1:0]     axi_arprot,

	output reg        axi_rvalid,
	input         	  axi_rready,
	output [sword-1:0] axi_rdata
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
	
	// CONSTRAINTS
	// This outputs are not used
	// Read Channel:
	assign axi_rdata = 32'h00000000;
	assign axi_arready = 1'b1;
	always @(posedge CLK ) begin	// A simple reactor, we ignore totally the addr, and ignore the result
		if(RST == 1'b0) begin
			axi_rvalid <= 1'b0;
		end else begin
			if(axi_rready == 1'b1) begin
				axi_rvalid <= 1'b0;
			end else if(axi_arvalid == 1'b1) begin
				axi_rvalid <= 1'b1;
			end else begin
				axi_rvalid <= axi_rvalid;
			end
		end
	end
	// Write Channel:
	// CONSIDERATION: Is supposed that the ADDR is unique.
	// If awvalid is triggered, awaddr is ignored
	// But if wvalid is triggered, the data is taken
	// So you will understand why I trigger all time the
	// awready
	assign axi_awready = 1'b1;
	
	// Angry CLK divisor for SCLK
	reg [numbit_divisor-1:0] divisor;
	always @(posedge CLK ) begin
		if(RST == 1'b0) begin
			divisor <= {numbit_divisor{1'b0}};
		end else begin
			divisor <= divisor + 1;
		end
	end
	wire SCLK_EN;	// This is an Enable that does the same that the divisor
	localparam [numbit_divisor-1:0] div_comp = ~(1 << (numbit_divisor-1));
	assign SCLK_EN = divisor == div_comp ? 1'b1:1'b0;
	wire SCLKA;
	assign SCLKA = ~divisor[numbit_divisor-1];
	// SCLK Activator (High state thing)
	assign SCLK = SCLKA;//(~CEB)?SCLKA:1'b0;
	
	// Counter for SPI SYNC
	localparam numbit_sync = clogb2(sword);
	localparam [numbit_sync-1:0] sync_stop = sword - 1;
	reg [numbit_sync-1:0] sync;
	wire stop;
	reg transmit;
	assign stop = sync == sync_stop? 1'b1:1'b0;
	always @(posedge CLK ) begin
		if(RST == 1'b0) begin
			sync <= {numbit_sync{1'b0}};
		end else begin
			if(SCLK_EN == 1'b1) begin
			if((transmit == 1'b1 && ~(|sync)) || (|sync)) begin
				if(stop == 1'b1) begin
					sync <= {numbit_sync{1'b0}};
				end else begin
					sync <= sync + 1;
				end
			end else begin
				sync <= sync;
			end
			end
		end
	end
	
	// Register that captures and do the Paralell-Serial
	reg [sword-1:0] cap_data;
	always @(posedge CLK ) begin
		if(RST == 1'b0) begin
			cap_data <= {sword{1'b0}};
			transmit <= 1'b0;
			//CEB <= 1'b1;
		end else begin
			if(SCLK_EN == 1'b1) begin
			if(stop == 1'b1) begin
				cap_data <= cap_data;
				transmit <= 1'b0;
			end else if(axi_wvalid == 1'b1 && transmit == 1'b0) begin
				cap_data <= axi_wdata;
				transmit <= 1'b1;
			end else if(transmit == 1'b1) begin
				cap_data <= cap_data << 1;
				transmit <= transmit;
			end else begin
				cap_data <= cap_data;
				transmit <= transmit;
			end
			
			/*if(stop == 1'b1) begin
				CEB <= 1'b1;
			end else if(axi_wvalid == 1'b1) begin
				CEB <= 1'b0;
			end else begin
				CEB <= CEB;
			end*/
			end
		end
	end
	assign CEB = ~transmit;
	assign DATA = (CEB==1'b0) ?cap_data[sword-1]:1'bz;
	
	// AXI control according to all
	always @(posedge CLK ) begin
		if(RST == 1'b0) begin
			axi_wready <= 1'b0;
			axi_bvalid <= 1'b0;
		end else begin
			if(axi_bready == 1'b1 && axi_bvalid == 1'b1) begin
				axi_wready <= 1'b0;
			end else if(transmit == 1'b1) begin
				axi_wready <= 1'b1;
			end else begin
				axi_wready <= axi_wready;
			end
			
			if(axi_bready == 1'b1 && axi_bvalid == 1'b1) begin
				axi_bvalid <= 1'b0;
			end else if(stop == 1'b1) begin
				axi_bvalid <= 1'b1;
			end else begin
				axi_bvalid <= axi_bvalid;
			end
		end
	end
 	/*
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
		endcase
	end
	
	// Determine the next state
	always @ (posedge CLK ) begin
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
*/
endmodule
