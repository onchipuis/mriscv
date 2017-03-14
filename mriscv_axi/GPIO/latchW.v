`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////////////////////
module latchW(
    input  clock,
    input  reset,
    input  AWvalid,
    input [31:0] WAddres,
    output reg [2:0] LWAddres
    );
	 
	 always @ ( posedge clock )
            if (!reset) begin
                LWAddres=3'b0;
			end else if (AWvalid) begin
				LWAddres=WAddres[2:0];
			end

endmodule
