`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
module macstate2(
	 input clock,
    input reset,
    output reg Pready,
    input Penable,
    input Pwrite,
	 input vel
    );
	
	reg [3:0] state,nexstate;
	parameter reposo = 4'd0;
   parameter sel = 4'b0001;
   parameter lectura = 4'b010;
   parameter waitR = 4'b0011;
   parameter endR = 4'b0100;
   parameter escritura = 4'b0101;
	parameter waitW = 4'b0110;
	parameter endW = 4'b0111;
	parameter delay1=4'b1000;
	parameter delay2=4'b1001;
	parameter delay3=4'b1010;
	parameter delay4=4'b1011;
	parameter delay5=4'b1100;
	parameter delay6=4'b1101;
	//asignacion estado siguiente
	
	always @(Pwrite,Penable,state) begin
		case (state)
            reposo : begin
               if (Penable) begin
                  nexstate = sel;
					end
               else begin
						nexstate = reposo;
					end
               
            end
            sel : begin
               if (!Pwrite) begin
                  nexstate = lectura;
					end
               else begin
                  nexstate = escritura;
					end
            end
            lectura : begin
					if(!vel) begin
                  nexstate = delay1;
					end
					else begin
						nexstate=endR;
					end
				end
               
				
				delay1 : begin
               nexstate=delay2;
            end
				
				delay2 : begin
               nexstate=delay3;
            end
				
				delay3 : begin
               nexstate=waitR;
            end
				
            waitR : begin
                  nexstate =endR;
            end
				
				endR : begin
					nexstate=reposo;
				end

            escritura : begin
					if (!vel) begin
                  nexstate = delay4;
					end
					else begin
						nexstate=endW;
					end
            end
				
				delay4 : begin
               nexstate=delay5;
            end
				
				delay5 : begin
               nexstate=delay6;
            end
				
				delay6 : begin
               nexstate=waitW;
            end
				
				waitW : begin
					nexstate=endW;
				end
				
				endW : begin
					nexstate=reposo;
				end
				
            default : begin  // Fault Recovery
               nexstate = reposo;
            end   
         endcase
		end
		
		// asignacion sincrona
		always @(posedge clock)
			if(reset == 0) state <= 4'b0;
			else state <= nexstate;
		
		// asignacion salidas
		
		always @(state) begin
			if (state==4'b0)
				Pready=0;
			else if(state==4'b1)
				Pready=0;
			else if (state==4'b0010)
				Pready=0;
			else if (state==4'b0011)
				Pready=1;
			else if (state==4'b0100)
				Pready=1;
			else if(state==4'b0101)
				Pready=0;
			else if(state==4'b0110)
				Pready=1;
			else if(state==4'b0111)
				Pready=1;
			else if(state==4'b1000)
				Pready=0;
			else if(state==4'b1001)
				Pready=0;
			else if(state==4'b1010)
				Pready=0;
			else if(state==4'b1011)
				Pready=0;
			else if(state==4'b1100)
				Pready=0;
				
			else
				Pready=0;
		end

endmodule
