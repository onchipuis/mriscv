`timescale 1ns / 1ps

module decodificador(
    input AWready,
	 input clock,
    input [2:0] LWAddress,
    output [7:0] W
    );
	 
	      
   assign W = AWready? (1 << LWAddress) : 0;
   /*always @(posedge clock)
      if (!AWready)
         W <= 8'h00;
      else
         case (LWAddress)
            3'b000  : W <= 8'b00000001;
            3'b001  : W <= 8'b00000010;
            3'b010  : W <= 8'b00000100;
            3'b011  : W <= 8'b00001000;
            3'b100  : W <= 8'b00010000;
            3'b101  : W <= 8'b00100000;
            3'b110  : W <= 8'b01000000;
            default  : W <= 8'b10000000;
            
         endcase*/
				


endmodule
