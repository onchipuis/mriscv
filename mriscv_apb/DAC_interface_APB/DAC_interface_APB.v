`timescale 1ns / 1ps
module DAC_interface_APB(CLK, RST, PWRITE, PSEL, PENABLE, PREADY, PADDR, PWDATA, PSTRB, DATA, PRDATA);

//----general--input----
	input CLK,RST,PWRITE, PSEL, PENABLE;
//----general--output----
	output wire PREADY;
//----write--input----
	input [31:0] PADDR,PWDATA;
	input [3:0] PSTRB;
//----write--output----
	output wire [11:0] DATA;
//----write--signals----
	reg [4:0] delay;
	reg [1:0] state_write;
	reg [11:0] latch_PWDATA;
	reg ena_DATA;
	reg PREADY_W;
//----read--output----
	output wire [31:0] PRDATA;
//----read--signals----
	reg state_read, ena_PRDATA;
	reg PREADY_R;

//----FSM--WRITE----******************************************************************

	parameter START_W = 2'b00, SAVE_PWDATA = 2'b01, WORKING = 2'b10, READY_W = 2'b11, START_R = 1'b0, READY_R = 1'b1;		

//----RESET--PARAMETERS----

	always @( posedge CLK or negedge RST)
	begin		
	if (RST == 1'b0) begin
		state_write = START_W;
		delay = 5'b00000;
	end
//----LOGIC----
	else
		begin
			case (state_write)

			START_W :if (PSEL & PWRITE & PENABLE == 1'b1) 
				begin
					state_write = SAVE_PWDATA;
					delay = 5'b00000;
				end
			else
				begin
					state_write = START_W;
				end

			SAVE_PWDATA :
				begin 
					state_write = WORKING;
				end

			WORKING : if (delay == 5'b01010) 
				begin
					state_write = READY_W;
				end
			else
				begin
					state_write = WORKING;
					delay = delay + 5'b00001;
				end
			READY_W : 
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
				ena_DATA = 0;
		end
	//----LOGIC----
		else
		begin	
			case (state_write)
				START_W :begin //----0
					PREADY_W = 0;
					ena_DATA = 1;
					end
				SAVE_PWDATA :begin //----1
					PREADY_W = 0;
					ena_DATA = 1;
					end
				WORKING :begin //----2
					PREADY_W = 0;
					ena_DATA = 1;
					end
				READY_W :begin //----3
					PREADY_W = 1;
					ena_DATA = 1;
					end

				endcase
			end
		end

//----FLIP--FLOP--WRITE----***************************************************

	always @( posedge CLK )
	begin
		if (RST == 1'b0)
			begin
				latch_PWDATA <= 12'b0;
			end
		else if (PSEL & PWRITE & PENABLE == 1'b1) 
			begin
				latch_PWDATA <= PWDATA;
			end
		else 
			begin
				latch_PWDATA <= latch_PWDATA;
			end	
	end


//----OUTPUT--DATA----******************************************

assign DATA = ena_DATA ? latch_PWDATA : 12'b0;

//----OUTPUT--PREADY----****************************************

assign PREADY = PWRITE ? PREADY_W : PREADY_R;

//----OUTPUT--PRDATA----****************************************

assign PRDATA = ena_PRDATA ?  32'h55555555 : 32'b0;
 
//----FSM--READ----**********************************************


//----RESET--PARAMETERS----
	always @( posedge CLK or negedge RST)
	begin		
	if (RST == 1'b0) begin
		state_read = START_R;
	end
//----LOGIC----
	else
		begin
			case (state_read)
			START_R :if (PSEL & ~PWRITE & PENABLE == 1'b1) 
				begin
					state_read = READY_R;
				end
			else
				begin
					state_read = START_R;
				end
			
			READY_R :
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
				READY_R  :begin
					PREADY_R = 1;
					ena_PRDATA = 1;
					end

				endcase
		end
	end
endmodule

	
