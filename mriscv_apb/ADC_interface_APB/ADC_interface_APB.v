`timescale 1ns / 1ps
module ADC_interface_APB(CLK, RST, PWRITE, PSEL, PENABLE, PREADY, PADDR, PWDATA, PSTRB, PRDATA, BUSY, DATA);

//----general--input----
	input CLK,RST,PWRITE, PSEL, PENABLE;
//----general--output----
	output wire PREADY;
//----write--input----
	input [31:0] PADDR,PWDATA;
	input [3:0] PSTRB;
//----write--output----

//----write--signals----
	reg state_write;
	reg PREADY_W;
//----read--input----
	input [9:0] DATA;
	input BUSY;
//----read--output----
	output wire [31:0] PRDATA;
//----read--signals----
	reg state_read, ena_PRDATA;
	reg PREADY_R;
	reg [9:0] latch_DATA; 


//----FSM--WRITE----

	parameter START_W = 1'b0, PREADY_P = 1'b1, START_R = 1'b0, PROCESS = 1'b1;		

//----RESET--PARAMETERS----

	always @( posedge CLK or negedge RST)
	begin		
	if (~RST) begin
		state_write = START_W;
	end
//----LOGIC----
	else
		begin
			case (state_write)

			START_W :if (PSEL & PWRITE & PENABLE == 1'b1) 
				begin
					state_write = PREADY_P;
				end
			else
				begin
					state_write = START_W;
				end

			PREADY_P: 
				begin 
					state_write = START_W;
				end

			endcase
		end
	end
//----OUTPUTS--FSM--WRITE----
	always @(state_write or RST)
	begin		
		if (RST == 1'b0)
		begin
				PREADY_W = 0;
		end
	//----LOGIC----
		else
		begin	
			case (state_write)
				START_W :begin //----0
				PREADY_W = 0;
					end
				PREADY_P :begin //----1
				PREADY_W = 1;
					end				
			endcase
		end
	end
//----OUTPUT--PREADY----****************************************

assign PREADY = PWRITE ? PREADY_W : PREADY_R;
//----FSM--READ----


//----RESET--PARAMETERS----
	always @( posedge CLK or negedge RST)
	begin		
	if (~RST) begin
		state_read = START_R;
	end
//----LOGIC----
	else
		begin
			case (state_read)
			START_R :if (PSEL & ~PWRITE & PENABLE == 1'b1) 
				begin
					state_read = PROCESS;
				end
			else
				begin
					state_read = START_R;
				end
			
			PROCESS: 
				begin 
					state_read = START_R;
				end
						
			endcase
		end
	end
//----OUTPUTS--FSM--READ----
	always @(state_read or RST)
	begin		
		if (RST == 1'b0)
		begin
				PREADY_R = 0;
				ena_PRDATA = 0;
		end

//----LOGIC----
		else
		begin	
				case (state_read)
				START_R :begin
					PREADY_R = 0;
					ena_PRDATA = 0;
					end
				PROCESS :begin
					PREADY_R = 1;
					ena_PRDATA = 1;
					end

				endcase
		end
	end

//----FLIP--FLOPS--WRITE----
	always @( posedge CLK )
	begin
		if (~RST) begin
			latch_DATA <= 10'b0;
		end
		else 
		begin
			if (BUSY)			
				begin
					latch_DATA <= DATA;
				end
			else 
				begin
					latch_DATA <= latch_DATA;
				end
		end		
	end

assign PRDATA = ena_PRDATA ? latch_DATA:10'b0;

//----OUTPUT--PREADY----****************************************

assign PREADY = PWRITE ? PREADY_W : PREADY_R;

endmodule

	
