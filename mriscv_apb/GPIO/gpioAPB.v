`timescale 1ns / 1ps


module gpioAPB(
    input clock,
    input reset,
    input [31:0] Paddr,
    input Penable,
    input Pwrite,
    input [31:0] Pwdata,
	 input [7:0] pindata,
    input Psel,
    output reg [31:0] Prdata,
	 output reg[7:0] Rx,datanw,
    output reg [7:0] Tx,DSE,
    output Pready,
	 input [3:0] strobe
    );
	 
	 wire [2:0] lwad,lrad;
	 wire [7:0] W,R,Tm,Rm,outdataw,DS;
	 reg Rdata1,vel;
	 		
// Instantiate the module
latchW lawrite (
    .clock(clock), 
    .reset(reset), 
    .enable(Pwrite), 
    .adress(Paddr), 
    .Ladress(lwad)
    );

// Instantiate the module
latchW laread (
    .clock(clock), 
    .reset(reset), 
    .enable(~Pwrite), 
    .adress(Paddr), 
    .Ladress(lrad)
    );

//decodificador escritura
decodificador decow (
    .Psel(Psel), 
    .clock(clock), 
    .Lrad(lwad), 
    .W(W)
    );

// decodificador lectura
decodificador decoR (
    .Psel(Psel), 
    .clock(clock), 
    .Lrad(lrad), 
    .W(R)
    );

// maquina estados
	macstate2 maquina (
		.vel(vel),
		.clock(clock), 
		.reset(reset), 
		.Pready(Pready), 
		.Penable(Penable), 
		.Pwrite(Pwrite)
		);
	
//////////////////////////////////////////////////////////////

	 always @ (posedge clock) begin
		
		if (!reset) begin
			vel<=1;
			
		end

		else begin
			vel<=Pwdata[2];
		
		end
	end

//////////////// FLIPS FLOPS HABILITADORES////////////////////

		// flip1
	flipflopRS flip1 (
		.reset(reset),
		.Tx(Tm[0]),
		.Rx(Rm[0]),
		.W1(W[0]), 
		.R1(R[0]), 
		.clock(clock)
		);

		// flip2
	flipflopRS flip2 (
		.reset(reset),
		.Tx(Tm[1]),
		.Rx(Rm[1]),
		.W1(W[1]), 
		.R1(R[1]), 
		.clock(clock)
		);

		// flip3
	flipflopRS flip3 (
		.reset(reset),
		.Tx(Tm[2]),
		.Rx(Rm[2]),
		.W1(W[2]), 
		.R1(R[2]), 
		.clock(clock)
		);

		// flip4
	flipflopRS flip4 (
		.reset(reset),
		.Tx(Tm[3]),
		.Rx(Rm[3]), 
		.W1(W[3]), 
		.R1(R[3]), 
		.clock(clock)
		);
		
		// flip5
	flipflopRS flip5 (
		.reset(reset),
		.Tx(Tm[4]),
		.Rx(Rm[4]),
		.W1(W[4]), 
		.R1(R[4]), 
		.clock(clock)
		);
		
		// flip6
	flipflopRS flip6 (
		.reset(reset),
		.Tx(Tm[5]),
		.Rx(Rm[5]),
		.W1(W[5]), 
		.R1(R[5]), 
		.clock(clock)
		);
		
		// flip7
	flipflopRS flip7 (
		.reset(reset),
		.Tx(Tm[6]),
		.Rx(Rm[6]),
		.W1(W[6]), 
		.R1(R[6]), 
		.clock(clock)
		);

		// flip8
	flipflopRS flip8 (
		.reset(reset),
		.Tx(Tm[7]),
		.Rx(Rm[7]),
		.W1(W[7]), 
		.R1(R[7]), 
		.clock(clock)
		);

///////////////////// FLIPS PARA DATO ESCRITURA	

	/////////////////////////////////////
	// Instantiate the module
	flipsdataw flipw1(
		.en(W[0]), 
		.clock(clock),
		.reset(reset), 
		.datain(Pwdata[1:0]), 
		.outdata(outdataw[0]),
		.DS(DS[0])
		);
		
	flipsdataw flipw2 (
		.en(W[1]),
		.reset(reset), 
		.clock(clock), 
		.datain(Pwdata[1:0]), 
		.outdata(outdataw[1]),
		.DS(DS[1])
		);
		
	flipsdataw flipw3 (
		.en(W[2]), 
		.clock(clock), 
		.reset(reset), 
		.datain(Pwdata[1:0]), 
		.outdata(outdataw[2]),
		.DS(DS[2])
		);
		
	flipsdataw flipw4 (
		.en(W[3]), 
		.clock(clock), 
		.reset(reset), 
		.datain(Pwdata[1:0]), 
		.outdata(outdataw[3]),
		.DS(DS[3])
		);
		
	flipsdataw flipw5 (
		.en(W[4]), 
		.clock(clock), 
		.reset(reset), 
		.datain(Pwdata[1:0]), 
		.outdata(outdataw[4]),
		.DS(DS[4])
		);
	
	flipsdataw flipw6 (
		.en(W[5]), 
		.clock(clock), 
		.reset(reset), 
		.datain(Pwdata[1:0]), 
		.outdata(outdataw[5]),
		.DS(DS[5])
		);

	flipsdataw flipw7 (
		.en(W[6]), 
		.clock(clock), 
		.reset(reset), 
		.datain(Pwdata[1:0]), 
		.outdata(outdataw[6]),
		.DS(DS[6])
		);

	flipsdataw flipw8 (
		.en(W[7]), 
		.clock(clock), 
		.reset(reset), 
		.datain(Pwdata[1:0]), 
		.outdata(outdataw[7]),
		.DS(DS[7])
		);		

///////////////////////////////////////////////////

   always @(lrad,pindata) begin
      case (lrad)
         3'b000: Rdata1 =pindata[0];
         3'b001: Rdata1 =pindata[1];
         3'b010: Rdata1 =pindata[2];
         3'b011: Rdata1 =pindata[3];
         3'b100: Rdata1 =pindata[4];
         3'b101: Rdata1 =pindata[5];
         3'b110: Rdata1 =pindata[6];
         3'b111: Rdata1 =pindata[7];
      endcase
	end
	
   always @(posedge clock)
      if (!reset) begin
         Prdata[0] <= 1'b0;
      end else begin
         Prdata[0] <= Rdata1;
      end
						
	always@* begin
		DSE=DS;
		Prdata[31:1]=0;
		Tx=Tm;
		Rx=Rm;
		datanw=outdataw;

		end

endmodule
