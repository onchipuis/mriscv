`timescale 1ns/1ns

module AXI_SP32B1024_tb();

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


// Autogen localparams

localparam		   BITS = 32;
localparam		   word_depth = 1024;
localparam		   addr_width = 10;
localparam		   wordx = {BITS{1'bx}};
localparam		   addrx = {addr_width{1'bx}};

reg 	CLK = 1'b0;
reg	 	RST;

// AXI4-lite master memory interfaces

reg         axi_awvalid;
wire        axi_awready;
reg [32-1:0] axi_awaddr;
reg [3-1:0]     axi_awprot;

reg         axi_wvalid;
wire        axi_wready;
reg [32-1:0] axi_wdata;
reg [4-1:0]     axi_wstrb;

wire        axi_bvalid;
reg         axi_bready;

reg         axi_arvalid;
wire        axi_arready;
reg [32-1:0] axi_araddr;
reg [3-1:0]     axi_arprot;

wire        axi_rvalid;
reg         axi_rready;
wire [32-1:0] axi_rdata;

	
	integer 	fd1, tmp1, ifstop;
	integer PERIOD = 20 ;
	integer i, j, error, l;
	
	
	AXI_SP32B1024_INTERCONNECT
	inst_AXI_SP32B1024_INTERCONNECT
	(
	.CLK		(CLK),
	.RST	(RST),
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
		input [BITS-1:0] av, e;
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
		$sdf_annotate("AXI_SP32B1024.sdf",inst_AXI_SP32B1024_INTERCONNECT);
		CLK 	= 1'b1;
		RST 	= 1'b0;
		error = 0;
		axi_awvalid = 1'b0;
		axi_wvalid = 1'b0;
		axi_bready = 1'b0;
		axi_arvalid = 1'b0;
		axi_rready = 1'b0;
		axi_awaddr = {32{1'b0}};
		axi_awprot = {3{1'b0}};
		axi_wdata = {32{1'b0}};
		axi_wstrb = 4'b1111;
		axi_araddr = {32{1'b0}};
		axi_arprot = {3{1'b0}};
		#101;
		RST 	= 1'b1;
		// init the memory (AXI style)
		for(i = 0; i < word_depth; i = i+1) begin
			#(PERIOD);
			// WRITTING TEST
			axi_awaddr = i & (word_depth-1);
			axi_awvalid = 1'b1;
			#PERIOD;
			while(!axi_awready) begin
				#PERIOD; 
			end
			axi_wvalid = 1'b1;
			axi_wdata = xorshift64_state[BITS-1:0];
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
			xorshift64_next;
		end
		//$stop;
		// WRITTING AND READING TEST
		// BASICALLY, WHAT I READ, IS WHAT I WRITE
		for(i = 0; i < word_depth; i = i+1) begin
			#(PERIOD*8);
			//axi_wstrb = 1<<(i%4); // Set me ACTIVE if you want to see the behavioral with strobes, but all checking will fail
			// WRITTING TEST
			axi_awaddr = i & (word_depth-1);
			axi_awvalid = 1'b1;
			#PERIOD;
			while(!axi_awready) begin
				#PERIOD; 
			end
			axi_wvalid = 1'b1;
			axi_wdata = xorshift64_state[BITS-1:0];
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
			// READING TEST
			#(PERIOD*8);
			axi_arvalid = 1'b1;
			axi_araddr = i & (word_depth-1);
			#PERIOD;
			while(!axi_arready) begin
				#PERIOD; 
			end
			while(!axi_rvalid) begin
				#PERIOD; 
			end
			axi_rready = 1'b1;
			aexpect(axi_rdata, xorshift64_state[BITS-1:0]);
			#PERIOD; 
			axi_arvalid = 1'b0;
			axi_rready = 1'b0;
			xorshift64_next;
		end
		$timeformat(-9,0,"ns",7);
		#(PERIOD*8) if (error == 0)
					$display("All match");
				else
					$display("Mismatches = %d", error);
		$finish;
	end

endmodule
