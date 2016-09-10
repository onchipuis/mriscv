`timescale 1ns/1ns

module axi4_interconnect_tb();

// HELPER
	function integer clogb2;
		input integer value;
		integer 	i;
		begin
			clogb2 = 0;
			for(i = 0; 2**i < value; i = i + 1)
			clogb2 = i + 1;
		end
	endfunction
	
localparam  			masters = 2;
localparam  			slaves = 5;
localparam  			sword = 32;

localparam			impl = 0;
localparam			addressing = 0;

// MEMORY MAP SPEC
localparam [slaves*sword-1:0] addr_mask = {32'h00000000,32'h0000000F,32'h00000001,32'h00000001,32'h000003FF};
localparam [slaves*sword-1:0] addr_use  = {32'h04000000,32'h00000410,32'h00000408,32'h00000400,32'h00000000};

// Autogen localparams

reg 	CLK = 1'b0;
reg	 	RST;

// AXI4-lite master memory interfaces

reg  [masters-1:0]       m_axi_awvalid;
wire [masters-1:0]       m_axi_awready;
wire [masters*sword-1:0] m_axi_awaddr;
wire [masters*3-1:0]     m_axi_awprot;

reg  [masters-1:0]       m_axi_wvalid;
wire [masters-1:0]       m_axi_wready;
wire [masters*sword-1:0] m_axi_wdata;
wire [masters*4-1:0]     m_axi_wstrb;

wire [masters-1:0]       m_axi_bvalid;
reg  [masters-1:0]       m_axi_bready;

reg  [masters-1:0]       m_axi_arvalid;
wire [masters-1:0]       m_axi_arready;
wire [masters*sword-1:0] m_axi_araddr;
wire [masters*3-1:0]     m_axi_arprot;

wire [masters-1:0]       m_axi_rvalid;
reg  [masters-1:0]       m_axi_rready;
wire [masters*sword-1:0] m_axi_rdata;

// AXI4-lite slave memory interfaces

wire [slaves-1:0]       s_axi_awvalid;
reg  [slaves-1:0]       s_axi_awready;
wire [slaves*sword-1:0] s_axi_awaddr;
wire [slaves*3-1:0]     s_axi_awprot;

wire [slaves-1:0]       s_axi_wvalid;
reg  [slaves-1:0]       s_axi_wready;
wire [slaves*sword-1:0] s_axi_wdata;
wire [slaves*4-1:0]     s_axi_wstrb;

reg  [slaves-1:0]       s_axi_bvalid;
wire [slaves-1:0]       s_axi_bready;

wire [slaves-1:0]       s_axi_arvalid;
reg  [slaves-1:0]       s_axi_arready;
wire [slaves*sword-1:0] s_axi_araddr;
wire [slaves*3-1:0]     s_axi_arprot;

reg  [slaves-1:0]       s_axi_rvalid;
wire [slaves-1:0]       s_axi_rready;
wire [slaves*sword-1:0] s_axi_rdata;

// THE CONCENTRATION

reg  [sword-1:0] m_axi_awaddr_o [0:masters-1];
reg  [3-1:0]     m_axi_awprot_o [0:masters-1];
reg  [sword-1:0] m_axi_wdata_o [0:masters-1];
reg  [4-1:0]     m_axi_wstrb_o [0:masters-1];
reg  [sword-1:0] m_axi_araddr_o [0:masters-1];
reg  [3-1:0]     m_axi_arprot_o [0:masters-1];
wire [sword-1:0] m_axi_rdata_o [0:masters-1];
wire [sword-1:0] s_axi_awaddr_o [0:slaves-1];
wire [3-1:0]     s_axi_awprot_o [0:slaves-1];
wire [sword-1:0] s_axi_wdata_o [0:slaves-1];
wire [4-1:0]     s_axi_wstrb_o [0:slaves-1];
wire [sword-1:0] s_axi_araddr_o [0:slaves-1];
wire [3-1:0]     s_axi_arprot_o [0:slaves-1];
reg  [sword-1:0] s_axi_rdata_o [0:slaves-1];

wire  [sword-1:0] addr_mask_o [0:slaves-1];
wire  [sword-1:0] addr_use_o [0:slaves-1];
genvar k;
generate
	for(k = 0; k < masters; k=k+1) begin
		assign m_axi_awaddr[(k+1)*sword-1:k*sword] = m_axi_awaddr_o[k];
		assign m_axi_awprot[(k+1)*3-1:k*3] = m_axi_awprot_o[k];
		assign m_axi_wdata[(k+1)*sword-1:k*sword] = m_axi_wdata_o[k];
		assign m_axi_wstrb[(k+1)*4-1:k*4] = m_axi_wstrb_o[k];
		assign m_axi_araddr[(k+1)*sword-1:k*sword] = m_axi_araddr_o[k];
		assign m_axi_arprot[(k+1)*3-1:k*3] = m_axi_arprot_o[k];
		assign m_axi_rdata_o[k] = m_axi_rdata[(k+1)*sword-1:k*sword];
	end
	for(k = 0; k < slaves; k=k+1) begin
		assign s_axi_awaddr_o[k] = s_axi_awaddr[(k+1)*sword-1:k*sword];
		assign s_axi_awprot_o[k] = s_axi_awprot[(k+1)*3-1:k*3];
		assign s_axi_wdata_o[k] = s_axi_wdata[(k+1)*sword-1:k*sword];
		assign s_axi_wstrb_o[k] = s_axi_wstrb[(k+1)*4-1:k*4];
		assign s_axi_araddr_o[k] = s_axi_araddr[(k+1)*sword-1:k*sword];
		assign s_axi_arprot_o[k] = s_axi_arprot[(k+1)*3-1:k*3];
		assign addr_mask_o[k] = addr_mask[(k+1)*sword-1:k*sword];
		assign addr_use_o[k] = addr_use[(k+1)*sword-1:k*sword];
		assign s_axi_rdata[(k+1)*sword-1:k*sword] = s_axi_rdata_o[k];
	end
endgenerate
	
	integer 	fd1, tmp1, ifstop;
	integer PERIOD = 20 ;
	integer i, j, error, l;
	
	
	axi4_interconnect/* #
	(
	.masters(masters),
	.slaves(slaves),
	.sword(sword),
	.impl(impl),
	.addressing(addressing),
	.addr_mask(addr_mask),
	.addr_use(addr_use)
	) */
	inst_axi4_interconnect
	(
	.CLK		(CLK),
	.RST	(RST),
	.m_axi_awvalid(m_axi_awvalid),
	.m_axi_awready(m_axi_awready),
	.m_axi_awaddr(m_axi_awaddr),
	.m_axi_awprot(m_axi_awprot),
	.m_axi_wvalid(m_axi_wvalid),
	.m_axi_wready(m_axi_wready),
	.m_axi_wdata(m_axi_wdata),
	.m_axi_wstrb(m_axi_wstrb),
	.m_axi_bvalid(m_axi_bvalid),
	.m_axi_bready(m_axi_bready),
	.m_axi_arvalid(m_axi_arvalid),
	.m_axi_arready(m_axi_arready),
	.m_axi_araddr(m_axi_araddr),
	.m_axi_arprot(m_axi_arprot),
	.m_axi_rvalid(m_axi_rvalid),
	.m_axi_rready(m_axi_rready),
	.m_axi_rdata(m_axi_rdata),
	.s_axi_awvalid(s_axi_awvalid),
	.s_axi_awready(s_axi_awready),
	.s_axi_awaddr(s_axi_awaddr),
	.s_axi_awprot(s_axi_awprot),
	.s_axi_wvalid(s_axi_wvalid),
	.s_axi_wready(s_axi_wready),
	.s_axi_wdata(s_axi_wdata),
	.s_axi_wstrb(s_axi_wstrb),
	.s_axi_bvalid(s_axi_bvalid),
	.s_axi_bready(s_axi_bready),
	.s_axi_arvalid(s_axi_arvalid),
	.s_axi_arready(s_axi_arready),
	.s_axi_araddr(s_axi_araddr),
	.s_axi_arprot(s_axi_arprot),
	.s_axi_rvalid(s_axi_rvalid),
	.s_axi_rready(s_axi_rready),
	.s_axi_rdata(s_axi_rdata)
	); 
	
	always
	begin #(PERIOD/2) CLK = ~CLK; end 

	task aexpect;
		input [sword-1:0] av, e;
		begin
		 if (av == e)
			$display ("TIME=%t." , $time, " Actual value of trans=%b, expected is %b. MATCH!", av, e);
		 else
		  begin
			$display ("TIME=%t." , $time, " Actual value of trans=%b, expected is %b. ERROR!", av, e);
			error = error + 1;
		  end
		end
	endtask
	
	reg [63:0] xorshift64_state = 64'd88172645463325252;

	task xorshift64_next;
		begin
			// see page 4 of Marsaglia, George (July 2003). "Xorshift RNGs". Journal of Statistical Software 8 (14).
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 13);
			xorshift64_state = xorshift64_state ^ (xorshift64_state >>  7);
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 17);
		end
	endtask


	initial begin
		$sdf_annotate("axi4_interconnect.sdf",inst_axi4_interconnect);
		fd1 = $fopen ("data.txt","r");
		CLK 	= 1'b1;
		RST 	= 1'b0;
		error = 0;
		m_axi_awvalid = {(masters){1'b0}};
		m_axi_wvalid = {(masters){1'b0}};
		m_axi_bready = {(masters){1'b0}};
		m_axi_arvalid = {(masters){1'b0}};
		m_axi_rready = {(masters){1'b0}};
		s_axi_awready = {(slaves){1'b0}};
		s_axi_wready = {(slaves){1'b0}};
		s_axi_bvalid = {(slaves){1'b0}};
		s_axi_arready = {(slaves){1'b0}};
		s_axi_rvalid = {(slaves){1'b0}};
		for(i = 0; i < masters; i=i+1) begin
			m_axi_awaddr_o[i] = {sword{1'b0}};
			m_axi_awprot_o[i] = {3{1'b0}};
			m_axi_wdata_o[i] = {sword{1'b0}};
			m_axi_wstrb_o[i] = {4{1'b0}};
			m_axi_araddr_o[i] = {sword{1'b0}};
			m_axi_arprot_o[i] = {3{1'b0}};
		end
		for(i = 0; i < slaves; i=i+1) begin
			s_axi_rdata_o[i] = {sword{1'b0}};
		end
		#20	;
		RST 	= 1'b1;
		// READING TEST
		for(i = 0; i < masters; i = i+1) begin
			for(j = 0; j < slaves; j = j+1) begin
				#(PERIOD*8);
				m_axi_arvalid[i] = 1'b1;
				m_axi_araddr_o[i] = addr_use_o[j] | (xorshift64_state[31:0] & addr_mask_o[j]);
				#PERIOD;
				while(!m_axi_arready[i]) begin
					#PERIOD; 
				end
				while(!m_axi_rvalid[i]) begin
					#PERIOD; 
				end
				m_axi_rready[i] = 1'b1;
				$display ("Master: %d, Task: RData", i);
				aexpect(m_axi_rdata_o[i], xorshift64_state[63:32]);
				#PERIOD; 
				m_axi_arvalid[i] = 1'b0;
				m_axi_rready[i] = 1'b0;
				xorshift64_next;
				if(j == 2) begin
					#(PERIOD*6);
					RST = 1'b0;
					#(PERIOD*6);
					RST = 1'b1;
					#(PERIOD*6);
				end
			end
		end
		
		// WRITTING TEST
		for(i = 0; i < masters; i = i+1) begin
			for(j = 0; j < slaves; j = j+1) begin
				#(PERIOD*8);
				m_axi_awvalid[i] = 1'b1;
				m_axi_awaddr_o[i] = addr_use_o[j] | (xorshift64_state[31:0] & addr_mask_o[j]);
				#PERIOD;
				while(!m_axi_awready[i]) begin
					#PERIOD; 
				end
				m_axi_wvalid[i] = 1'b1;
				m_axi_wdata_o[i] = xorshift64_state[63:32];
				while(!m_axi_wready[i]) begin
					#PERIOD; 
				end
				while(!m_axi_bvalid[i]) begin
					#PERIOD; 
				end
				m_axi_bready[i] = 1'b1;
				#PERIOD; 
				m_axi_awvalid[i] = 1'b0;
				m_axi_wvalid[i] = 1'b0;
				m_axi_bready[i] = 1'b0;
				xorshift64_next;
				if(j == 2) begin
					#(PERIOD*6);
					RST = 1'b0;
					#(PERIOD*6);
					RST = 1'b1;
					#(PERIOD*6);
				end
			end
		end
		$timeformat(-9,0,"ns",7);
		#(PERIOD*8) if (error == 0)
					$display("All match");
				else
					$display("Mismatches = %d", error);
		$finish;
	end
	
	always @(posedge CLK) begin
		for(l = 0; l < slaves; l = l+1) begin
			if(s_axi_arvalid[l] && !s_axi_arready[i] && !s_axi_rready[l]) begin
				s_axi_arready[l] = 1'b1;
				s_axi_rvalid[l] = 1'b1;
				s_axi_rdata_o[l] = xorshift64_state[63:32];
				$display ("Slave: %d, Task: RAddr", l);
				aexpect(s_axi_araddr_o[l], addr_use_o[l] | (xorshift64_state[31:0] & addr_mask_o[l]));
			end else if(s_axi_rready[l]) begin
				s_axi_arready[l] = 1'b0;
				s_axi_rvalid[l] = 1'b0;
			end
			
			
			if(s_axi_awvalid[l] && !s_axi_awready[i] && !s_axi_bready[l]) begin
				s_axi_awready[l] = 1'b1;
				$display ("Slave: %d, Task: WAddr", l);
				aexpect(s_axi_awaddr_o[l], addr_use_o[l] | (xorshift64_state[31:0] & addr_mask_o[l]));
			end if(s_axi_wvalid[l] && !s_axi_wready[i] && !s_axi_bready[l]) begin
				s_axi_wready[l] = 1'b1;
				s_axi_bvalid[l] = 1'b1;
				$display ("Slave: %d, Task: WData", l);
				aexpect(s_axi_wdata_o[l], xorshift64_state[63:32]);
			end else if(s_axi_bready[l]) begin
				s_axi_awready[l] = 1'b0;
				s_axi_wready[l] = 1'b0;
				s_axi_bvalid[l] = 1'b0;
			end
		end
	end

endmodule
