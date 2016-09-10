`timescale 1ns/1ns

module spi_axi_master_tb();

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
	
localparam	tries = 10;
localparam  			sword = 32;

localparam			impl = 0;
localparam			syncing = 0;

// Autogen localparams

reg 	CLK = 1'b0;
reg 	SCLK = 1'b0;
reg	 	RST;

// AXI4-lite slave memory interfaces

wire             axi_awvalid;
reg              axi_awready;
wire [sword-1:0] axi_awaddr;
wire [3-1:0]     axi_awprot;

wire             axi_wvalid;
reg              axi_wready;
wire [sword-1:0] axi_wdata;
wire [4-1:0]     axi_wstrb;

reg              axi_bvalid;
wire             axi_bready;

wire             axi_arvalid;
reg              axi_arready;
wire [sword-1:0] axi_araddr;
wire [3-1:0]     axi_arprot;

reg              axi_rvalid;
wire             axi_rready;
reg  [sword-1:0] axi_rdata;

reg DATA;
wire DOUT;
reg CEB;

wire PICORV_RST;

localparam numbit_instr = 2;			// Nop (00), Read(01), Write(10)
localparam numbit_address = sword;
localparam numbit_handshake = numbit_instr+numbit_address+sword;

reg [numbit_handshake-1:0] handshake;
reg [sword-1:0] result;

reg stat;
	
	integer 	fd1, tmp1, ifstop;
	integer PERIOD = 8 ;
	integer SPERIOD = 20 ;
	integer i, j, error, l;
	
	
	spi_axi_master /*#
	(
	.sword(sword),
	.impl(impl),
	.syncing(syncing)
	) */
	inst_spi_axi_master
	(
	.SCLK		(SCLK),
	.CEB	(CEB),
	.DATA	(DATA),
	.DOUT	(DOUT),
	.RST	(RST),
	.CLK		(CLK),
	.PICORV_RST(PICORV_RST),
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
	begin #(SPERIOD/2) SCLK = ~SCLK; end 
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
		$sdf_annotate("spi_axi_master.sdf",inst_spi_axi_master);
		CEB		= 1'b1;
		CLK 	= 1'b0;
		SCLK 	= 1'b0;
		RST 	= 1'b0;
		DATA 	= 1'b0;
		stat = 1'b0;
		error = 0;
		axi_awready = 1'b0;
		axi_wready = 1'b0;
		axi_bvalid = 1'b0;
		axi_arready = 1'b0;
		axi_rvalid = 1'b0;
		axi_rdata = {sword{1'b0}};
		result = {sword{1'b0}};
		handshake = {numbit_handshake{1'b0}};
		#(SPERIOD*20);
		RST 	= 1'b1;
		
		#(SPERIOD*6);
		
		// SENDING PICORV RESET TO ZERO
		CEB = 1'b0;
		DATA = 1'b0;
		#SPERIOD;
		DATA = 1'b0;
		#SPERIOD;		// SENT "SEND STATUS", but we ignore totally the result
		#(SPERIOD*(2*sword-1));
		DATA = 1'b0;	// Send to the reset
		#SPERIOD;
		CEB = 1'b1;
		#(SPERIOD*4);
		
		$display("The PICORV_RST is on ZERO? %b", PICORV_RST);
		
		// WRITTING TEST
		for(i = 0; i < tries; i = i+1) begin
			#(SPERIOD*8);
			CEB = 1'b0;
			// Making handshake, writting, at random dir, at random data
			handshake = {2'b10,xorshift64_state};
			for(j = 0; j < numbit_handshake; j = j+1) begin
				DATA = handshake[numbit_handshake-j-1];
				#SPERIOD;
			end
			CEB = 1'b1;
			#SPERIOD;
			stat = 1'b1;
			// Wait the axi handshake, SPI-POV
			while(stat) begin
				CEB = 1'b0;
				DATA = 1'b0;
				#SPERIOD;
				DATA = 1'b0;
				#SPERIOD;		// SENT "SEND STATUS"
				for(j = 0; j < sword; j = j+1) begin
					result[sword-j-1] = DOUT;
					#SPERIOD;
				end
				CEB = 1'b1;
				#(SPERIOD*2);
				if(result[1] == 1'b0 && result[0] == 1'b0) begin	// CHECKING WBUSY AND BUSY
					stat = 1'b0;
				end
			end
			$display ("SPI: Task: WData");
			xorshift64_next;
			#(SPERIOD*8);
		end
		
		// READING TEST
		for(i = 0; i < tries; i = i+1) begin
			#(SPERIOD*8);
			CEB = 1'b0;
			// Making handshake, reading, at random dir, at random data (ignored)
			handshake = {2'b01,xorshift64_state};
			for(j = 0; j < numbit_handshake; j = j+1) begin
				DATA = handshake[numbit_handshake-j-1];
				#SPERIOD;
			end
			CEB = 1'b1;
			#(SPERIOD*3);
			stat = 1'b1;
			// Wait the axi handshake, SPI-POV
			while(stat) begin
				CEB = 1'b0;
				DATA = 1'b0;
				#SPERIOD;
				DATA = 1'b0;
				#SPERIOD;		// SENT "SEND STATUS"
				for(j = 0; j < sword; j = j+1) begin
					result[sword-j-1] = DOUT;
					#SPERIOD;
				end
				CEB = 1'b1;
				#(SPERIOD*3);
				if(result[2] == 1'b0 && result[0] == 1'b0) begin	// CHECKING RBUSY AND BUSY
					stat = 1'b0;
				end
			end
			
			CEB = 1'b0;
			DATA = 1'b1;
			#SPERIOD;
			DATA = 1'b1;
			#SPERIOD;		// SEND "SEND RDATA"
			for(j = 0; j < sword; j = j+1) begin
				result[sword-j-1] = DOUT;
				#SPERIOD;
			end
			CEB = 1'b1;
			$display ("SPI: Task: RData");
			aexpect(result, xorshift64_state[31:0]);
			xorshift64_next;
			#(SPERIOD*8);
		end
		
		// SENDING PICORV RESET TO ONE
		CEB = 1'b0;
		DATA = 1'b0;
		#SPERIOD;
		DATA = 1'b0;
		#SPERIOD;		// SENT "SEND STATUS", but we ignore totally the result
		#(SPERIOD*(2*sword-1));
		DATA = 1'b1;	// Send to the reset
		#SPERIOD;
		CEB = 1'b1;
		#(SPERIOD*4);
		$display("The PICORV_RST is on ONE? %b", PICORV_RST);
		
		$timeformat(-9,0,"ns",7);
		#(SPERIOD*8) if (error == 0)
					$display("All match");
				else
					$display("Mismatches = %d", error);
		$finish;
	end
	
	always @(posedge CLK) begin
		if(axi_arvalid && !axi_arready && !axi_rready) begin
			axi_arready = 1'b1;
			axi_rvalid = 1'b1;
			axi_rdata = xorshift64_state[31:0];
			$display ("AXI: Task: RAddr");
			aexpect(axi_araddr, xorshift64_state[63:32]);
		end else if(axi_rready) begin
			axi_arready = 1'b0;
			axi_rvalid = 1'b0;
		end
		
		
		if(axi_awvalid && !axi_awready && !axi_bready) begin
			axi_awready = 1'b1;
			$display ("AXI: Task: WAddr");
			aexpect(axi_awaddr, xorshift64_state[63:32]);
		end else if(axi_wvalid && !axi_wready && !axi_bready) begin
			axi_wready = 1'b1;
			axi_bvalid = 1'b1;
			$display ("AXI: Task: WData");
			aexpect(axi_wdata, xorshift64_state[31:0]);
		end else if(axi_bready) begin
			axi_awready = 1'b0;
			axi_wready = 1'b0;
			axi_bvalid = 1'b0;
		end
	end

endmodule
