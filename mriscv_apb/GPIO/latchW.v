`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////////////////////
module latchW(
    input  clock,
    input  reset,
    input  enable,
    input [31:0] adress,
    output reg [2:0] Ladress
    );
	 
	 always @ ( posedge clock )
            if (!reset) begin
                Ladress=3'b0;
			end else if (enable) begin
				Ladress=adress[2:0];
			end

endmodule