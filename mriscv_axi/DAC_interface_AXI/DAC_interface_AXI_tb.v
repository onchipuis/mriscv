`timescale 1ns / 1ps

module DAC_interface_AXI_tb;
parameter CLKPERIOD = 10;

reg CLK = 0, RST;
reg AWVALID, WVALID, BREADY;
reg [31:0] AWADDR, WDATA;
reg [3:0] WSTRB; 
reg ARVALID, RREADY;

wire AWREADY, WREADY, BVALID;
wire [11:0] DATA;
wire ARREADY, RVALID;
wire [31:0] RDATA; 

DAC_interface_AXI DAC_interface_AXI_inst(
		.RST(RST),
		.CLK(CLK),
		.AWVALID(AWVALID),
		.WVALID(WVALID),
		.BREADY(BREADY),
		.AWADDR(AWADDR),
		.WDATA(WDATA),
		.WSTRB(WSTRB),
		.AWREADY(AWREADY),
		.WREADY(WREADY),
		.BVALID(BVALID), 
		.DATA(DATA), 
		.ARVALID(ARVALID),
		.RREADY(RREADY),
		.ARREADY(ARREADY),
		.RVALID(RVALID),
		.RDATA(RDATA));

always 
	begin
		#(CLKPERIOD/2) CLK = ~CLK;
	end

initial begin

RST <= 1'b0;

#(CLKPERIOD*100);//-------------------------START_W--AND--START_R

/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h12345678;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bx;
AWVALID <= 1'bx;
WVALID <= 1'bx;
BREADY <= 1'bx;
AWADDR <= 32'bx; 
WDATA <= 32'hx;
ARVALID <= 1'bX;
RREADY <= 1'bX;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bz;
AWVALID <= 1'bz;
WVALID <= 1'bz;
BREADY <= 1'bz;
AWADDR <= 32'bz; 
WDATA <= 32'hz;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------
*/

RST <= 1'b1;
AWVALID <= 1'b1;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h12345678;
ARVALID <= 1'b1;
RREADY <= 1'b0;

#(CLKPERIOD*20);//-------------------------WAIT_WVALID--AND--WAIT_RREADY
/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h12345678;
ARVALID <= 1'b0;
RREADY <= 1'b0;


#(CLKPERIOD*5);//-------------------------

RST <= 1'bX;
AWVALID <= 1'bX;
WVALID <= 1'bX;
BREADY <= 1'bX;
AWADDR <= 32'bX; 
WDATA <= 32'bX;
ARVALID <= 1'bX;
RREADY <= 1'bX;


#(CLKPERIOD*5);//-------------------------

RST <= 1'bZ;
AWVALID <= 1'bZ;
WVALID <= 1'bZ;
BREADY <= 1'bZ;
AWADDR <= 32'bZ; 
WDATA <= 32'bZ;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------
*/
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b1;
BREADY <= 1'b1;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h55555555;
ARVALID <= 1'b0;
RREADY <= 1'b1;

#(CLKPERIOD*20);//-------------------------WORKING--AND--START_R
/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h12345678;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bX;
AWVALID <= 1'bX;
WVALID <= 1'bX;
BREADY <= 1'b0;
AWADDR <= 32'bX; 
WDATA <= 32'bX;
ARVALID <= 1'bX;
RREADY <= 1'bX;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bZ;
AWVALID <= 1'bZ;
WVALID <= 1'bZ;
BREADY <= 1'bZ;
AWADDR <= 32'bZ; 
WDATA <= 32'bZ;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*10);
*/
//----------------------------------reset------------------------

RST <= 1'b0;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'h0; 
WDATA <= 32'h0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*100);//-------------------------START_R--AND--START_W
/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff2; 
WDATA <= 32'h87654321;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bx;
AWVALID <= 1'bx;
WVALID <= 1'bx;
BREADY <= 1'bx;
AWADDR <= 32'bx; 
WDATA <= 32'hx;
ARVALID <= 1'bX;
RREADY <= 1'bX;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bz;
AWVALID <= 1'bz;
WVALID <= 1'bz;
BREADY <= 1'bz;
AWADDR <= 32'bz; 
WDATA <= 32'hz;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b1;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff2; 
WDATA <= 32'h87654321;
ARVALID <= 1'b1;
RREADY <= 1'b0;

*/

RST <= 1'b1;
AWVALID <= 1'b1;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h44444444;
ARVALID <= 1'b1;
RREADY <= 1'b0;


#(CLKPERIOD*20);//-------------------------WAIT_WVALID--AND--WAIT_RREADY
/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff2; 
WDATA <= 32'h87654321;
ARVALID <= 1'b0;
RREADY <= 1'b0;


#(CLKPERIOD*5);//-------------------------

RST <= 1'bX;
AWVALID <= 1'bX;
WVALID <= 1'bX;
BREADY <= 1'bX;
AWADDR <= 32'bX; 
WDATA <= 32'bX;
ARVALID <= 1'bX;
RREADY <= 1'bX;


#(CLKPERIOD*5);//-------------------------

RST <= 1'bZ;
AWVALID <= 1'bZ;
WVALID <= 1'bZ;
BREADY <= 1'bZ;
AWADDR <= 32'bZ; 
WDATA <= 32'bZ;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b1;
BREADY <= 1'b1;
AWADDR <= 32'hfffffff2; 
WDATA <= 32'h87654321;
ARVALID <= 1'b0;
RREADY <= 1'b1;
*/
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b1;
BREADY <= 1'b1;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h44444444;
ARVALID <= 1'b0;
RREADY <= 1'b1;

#(CLKPERIOD*20);//-------------------------WORKING--AND--START_R
/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff2; 
WDATA <= 32'h87654321;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bX;
AWVALID <= 1'bX;
WVALID <= 1'bX;
BREADY <= 1'b0;
AWADDR <= 32'bX; 
WDATA <= 32'bX;
ARVALID <= 1'bX;
RREADY <= 1'bX;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bZ;
AWVALID <= 1'bZ;
WVALID <= 1'bZ;
BREADY <= 1'bZ;
AWADDR <= 32'bZ; 
WDATA <= 32'bZ;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------


RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b1;

#(CLKPERIOD*10)
*/
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'h0; 
WDATA <= 32'h0;
ARVALID <= 1'b0;
RREADY <= 1'b1;


//-------------------------START_R--AND--START_W

//----------------------------------NO--reset------------------------

//RST <= 1'b0;

#(CLKPERIOD*100);//-------------------------START_R--AND--START_W
/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff3; 
WDATA <= 32'h55555555;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bx;
AWVALID <= 1'bx;
WVALID <= 1'bx;
BREADY <= 1'bx;
AWADDR <= 32'bx; 
WDATA <= 32'hx;
ARVALID <= 1'bX;
RREADY <= 1'bX;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bz;
AWVALID <= 1'bz;
WVALID <= 1'bz;
BREADY <= 1'bz;
AWADDR <= 32'bz; 
WDATA <= 32'hz;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b1;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff3; 
WDATA <= 32'h55555555;
ARVALID <= 1'b1;
RREADY <= 1'b0;
*/
RST <= 1'b1;
AWVALID <= 1'b1;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h66666666;
ARVALID <= 1'b1;
RREADY <= 1'b0;

#(CLKPERIOD*20);//-------------------------WAIT_WVALID--AND--WAIT_RREADY
/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff3; 
WDATA <= 32'h55555555;
ARVALID <= 1'b0;
RREADY <= 1'b0;


#(CLKPERIOD*5);//-------------------------

RST <= 1'bX;
AWVALID <= 1'bX;
WVALID <= 1'bX;
BREADY <= 1'bX;
AWADDR <= 32'bX; 
WDATA <= 32'bX;
ARVALID <= 1'bX;
RREADY <= 1'bX;


#(CLKPERIOD*5);//-------------------------

RST <= 1'bZ;
AWVALID <= 1'bZ;
WVALID <= 1'bZ;
BREADY <= 1'bZ;
AWADDR <= 32'bZ; 
WDATA <= 32'bZ;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------


RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b1;
BREADY <= 1'b1;
AWADDR <= 32'hfffffff3; 
WDATA <= 32'h55555555;
ARVALID <= 1'b0;
RREADY <= 1'b1;

*/

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b1;
BREADY <= 1'b1;
AWADDR <= 32'hfffffff1; 
WDATA <= 32'h66666666;
ARVALID <= 1'b0;
RREADY <= 1'b1;

#(CLKPERIOD*100);//-------------------------WORKING--AND--START_R
/*
RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'hfffffff3; 
WDATA <= 32'h55555555;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bX;
AWVALID <= 1'bX;
WVALID <= 1'bX;
BREADY <= 1'b0;
AWADDR <= 32'bX; 
WDATA <= 32'bX;
ARVALID <= 1'bX;
RREADY <= 1'bX;

#(CLKPERIOD*5);//-------------------------

RST <= 1'bZ;
AWVALID <= 1'bZ;
WVALID <= 1'bZ;
BREADY <= 1'bZ;
AWADDR <= 32'bZ; 
WDATA <= 32'bZ;
ARVALID <= 1'bZ;
RREADY <= 1'bZ;

#(CLKPERIOD*5);//-------------------------

RST <= 1'b1;
AWVALID <= 1'b0;
WVALID <= 1'b0;
BREADY <= 1'b0;
AWADDR <= 32'b0; 
WDATA <= 32'b0;
ARVALID <= 1'b0;
RREADY <= 1'b0;

#(CLKPERIOD*10)

//-------------------------START--AND--WAIT_RREADY
*/
$finish;

end
endmodule
