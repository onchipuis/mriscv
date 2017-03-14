`timescale 1ns / 1ps

module flipflopRS(
    
    output reg Rx,Tx,
    input W1,reset,
    input R1,
    input clock
    );

	reg D;
   always @(posedge clock)
		if (!reset) begin
			Rx<=1'b0;
			Tx<=1'b1;			
		end
      else if (R1 && !W1) begin
         Tx <= 1'b1;
	Rx<=1'b1;
			
      end else if (W1 && !R1) begin
          Tx<= 1'b0;
	Rx<=1'b0;
			 
		
	end
	else begin
		Tx<=Tx;
		Rx<=Rx;
			
      end

endmodule
