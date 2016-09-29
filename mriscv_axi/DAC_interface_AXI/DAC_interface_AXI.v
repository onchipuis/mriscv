`timescale 1ns / 1ps
module DAC_interface_AXI(CLK,RST,AWVALID,WVALID,BREADY,AWADDR,WDATA,WSTRB,AWREADY,WREADY,BVALID,DATA,ARVALID,RREADY,ARREADY,RVALID,RDATA);

//----general--input----
	input CLK,RST;
//----write--input----
	input AWVALID,WVALID, BREADY;
	input [31:0] AWADDR,WDATA;
	input [3:0] WSTRB;
//----write--output----
	output reg AWREADY, WREADY, BVALID;	
	output wire [11:0] DATA;
//----write--signals----
	reg [4:0] delay;
	reg [2:0] state_write;
	reg [11:0] latch_WDATA;
	reg latch_reset, Q_WVALID, ena_DATA;
	wire latch_WVALID;
//----read--input----
	input ARVALID,RREADY;
//----read--output----
	output reg ARREADY, RVALID;
	output reg [31:0] RDATA;
//----read--signals----
	reg state_read;

//----FSM--WRITE----

	parameter START_W = 3'b000, WAIT_WVALID = 3'b001, SAVE_WDATA = 3'b010, WORKING = 3'b011, RESET = 3'b100, START_R = 1'b0, WAIT_RREADY = 1'b1;		

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

			START_W :if (AWVALID == 1'b1) 
				begin
					state_write = WAIT_WVALID;
					delay = 5'b00000;
				end
			else
				begin
					state_write = START_W;
				end

			WAIT_WVALID : if (WVALID == 1'b1)
				begin 
					state_write = SAVE_WDATA;
				end
			else
				begin
					state_write = WAIT_WVALID;
				end


			SAVE_WDATA :
				begin 
					state_write = WORKING;
				end


			WORKING : if (delay == 5'b01010) 
				begin
					state_write = RESET;
				end
			else
				begin
					state_write = WORKING;
					delay = delay + 5'b00001;
				end


			RESET : if (BREADY == 1'b1) 
				begin
					state_write = START_W;
				end
			else
				begin
					state_write = RESET;
				end

			default :
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
				AWREADY = 0;
				WREADY = 0;
				BVALID = 0;
				ena_DATA = 0;
				latch_reset = 0;
		end
	//----LOGIC----
		else
		begin	
			case (state_write)
				START_W :begin //----0
					AWREADY = 0;
					WREADY = 0;
					BVALID = 0;
					ena_DATA = 1;
					latch_reset = 0;
					end
				WAIT_WVALID :begin //----1
					AWREADY = 1;
					WREADY = 0;
					BVALID = 0;
					ena_DATA = 1;
					latch_reset = 0;
					end
				SAVE_WDATA :begin //----2
					AWREADY = 1;
					WREADY = 1;
					BVALID = 0;
					ena_DATA = 1;
					latch_reset = 0;
					end
				WORKING :begin //----3
					AWREADY = 1;
					WREADY = 1;
					BVALID = 0;
					ena_DATA = 1;
					latch_reset = 0;
					end
				RESET :begin //----4
					AWREADY = 1;
					WREADY = 1;
					BVALID = 1;
					ena_DATA = 1;
					latch_reset = 1;
					end
					
				default :begin
					AWREADY = 0;
					WREADY = 0;
					BVALID = 0;
					ena_DATA = 1;
					latch_reset = 0;
					end		
						
				

				endcase
			end
		end
//----LATCH_WVALID----

assign latch_WVALID = WVALID & ~Q_WVALID;

	always @( posedge CLK )
	begin
		if (RST == 1'b0 || latch_reset )
			begin
				Q_WVALID <= 1'b0;
			end
		else
			begin
				Q_WVALID <= WVALID;
			end
	end


//----FLIP--FLOPS--WRITE----

	always @( posedge CLK )
	begin
		if (RST == 1'b0)
			begin
				latch_WDATA <= 32'b0;
			end
		else if (latch_WVALID) 
			begin
				latch_WDATA <= WDATA;
			end
		else 
			begin
				latch_WDATA <= latch_WDATA;
			end	
	end

//----OUTPUT--DATA----

assign DATA = ena_DATA ? latch_WDATA : 12'b0;
 
//----FSM--READ----


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
			START_R :if (ARVALID == 1'b1) 
				begin
					state_read = WAIT_RREADY;
				end
			else
				begin
					state_read = START_R;
				end
			
			WAIT_RREADY : if (RREADY == 1'b1)
				begin 
					state_read = START_R;
				end
			else
				begin
					state_read = WAIT_RREADY;
				end
			
			endcase
		end
	end
//----OUTPUTS--FSM--READ----
	always @(state_read or RST)
	begin		
		if (RST == 1'b0)
		begin
			ARREADY = 0;
			RVALID = 0;
			RDATA = 32'b0;
		end
//----LOGIC----
		else
		begin	
				case (state_read)
				START_R :begin
					ARREADY = 1;
					RVALID = 0;
					RDATA = 32'b0;
					end
				WAIT_RREADY  :begin
					ARREADY = 1;
					RVALID = 1;
					RDATA = 32'h55555555;
					end
	
				endcase
		end
	end
endmodule

	
