`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
module macstate2(
	 input clock,
    input reset,
    output reg [4:0] salida,
    input AWvalid,
    input Wvalid,Bready,
    input ARvalid,Rready,
    input vel
    );
	
	reg [3:0] state,nexstate;
	parameter reposo = 4'd0000;
   parameter lectura = 4'b0001;
   parameter waitR = 4'b0010;
   parameter escritura = 4'b0011;
   parameter waitW = 4'b0100;
   parameter delay1 = 4'b0101;
	parameter delay2=4'b0110;
	parameter delay3=4'b0111;
	parameter delay4=4'b1000;
	parameter delay5=4'b1001;
	parameter delay6=4'b1010;
	parameter delay7=4'b1011;
	//asignacion estado siguiente
	
	always @(state,ARvalid,AWvalid,Wvalid,Bready,Rready,vel) begin
		case (state)
            reposo : begin
               if (ARvalid) begin
                  nexstate = lectura;
					end
               else if (AWvalid) begin
                  nexstate = waitW;
					end
               else begin
                  nexstate = reposo;
					end
            end
				
            lectura : begin
            	if(!vel) begin
                   nexstate = delay4;
                end
                else begin
                	nexstate=delay7;
                end
                
            end
				
            delay4 : begin
               nexstate=delay5;
            end
				
            delay5 : begin
               nexstate=delay6;
            end
				
				delay6: begin
					nexstate=delay7;
				end
				
				delay7: begin
					if (Rready) begin
						nexstate=reposo;
					end
					else begin
						nexstate=delay7;
					end
				end
				
				waitW : begin
               if (Wvalid) begin
                  nexstate = escritura;
					end
               else begin
                  nexstate = waitW;
					end
            end
				
			escritura : begin
              if (!vel) begin
              	nexstate=delay1;
              end
              else begin
              	nexstate=delay3;
              end
            end
				
				
            delay1 : begin
					nexstate=delay2;
            end
				
				delay2: begin
					nexstate=delay3;
				end
				
				delay3: begin
					if (Bready) begin
						nexstate=reposo;
					end
					else begin
						nexstate=delay3;
					end
				end
					
            default : begin  // Fault Recovery
               nexstate = reposo;
            end   
         endcase
		end
		
		// asignacion sincrona
		always @(posedge clock)
			if(reset == 0) state <= 3'b0;
			else state <= nexstate;
		
		// asignacion salidas
		
		always @(state) begin
			if (state==4'b0)
				salida=5'b00000;
			else if(state==4'b1)
				salida=5'b10000;
			else if (state==4'b010)
				salida=5'b11000;
			else if (state==4'b011)
				salida=5'b00110;
			else if (state==4'b100)
				salida=5'b00100;
			else if (state==4'b101)
				salida=5'b00110;
			else if (state==4'b110)
				salida=5'b00110;
			else if (state==4'b111)
				salida=5'b00111;
			else if (state==4'b1000)
				salida=5'b10000;
			else if (state==4'b1001)
				salida=5'b10000;
			else if (state==4'b1010)
				salida=5'b10000;
			else if (state==4'b1011)
				salida=5'b11000;
			else
				salida=5'b0;
			
			
		end
				
				
		
		

endmodule
