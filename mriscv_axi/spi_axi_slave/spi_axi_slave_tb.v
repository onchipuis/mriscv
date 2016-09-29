`timescale 1ns/1ns

module spi_axi_slave_tb();

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
	
localparam	tries = 512;
localparam  			sword = 32;

localparam			impl = 0;
localparam			syncing = 0;

// Autogen localparams

reg 	CLK = 1'b0;
reg	 	RST;

// AXI4-lite master memory interfaces

reg         axi_awvalid;
wire        axi_awready;
reg [sword-1:0] axi_awaddr;
reg [3-1:0]     axi_awprot;

reg         axi_wvalid;
wire        axi_wready;
reg [sword-1:0] axi_wdata;
reg [4-1:0]     axi_wstrb;

wire        axi_bvalid;
reg         axi_bready;

reg         axi_arvalid;
wire        axi_arready;
reg [sword-1:0] axi_araddr;
reg [3-1:0]     axi_arprot;

wire        axi_rvalid;
reg         axi_rready;
wire [sword-1:0] axi_rdata;

// SPI interface
wire SCLK;
wire CEB;
wire DATA;

// Data per capturing
reg [sword-1:0] cap;

	
	integer 	fd1, tmp1, ifstop;
	integer PERIOD = 20 ;
	integer i, j, error, l;
	
	
	spi_axi_slave
	inst_spi_axi_slave
	(
	.CLK		(CLK),
	.RST	(RST),
	.SCLK(SCLK),
	.CEB(CEB),
	.DATA(DATA),
	.axi_awvalid(axi_awvalid),
	.axi_awready(axi_awready),
	.axi_awaddr(axi_awaddr),
	.axi_awprot(axi_awprot),
	.axi_wvalid(axi_wvalid),
	.axi_wready(axi_wready),
	.axi_wdata(axi_wdata),
	.axi_wstrb(axi_wstrb),
	.axi_bvalid(axi_bvalid),
	.axi_bready(axi_bready),
	.axi_arvalid(axi_arvalid),
	.axi_arready(axi_arready),
	.axi_araddr(axi_araddr),
	.axi_arprot(axi_arprot),
	.axi_rvalid(axi_rvalid),
	.axi_rready(axi_rready),
	.axi_rdata(axi_rdata)
	); 
	
	always
	begin #(PERIOD/2) CLK = ~CLK; end 

	task aexpect;
		input [sword-1:0] av, e;
		begin
		 if (av == e)
			$display ("TIME=%t." , $time, " Actual value of trans=%b, expected is %b. MATCH!", av, e);
		 else
		  begin
			$display ("TIME=%t." , $time, " Actual value of trans=%b, expected is %b. ERROR!", av, e);
			error = error + 1;
		  end
		end
	endtask
	
	reg [63:0] xorshift64_state = 64'd88172645463325252;

	task xorshift64_next;
		begin
			// see page 4 of Marsaglia, George (July 2003). "Xorshift RNGs". Journal of Statistical Software 8 (14).
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 13);
			xorshift64_state = xorshift64_state ^ (xorshift64_state >>  7);
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 17);
		end
	endtask


	initial begin
		$sdf_annotate("spi_axi_slave.sdf",inst_spi_axi_slave);
		CLK 	= 1'b0;
		RST 	= 1'b0;
		cap = {sword{1'b0}};
		error = 0;
		axi_awvalid = 1'b0;
		axi_wvalid = 1'b0;
		axi_bready = 1'b0;
		axi_arvalid = 1'b0;
		axi_rready = 1'b0;
		axi_awaddr = {sword{1'b0}};
		axi_awprot = {3{1'b0}};
		axi_wdata = {sword{1'b0}};
		axi_wstrb = 4'b1111;
		axi_araddr = {sword{1'b0}};
		axi_arprot = {3{1'b0}};
		#101;
		RST 	= 1'b1;
		// WRITTING AND READING TEST
		// BASICALLY, WHAT I READ, IS WHAT I WRITE
		for(i = 0; i < tries; i = i+1) begin
			#(PERIOD*8);
			// WRITTING TEST
			axi_awvalid = 1'b1;
			#PERIOD;
			while(!axi_awready) begin
				#PERIOD; 
			end
			axi_wvalid = 1'b1;
			axi_wdata = xorshift64_state[sword-1:0];
			while(!axi_wready) begin
				#PERIOD; 
			end
			while(!axi_bvalid) begin
				#PERIOD; 
			end
			axi_bready = 1'b1;
			#PERIOD; 
			axi_awvalid = 1'b0;
			axi_wvalid = 1'b0;
			axi_bready = 1'b0;
			
			// Waiting the SPI for finishing
			while(!CEB) begin
				#PERIOD; 
			end
			aexpect(cap, xorshift64_state[sword-1:0]);
			xorshift64_next;
		end
		$timeformat(-9,0,"ns",7);
		#(PERIOD*8) if (error == 0)
					$display("All match");
				else
					$display("Mismatches = %d", error);
		$finish;
	end
	
	always @(posedge SCLK) begin
		if(CEB == 1'b0) begin
			cap = {cap[sword-2:0], DATA};
		end
	end

endmodule
