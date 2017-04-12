`timescale 1ns/1ns

module impl_axi_tb();

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
localparam  sword = 32;	
localparam  			masters = 2;
localparam  			slaves = 5;

localparam	impl = 0;
localparam	syncing = 0;
localparam	max_wait = 1000000;

// Autogen localparams

reg 	CLK = 1'b0;
reg 	SCLK = 1'b0;
reg 	ADCCLK = 1'b0;
reg	 	RST;

reg  DATA;
wire DOUT;
reg  CEB;
wire [11:0] 	DAC_interface_AXI_DATA;
reg 			ADC_interface_AXI_BUSY;
reg  [9:0] 		ADC_interface_AXI_DATA;
reg  [7:0] 		completogpio_pindata;
wire [7:0] 		completogpio_Rx;
wire [7:0] 		completogpio_Tx;
wire [7:0] 		completogpio_datanw;
wire [7:0] 		completogpio_DSE;
wire 			spi_axi_slave_CEB; 
wire 			spi_axi_slave_SCLK; 
wire 			spi_axi_slave_DATA;

localparam numbit_instr = 2;			// Nop (00), Read(01), Write(10)
localparam numbit_address = sword;
localparam numbit_handshake = numbit_instr+numbit_address+sword;

reg [numbit_handshake-1:0] handshake;
reg [sword-1:0] result;

// Data per capturing
reg [sword-1:0] cap;

reg stat;
reg stats;
reg is_o, is_ok;
reg waiting_ok;
integer waiting;
	
integer fd1, tmp1, ifstop;
integer PERIOD = 10 ;
integer SPERIOD = 20 ;
integer ADCPERIOD = 100 ;
integer i, j, error, l;
	
	// Device under test
	impl_axi inst_impl_axi(
		// General
		.CLK(CLK),
		.RST(RST),
		.spi_axi_master_CEB(CEB), 
		.spi_axi_master_SCLK(SCLK), 
		.spi_axi_master_DATA(DATA), 
		.spi_axi_master_DOUT(DOUT),
		.DAC_interface_AXI_DATA(DAC_interface_AXI_DATA),
		.ADC_interface_AXI_BUSY(ADC_interface_AXI_BUSY),
		.ADC_interface_AXI_DATA(ADC_interface_AXI_DATA),
		.completogpio_pindata(completogpio_pindata),
		.completogpio_Rx(completogpio_Rx),
		.completogpio_Tx(completogpio_Tx),
		.completogpio_datanw(completogpio_datanw),
		.completogpio_DSE(completogpio_DSE),
		.spi_axi_slave_CEB(spi_axi_slave_CEB), 
		.spi_axi_slave_SCLK(spi_axi_slave_SCLK), 
		.spi_axi_slave_DATA(spi_axi_slave_DATA)
	);
	
	always
	begin #(SPERIOD/2) SCLK = ~SCLK; end 
	always
	begin #(PERIOD/2) CLK = ~CLK; end 
	always
	begin #(ADCPERIOD/2) ADCCLK = ~ADCCLK; end 
	
	// Task for expect something (helper)
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
	
	// Our pseudo-random generator
	reg [63:0] xorshift64_state = 64'd88172645463325252;
	task xorshift64_next;
		begin
			// see page 4 of Marsaglia, George (July 2003). "Xorshift RNGs". Journal of Statistical Software 8 (14).
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 13);
			xorshift64_state = xorshift64_state ^ (xorshift64_state >>  7);
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 17);
		end
	endtask
	
	// Memory to write
	reg [31:0] memory [0:1023];
	initial $readmemh("firmware_mini.hex", memory);

	initial begin
		//$sdf_annotate("spi_axi_master.sdf",inst_spi_axi_master);
		waiting = 0;
		waiting_ok = 1'b0;
		cap = {sword{1'b0}};
		ADC_interface_AXI_BUSY = 1'b0;
		ADC_interface_AXI_DATA = {10{1'b0}};
		completogpio_pindata = {8{1'b0}};
		is_o = 1'b0;
		is_ok = 1'b0;
		CEB		= 1'b1;
		CLK 	= 1'b0;
		SCLK 	= 1'b0;
		ADCCLK 	= 1'b0;
		RST 	= 1'b0;
		DATA 	= 1'b0;
		stat = 1'b0;
		stats = 1'b0;
		error = 0;
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
		
		// WRITTING PROGRAM
		for(i = 0; i < 1024; i = i+1) begin
			#(SPERIOD*8);
			CEB = 1'b0;
			// Making handshake, writting, ordinal dir, at data program
			handshake = {2'b10,32'h00000000|i,memory[i]};
			for(j = 0; j < numbit_handshake; j = j+1) begin
				DATA = handshake[numbit_handshake-j-1];
				#SPERIOD;
			end
			CEB = 1'b1;
			#(SPERIOD*4);
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
			$display ("SPI: Written data %x = %x", i, memory[i]);
			#(SPERIOD*8);
            if(memory[i] == 32'd0) i = 1024;   // Workaround
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
		
		$display ("SPI: Programmed all instructions, picorv32 activated!");
		$timeformat(-9,0,"ns",7);
		
		// Waiting picorv to finish (Remember to put OK)
		while(~waiting_ok) #SPERIOD;
		
		// DAC_interface_AXI
		$display("Doing the DAC_interface_AXI test");
		//$stop;
		for(i = 0; i < 8; i = i + 1) begin
			xorshift64_next;
			#SPERIOD;
		end
		for(l = 0; l < tries; l = l + 1) begin
			CEB = 1'b0;
			// Making handshake, writting, DAC dir, at random data 
			handshake = {2'b10,32'h00000400,xorshift64_state[31:0]};
			for(j = 0; j < numbit_handshake; j = j+1) begin
				DATA = handshake[numbit_handshake-j-1];
				#SPERIOD;
			end
			CEB = 1'b1;
			#(SPERIOD*4);
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
				end else begin
					$display ("SPI: Waiting writting to be done (%b) %x = %x", result[2:0], 32'h00000400, xorshift64_state[31:0]);
				end
			end
			$display ("SPI: Written data %x = %x", 32'h00000400, xorshift64_state[31:0]);
			aexpect(DAC_interface_AXI_DATA, xorshift64_state[11:0]);
			
			#(SPERIOD*8);
			xorshift64_next;
		end
		
		// ADC_interface_AXI
		$display("Doing the ADC_interface_AXI test");
		//$stop;
		for(i = 0; i < 8; i = i + 1) begin
			xorshift64_next;
			#SPERIOD;
		end
		
		for(l = 0; l < tries; l = l + 1) begin
			CEB = 1'b0;
			// Making handshake, reading, at ADC dir, at random data (ignored)
			handshake = {2'b01,32'h00000408,32'h00000000};
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
				end else begin
					$display ("SPI: Waiting reading to be done (%b) %x", result[2:0], 32'h00000408);
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
			$display ("SPI: Read data %x = %x", 32'h00000408, result);
			aexpect(result[9:0], xorshift64_state[9:0]);
			
			#(SPERIOD*8);
			xorshift64_next;
		end
		
		
		// completogpio
		$display("Doing the completegpio test");
		//$stop;
		for(i = 0; i < 8; i = i + 1) begin
			xorshift64_next;
			#SPERIOD;
		end
		
		for(l = 0; l < tries; l = l + 1) begin
			// READING TEST
			for(i = 0; i < 8; i = i+1) begin
				#(SPERIOD*8);
				CEB = 1'b0;
				// Making handshake, reading, at completogpio dir, at random data (ignored)
				handshake = {2'b01,32'h00000410 | i, 32'h00000000};
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
				$display ("SPI: Read data %x = %x", 32'h00000410|i, result);
				aexpect(result[0], xorshift64_state[i]);
			end
			$display ("completogpio: Making test of Rx");
			aexpect(completogpio_Rx, 8'b11111111);
			// WRITTING TEST
			for(i = 0; i < 8; i = i+1) begin
				#(SPERIOD*8);
				CEB = 1'b0;
				// Making handshake, writting, completogpio dir, at random data 
				handshake = {2'b10, 32'h00000410 | i, 32'h00000004 | xorshift64_state[16+i]};
				for(j = 0; j < numbit_handshake; j = j+1) begin
					DATA = handshake[numbit_handshake-j-1];
					#SPERIOD;
				end
				CEB = 1'b1;
				#(SPERIOD*4);
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
				$display ("SPI: Written data %x = %x", 32'h00000410 | i, 32'h00000000 | xorshift64_state[16+i]);
				aexpect(completogpio_datanw[i], xorshift64_state[16+i]);
			end
			$display ("completogpio: Making test of Tx");
			aexpect(completogpio_Tx, 8'b00000000);
			
			#(SPERIOD*8);
			xorshift64_next;
		end
		
		if (error == 0)
			$display("All match");
		else
			$display("Mismatches = %d", error);
		$finish;
		//$stop;
		
	end
	
	// SPI AXI SLAVE interface simulation
	always @(posedge spi_axi_slave_SCLK) begin
		if(spi_axi_slave_CEB == 1'b0) begin
			stats <= 1'b1;
			cap <= {cap[sword-2:0], spi_axi_slave_DATA};
		end else if(stats == 1'b1) begin
			stats <= 1'b0;
			if(cap == 68 || (cap == 79 && is_o == 1'b1) || (cap == 78 && is_o == 1'b1) || (cap == 69 && is_o == 1'b1))
				is_o <= 1'b1;
			else
				is_o <= 1'b0;
			if(cap == 69 && is_o == 1'b1)
				is_ok <= 1'b1;
`ifdef VERBOSE
			if (32 <= cap && cap < 128)
				$display("OUT: '%c'", cap);
			else
				$display("OUT: %3d", cap);
