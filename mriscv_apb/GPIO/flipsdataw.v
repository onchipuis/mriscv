`timescale 1ns / 1ps

module flipsdataw(
    input en,clock,reset,
    input [1:0] datain,
    output reg  outdata,
	 output reg DS
    );
	 
	 //reg es1,es2;
	 always @ (posedge clock) begin
		
		if (!reset) begin
			DS<=0;
			outdata<=0;
			//es1<=0;
			//es2<=0;
		end
		

		else if (en) begin
			outdata<=datain[0];
			DS<=datain[1];
			//es1<=datain[0];
			//es2<=datain[1];
			
		end
	end

endmodule