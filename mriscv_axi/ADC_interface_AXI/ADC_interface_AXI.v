`timescale 1ns / 1ps
module ADC_interface_AXI (CLK,RST,AWVALID,WVALID,BREADY,AWADDR,WDATA,WSTRB,AWREADY,WREADY,BVALID,DATA,ARADDR,ARVALID,RREADY,ARREADY,RVALID,RDATA,BUSY);

//----general--input----
	input CLK,RST;
//----write--input----
	input AWVALID,WVALID, BREADY;
	input [31:0] AWADDR,WDATA;
	input [3:0] WSTRB;
//----write--output----
	output reg AWREADY, WREADY, BVALID;	
//----write--signals----		
	reg [2:0] state_write;
//----read--input----
	input [31:0] ARADDR;
	input ARVALID,RREADY,BUSY;
	input [9:0] DATA;
//----read--output----
	output reg ARREADY, RVALID;
	output wire [31:0] RDATA;
//----read--signals----
	reg [2:0] state_read;
	reg [9:0] latch_DATA;
	reg ena_rdata;

//----FSM--WRITE----

	parameter START_W = 3'b000, WAIT_BREADY = 3'b001, START_R = 3'b010, PROCESS = 3'b011;		

//----RESET--PARAMETERS----

	always @( posedge CLK or negedge RST)
	begin		
	if (RST == 1'b0) begin
		state_write = START_W;
	end
//----LOGIC----
	else
		begin
			case (state_write)
			START_W :if (AWVALID == 1'b1) 
				begin
					state_write = WAIT_BREADY;
				end
			else
				begin
					state_write = START_W;
				end
			WAIT_BREADY : if (BREADY == 1'b1)
				begin 
					state_write = START_W;
				end
			else
				begin
					state_write = WAIT_BREADY;
				end
			default : state_write = START_W;
			endcase
		end
	end
//----OUTPUTS--FSM--WRITE----
	always @(posedge CLK or negedge RST)
	begin		
		if (RST == 1'b0)
		begin
				AWREADY <= 0;
				WREADY <= 0;
				BVALID <= 0;
		end
	//----LOGIC----
		else
		begin	
			case (state_write)
				START_W :begin //----0
					AWREADY <= 1;
					WREADY <= 0;
					BVALID <= 0;
					end
				WAIT_BREADY  :begin //----1
					AWREADY <= 1;
					WREADY <= 1;
					BVALID <= 1;
					end				
			endcase
		end
	end

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
			START_R :if (ARVALID == 1'b1) 
				begin
					state_read = PROCESS;
				end
			else
				begin
					state_read = START_R;
				end
			
			PROCESS : if (RREADY == 1'b1)
				begin 
					state_read = START_R;
				end
			else
				begin
					state_read = PROCESS;
				end
			
			default : state_read = START_R;
			endcase
		end
	end
//----OUTPUTS--FSM--READ----
	always @(posedge CLK)
	begin		
		if (RST == 1'b0)
		begin
			ARREADY <= 0;
			RVALID <= 0;
		end

//----LOGIC----
		else
		begin	
				case (state_read)
				START_R :begin
					ARREADY <= 0;
					RVALID <= 0;
					ena_rdata <= 0;
					end
				PROCESS :begin
					ARREADY <= 1;
					RVALID <= 1;
					ena_rdata <= 1;
					end
				default : begin
					ARREADY <= 0;
					RVALID <= 0;
					ena_rdata <= 0;			
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
		else begin
			if (BUSY)			
			begin
			latch_DATA <= DATA;
			end
			else begin
			latch_DATA <= latch_DATA;
			end
		end		
	end

assign RDATA = ena_rdata ? latch_DATA:10'b0;

endmodule

	
