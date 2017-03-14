`timescale 1ns / 1ps



module completogpio_tb;

	// Inputs
	reg [31:0] WAddress;
	reg [31:0] Wdata;
	reg AWvalid;
	reg [7:0] pindata;
	reg [31:0] RAddress;
	reg Wvalid;
	reg clock;
	reg ARvalid;
	reg reset;
	reg Rready;
	reg Bready;
	reg [3:0 ]strobe;

	// Outputs
	wire [7:0] DSE;
	wire ARready;
	wire Rvalid;
	wire AWready;
	wire Wready;
	wire Bvalid;
	wire [7:0] Rx;
	wire [7:0] datanw;
	wire [7:0] Tx;
	wire [31:0] Rdata;

	// Instantiate the Unit Under Test (UUT)
	completogpio uut (
		.WAddress(WAddress), 
		.Wdata(Wdata), 
		.AWvalid(AWvalid), 
		.pindata(pindata), 
		.RAddress(RAddress), 
		.Wvalid(Wvalid), 
		.clock(clock), 
		.ARvalid(ARvalid), 
		.reset(reset), 
		.Rready(Rready), 
		.Bready(Bready), 
		.DSE(DSE), 
		.ARready(ARready), 
		.Rvalid(Rvalid), 
		.AWready(AWready), 
		.Wready(Wready), 
		.Bvalid(Bvalid), 
		.Rx(Rx), 
		.datanw(datanw), 
		.Tx(Tx), 
		.Rdata(Rdata)
	);

	always #1 clock=~clock;
	initial begin
		// Initialize Inputs
		WAddress = 0;
		Wdata = 0;
		AWvalid = 0;
		pindata = 8'd0;
		RAddress = 0;
		Wvalid = 0;
		clock = 0;
		ARvalid = 0;
		reset = 0;
		Rready = 0;
		Bready = 0;
		

		// escritura
		#2;
		reset=1;
		Rready=0;
		WAddress=32'hEFA;
		Wdata=32'hABCDEFFF;
		pindata = 8'b10101010;
		RAddress=32'd88393348;
		AWvalid=1;
		#1;
		Wvalid=1;
		#2.5;
		Wvalid=0;		
		#2.5;
		AWvalid=0;
		Bready=1;
		
		#2.5;
		reset=0;
		Bready=0;		
		// lectura
		
		#10;
		reset=1;
		
		ARvalid=1;
		#2.5;
		Rready=1;
		ARvalid=0;
		#2.0;
		Rready=0;
		
		
		
		#4;
		reset=0;
		// escritura
		#10;
		reset=1;
		Rready=0;
		WAddress=32'hEFA6;
		Wdata=32'hABCDEFF1;
		pindata = 8'b10101010;
		RAddress=32'd88393348;
		AWvalid=1;
		#1;
		Wvalid=1;
		#8;
		Wvalid=0;		
		#9;
		AWvalid=0;
		Bready=1;
		
		#9;
		reset=0;	
		Bready=0;
		
		// lectura
		
		#10;
		reset=1;
		ARvalid=1;
		#6;
		Rready=1;
		ARvalid=0;
		
		#4;
		reset=0;
		Rready=0;
		#2;
		reset=1;
		$finish;
/*				// escritura
		#100;
		reset=1;
		Rready=0;
		WAddress=32'hEFA;
		Wdata=32'hABCDEFFF;
		pindata = 8'b10101010;
		RAddress=32'd88393348;
		AWvalid=1;
		#10;
		Wvalid=1;
		#25;
		Wvalid=0;		
		#25;
		AWvalid=0;
		Bready=1;
		
		#25;
		reset=0;		
		// lectura
		
		#100;
		reset=1;
		Bready=0;
		ARvalid=1;
		#25;
		Rready=1;
		ARvalid=0;
		
		
		
		
		#20;
		reset=0;
		Rready=0;*/
		/*// escritura
		#100;
		reset=1;
		Rready=0;
		WAddress=32'hEFA6;
		Wdata=32'hABCDEFF1;
		pindata = 8'b10101010;
		RAddress=32'd88393348;
		AWvalid=1;
		#10;
		Wvalid=1;
		#80;
		Wvalid=0;		
		#90;
		AWvalid=0;
		Bready=1;
		
		#90;
		reset=0;	
		
		// lectura
		
		#100;
		reset=1;
		Bready=0;
		ARvalid=1;
		#60;
		Rready=1;
		ARvalid=0;
		
		#60;
		reset=0;
		Rready=0;*/
		
		// Add stimulus here

	end
      
endmodule