`else
			$write("%c", cap);
			$fflush();
`endif
		end
	end
	
	// Waiting to end program
	always @(posedge SCLK) begin
		if(waiting_ok == 1'b0) begin
			if(is_ok == 1'b1) begin
				
				// SENDING PICORV RESET TO ZERO
				/*CEB = 1'b0;
				DATA = 1'b0;
				#SPERIOD;
				DATA = 1'b0;
				#SPERIOD;		// SENT "SEND STATUS", but we ignore totally the result
				#(SPERIOD*(2*sword-1));
				DATA = 1'b0;	// Send to the reset
				#SPERIOD;
				CEB = 1'b1;
				#(SPERIOD*4);*/
	
				$display ("Program Suceed! Reseted the picorv");
				
				// screw it! we'll put all this to reset
				/*RST = 1'b0;
				#(SPERIOD*4);
				RST = 1'b1;*/
			
				waiting_ok = 1'b1;
				#(SPERIOD*4);
			
			end else begin
				waiting = waiting + 1;
				if(waiting >= max_wait) begin
					waiting_ok = 1'b1;
					$display("TIMEOUT!, PLEASE DO NOT FORGET TO PUT 'DONE' ON THE FIRMWARE");
					$finish;
				end
				xorshift64_next;
			end
		end 
	end
	
	// ADC simulation
	always @(posedge ADCCLK) begin
		ADC_interface_AXI_BUSY <= ~ADC_interface_AXI_BUSY;
		ADC_interface_AXI_DATA <= xorshift64_state[9:0];
	end
	
	// completogpio simulation
	always @* begin
		completogpio_pindata = xorshift64_state[7:0];
	end

endmodule
