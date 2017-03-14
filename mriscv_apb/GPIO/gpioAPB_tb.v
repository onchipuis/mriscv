`timescale 1ns / 1ps


module gpioAPB_tb;

	// Inputs
	reg clock;
	reg reset;
	reg [31:0] Paddr;
	reg Penable;
	reg Pwrite;
	reg [31:0] Pwdata;
	reg [7:0]pindata;
	reg Psel;
	reg [3:0] strobe;

	// Outputs
	wire [31:0] Prdata;
	wire [7:0] Rx;
	wire [7:0] datanw;
	wire [7:0] Tx;
	wire [7:0] DSE;
	wire Pready;

	// Instantiate the Unit Under Test (UUT)
	gpioAPB uut (
		.clock(clock), 
		.reset(reset), 
		.Paddr(Paddr), 
		.Penable(Penable), 
		.Pwrite(Pwrite), 
		.Pwdata(Pwdata), 
		.pindata(pindata),  
		.Psel(Psel), 
		.Prdata(Prdata), 
		.Rx(Rx), 
		.datanw(datanw), 
		.Tx(Tx), 
		.DSE(DSE), 
		.Pready(Pready), 
		.strobe(strobe)
	);
	always #1 clock=~clock;
	initial begin
		// Initialize Inputs
		clock = 0;
		reset = 0;
		Paddr = 0;
		Penable = 0;
		Pwrite = 0;
		Pwdata = 0;
		pindata =8'd0;
		Psel = 0;
		strobe = 0;
		
		
		// lectura
		#5;
		reset = 1;
		Paddr = 32'habcfdef;
		Penable = 1;
		Pwrite = 0;
		Pwdata = 32'h4567abcf;;
		pindata = 8'b10110101;
		Psel = 1;
		
		#5;
		reset=0;
		Penable=0;
		Paddr = 32'h348cf01f;
		
		
		// escritura
		#5;
		reset=1;
		Penable=1;
		Pwrite=1;
		pindata = 8'hff;
		
		#5;
		reset=0;
		Pwrite=0;
		Penable=0;
		Paddr = 32'h34;
		
		// lectura
		#5;
		reset=1;
		Penable=1;
		
		
		#5;
		reset=0;
		Penable=0;
		
		
		// escritura
		#5;
		reset=1;
		Penable=1;
		Pwrite=1;
		pindata = 8'h2a;
		Paddr = 32'h3a;
		
		#5;
		reset=0;
		Pwrite=0;
		Penable=0;
		#1;
		$finish;

		// Add stimulus here

	end
      
endmodule

