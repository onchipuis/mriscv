`timescale 1ns / 1ps

module decodificador(
    input Psel,
	 input clock,
    input [2:0] Lrad,
    output [7:0] W
    );
	 	      
   assign W = Psel? (1 << Lrad) : 0;

endmodule
