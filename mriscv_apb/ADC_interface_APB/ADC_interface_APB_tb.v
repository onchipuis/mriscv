`timescale 1ns / 1ps

module ADC_interface_APB_tb;
parameter CLKPERIOD = 10;

reg CLK = 0, RST;
reg PWRITE, PSEL, PENABLE;
reg [31:0] PADDR, PWDATA;
reg [3:0] PSTRB; 
reg [9:0] DATA;
reg BUSY;

wire PREADY;
wire [31:0] PRDATA; 

ADC_interface_APB ADC_interface_APB_inst(
		.RST(RST),
		.CLK(CLK),
		.PWRITE(PWRITE),
		.PSEL(PSEL),
		.PENABLE(PENABLE),
		.PADDR(PADDR),
		.PWDATA(PWDATA),
		.PSTRB(PSTRB),
		.PREADY(PREADY),
		.DATA(DATA),
		.PRDATA(PRDATA),
		.BUSY(BUSY));

always 
	begin
		#(CLKPERIOD/2) CLK = ~CLK;
	end

initial begin

RST <= 1'b0;

#(CLKPERIOD*20);//-------------------------START_W--AND--START_R

RST <= 1'b1;
PWRITE <= 1'b0;
PSEL <= 1'b1;
PENABLE <= 1'b1; 
PWDATA <= 32'h55555555;
PADDR <= 32'h55555555;
PSTRB <= 4'b1;
BUSY <= 1'b1;
DATA <= 10'b0000001111;

#(CLKPERIOD*2);//-------------------------WAIT_WVALID--AND--WAIT_RREADY
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
PWRITE <= 1'b0;
PSEL <= 1'b1;
PENABLE <= 1'b1; 
PWDATA <= 32'h44444444;
PADDR <= 32'h55555555;
PSTRB <= 4'b1;
BUSY <= 1'b1;
DATA <= 10'b0000001011;


#(CLKPERIOD*2);//-------------------------WORKING--AND--START_R
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
PWRITE <= 1'b0;
PSEL <= 1'b0;
PENABLE <= 1'b0; 
PWDATA <= 32'h0;
PADDR <= 32'h0;
PSTRB <= 4'b0;
BUSY <= 1'b0;
DATA <= 10'b0;


#(CLKPERIOD*20);//-------------------------START_R--AND--START_W
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
PWRITE <= 1'b0;
PSEL <= 1'b1;
PENABLE <= 1'b1; 
PWDATA <= 32'h33333333;
PADDR <= 32'h55555555;
PSTRB <= 4'b1;
BUSY <= 1'b1;
DATA <= 10'b0000000001;


#(CLKPERIOD*2);//-------------------------WAIT_WVALID--AND--WAIT_RREADY
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
PWRITE <= 1'b0;
PSEL <= 1'b1;
PENABLE <= 1'b1; 
PWDATA <= 32'h77777777;
PADDR <= 32'h55555555;
PSTRB <= 4'b1;
BUSY <= 1'b0;
DATA <= 10'b0000001001;


#(CLKPERIOD*2);//-------------------------WORKING--AND--START_R
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
PWRITE <= 1'b0;
PSEL <= 1'b1;
PENABLE <= 1'b1; 
PWDATA <= 32'h11111111;
PADDR <= 32'h55555555;
PSTRB <= 4'b1;
BUSY <= 1'b0;
DATA <= 10'b0000000001;


//-------------------------START_R--AND--START_W

//----------------------------------NO--reset------------------------

//RST <= 1'b0;

#(CLKPERIOD*2);//-------------------------START_R--AND--START_W
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
PWRITE <= 1'b0;
PSEL <= 1'b1;
PENABLE <= 1'b1; 
PWDATA <= 32'h22222222;
PADDR <= 32'h55555555;
PSTRB <= 4'b1;
BUSY <= 1'b1;
DATA <= 10'b0000011111;


#(CLKPERIOD*9);//-------------------------WAIT_WVALID--AND--WAIT_RREADY
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
PWRITE <= 1'b0;
PSEL <= 1'b1;
PENABLE <= 1'b1; 
PWDATA <= 32'h55555568;
PADDR <= 32'h55555555;
PSTRB <= 4'b1;
BUSY <= 1'b0;
DATA <= 10'b0000000001;


#(CLKPERIOD*9);//-------------------------WORKING--AND--START_R
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
