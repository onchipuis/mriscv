`timescale 1ns / 1ps

module completogpio(
    input [31:0] WAddress,Wdata,
    input AWvalid,
	 input [7:0] pindata,
    input [31:0] RAddress,
    input Wvalid,
	 input clock,
	 input ARvalid,
	 input reset,
    input Rready,
    input Bready,
	 output reg ARready,Rvalid,AWready,Wready,Bvalid,
    output reg[7:0] Rx,datanw,
    output reg [7:0] Tx,DSE,
	 output reg [31:0] Rdata
    );
		
		wire [2:0] LWAddress,LRAddress;
		wire [7:0] W,R,Tm,Rm;
		wire [4:0] salm;
		wire [7:0] outdataw,DS;
		reg Rdata1,vel;
		

		

//decodificador para Wend		

 

	 
	// maquina
	macstate2 maquina (
		.clock(clock),
		.vel(vel), 
		.reset(reset), 
		.salida(salm), 
		.AWvalid(AWvalid), 
		.Wvalid(Wvalid), 
		.Bready(Bready), 
		.ARvalid(ARvalid), 
		.Rready(Rready)
		);


	////////////////////////////////////////////////////////////////////////

	 always @ (posedge clock) begin
		
		if (!reset) begin
			vel<=1;

		end
		
		else if (Wvalid) begin
			vel<=Wdata[2];
		end
		
		else begin
			vel<=vel;
		end
	end

/////////////////////////////////////

	
	// latch escritura
	latchW latchW (
		.clock(clock),
		.reset(reset),
		.AWvalid(AWvalid), 
		.WAddres(WAddress), 
		.LWAddres(LWAddress)
		);
	 
	 // latch lectura
	latchW latchR (
		.clock(clock),
		.reset(reset),
		.AWvalid(ARvalid), 
		.WAddres(RAddress), 
		.LWAddres(LRAddress)
		);
		
		// decodificador escritura
	decodificador decow (
		.AWready(salm[2]), 
		.clock(clock), 
		.LWAddress(LWAddress), 
		.W(W)
		);
	
	
	/////////////////////////////////////
	// Instantiate the module
	flipsdataw flipw1(
		.reset(reset),
		.en(W[0]), 
		.clock(clock), 
		.datain(Wdata[1:0]), 
		.outdata(outdataw[0]),
		.DS(DS[0])
		);
	flipsdataw flipw2 (
		.reset(reset),		
		.en(W[1]), 
		.clock(clock), 
		.datain(Wdata[1:0]), 
		.outdata(outdataw[1]),
		.DS(DS[1])
		);
	flipsdataw flipw3 (
		.reset(reset),
		.en(W[2]), 
		.clock(clock), 
		.datain(Wdata[1:0]), 
		.outdata(outdataw[2]),
		.DS(DS[2])
		);
	flipsdataw flipw4 (
		.reset(reset),
		.en(W[3]), 
		.clock(clock), 
		.datain(Wdata[1:0]), 
		.outdata(outdataw[3]),
		.DS(DS[3])
		);
	flipsdataw flipw5 (
		.reset(reset),
		.en(W[4]), 
		.clock(clock), 
		.datain(Wdata[1:0]), 
		.outdata(outdataw[4]),
		.DS(DS[4])
		);
	
	flipsdataw flipw6 (
		.reset(reset),
		.en(W[5]), 
		.clock(clock), 
		.datain(Wdata[1:0]), 
		.outdata(outdataw[5]),
		.DS(DS[5])
		);
	flipsdataw flipw7 (
		.reset(reset),
		.en(W[6]), 
		.clock(clock), 
		.datain(Wdata[1:0]), 
		.outdata(outdataw[6]),
		.DS(DS[6])
		);
	flipsdataw flipw8 (
		.reset(reset),
		.en(W[7]), 
		.clock(clock), 
		.datain(Wdata[1:0]), 
		.outdata(outdataw[7]),
		.DS(DS[7])
		);		
	
	 
	
	
	/////////////////////////////////////
	
	// decodificador lectura
	decodificador decor (
		.AWready(salm[4]), 
		.clock(clock), 
		.LWAddress(LRAddress), 
		.W(R)
		);
	
	/////////////////////////////////////////////////////////////////
		///////////FLIP FLOPS//////////////////////////////////
		
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
	 
/*	 always @(P , reset) begin
		if (!reset) begin
			Rx=0;
			Tx=0;
		end
		else begin
			Rx=~P;
			Tx=P;
		end
	end
*/

   always @(LRAddress or pindata) begin
      case (LRAddress)
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
         Rdata[0] <= 1'b0;
      end else begin
         Rdata[0] <= Rdata1;
      end
						


	always@* begin
		DSE=DS;
		Rdata[31:1]=0;
		Tx=Tm;
		Rx=Rm;
		Bvalid=salm[0];
		Wready=salm[1];
		AWready=salm[2];
		Rvalid=salm[3];
		ARready=salm[4];
		datanw=outdataw;
		//Rend=1'b1;
		//Wend=1'b1;
		end
endmodule

