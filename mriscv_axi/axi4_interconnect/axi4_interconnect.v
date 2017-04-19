// Created by: CKDUR
`timescale 1ns/1ns

module axi4_interconnect #
	(
	parameter  			masters = 2,
	parameter  			slaves = 5,
	parameter  			sword = 32,

	/*
	IMPLEMENTATION SETTINGS
	impl: 0,Classic  1,Simulation
	addressing: 0,ByTristate  1,ByAGiantMux
	*/
	parameter			impl = 0,
	parameter			addressing = 0,
	
	/*
	ADDRESS MASKING SETTINGS
	You put here the adress mask for each slave
	PLEASE dont letme on zeros or i wont work.

	For each address mask you need to do the address use
	0x00FF <-- This is an address mask
	0x0100 <-- This is an address use
	If the master access the address 0x01XX, refer to this
	slave, otherwise won't be like this
	WARNING Please ensure that all mask-use pairs for all
	slaves are excluyent, because if you use tri-state 
	addressing, there will have problems.
	*/
	parameter [slaves*sword-1:0] addr_mask = {32'h00000000,32'h0000000F,32'h00000001,32'h00000001,32'h000003FF},
	parameter [slaves*sword-1:0] addr_use  = {32'h04000000,32'h00000410,32'h00000408,32'h00000400,32'h00000000}
	)

	(
	input							CLK,
	input							RST,
	
	// AXI4-lite master memory interfaces

	input  [masters-1:0]       m_axi_awvalid,
	output [masters-1:0]       m_axi_awready,
	input  [masters*sword-1:0] m_axi_awaddr,
	input  [masters*3-1:0]     m_axi_awprot,

	input  [masters-1:0]       m_axi_wvalid,
	output [masters-1:0]       m_axi_wready,
	input  [masters*sword-1:0] m_axi_wdata,
	input  [masters*4-1:0]     m_axi_wstrb,

	output [masters-1:0]       m_axi_bvalid,
	input  [masters-1:0]       m_axi_bready,

	input  [masters-1:0]       m_axi_arvalid,
	output [masters-1:0]       m_axi_arready,
	input  [masters*sword-1:0] m_axi_araddr,
	input  [masters*3-1:0]     m_axi_arprot,

	output [masters-1:0]       m_axi_rvalid,
	input  [masters-1:0]       m_axi_rready,
	output [masters*sword-1:0] m_axi_rdata,
	
	// AXI4-lite slave memory interfaces

	output [slaves-1:0]       s_axi_awvalid,
	input  [slaves-1:0]       s_axi_awready,
	output [slaves*sword-1:0] s_axi_awaddr,
	output [slaves*3-1:0]     s_axi_awprot,

	output [slaves-1:0]       s_axi_wvalid,
	input  [slaves-1:0]       s_axi_wready,
	output [slaves*sword-1:0] s_axi_wdata,
	output [slaves*4-1:0]     s_axi_wstrb,

	input  [slaves-1:0]       s_axi_bvalid,
	output [slaves-1:0]       s_axi_bready,

	output [slaves-1:0]       s_axi_arvalid,
	input  [slaves-1:0]       s_axi_arready,
	output [slaves*sword-1:0] s_axi_araddr,
	output [slaves*3-1:0]     s_axi_arprot,

	input  [slaves-1:0]       s_axi_rvalid,
	output [slaves-1:0]       s_axi_rready,
	input  [slaves*sword-1:0] s_axi_rdata
    );
	
	// HELPERS ***********************************************
	function integer clogb2;
		input integer value;
		integer 	i;
		begin
			clogb2 = 0;
			for(i = 0; 2**i < value; i = i + 1)
			clogb2 = i + 1;
		end
	endfunction
	
	genvar i;
	genvar unpk_idx; 
	// ********************************************************
	localparam numbit_masters = clogb2(masters);
	localparam numbit_slaves = clogb2(slaves);
	
	// Masters read requests
	wire [masters-1:0]		rrequests;
	assign rrequests = m_axi_arvalid;	// In readings, is the address valid
	wire [masters-1:0]		wrequests;
	assign wrequests = m_axi_awvalid|m_axi_wvalid;	// In writtings, is the address valid or the write valid (AXI4-spec)
	
	// The master director. This chooses who is going to do the request
	reg [numbit_masters-1:0] counter_rrequests;
	reg [numbit_masters-1:0] counter_wrequests;
	// This comes from fsms for stopping the counters if there is a pendant request
	wire en_rrequests;	// TODO: NOT ASSIGNED ALREADY
	wire en_wrequests;	// TODO: NOT ASSIGNED ALREADY
	always @ (posedge CLK)
	begin
		if (RST == 1'b0)
		begin
			counter_rrequests <= {numbit_masters{1'b0}};		// RESET 
		end else 
		begin
			if (en_rrequests == 1'b0)
			begin
				counter_rrequests <= counter_rrequests;	// NOTHING 
			end else
			begin
				if(counter_rrequests < masters)
					counter_rrequests <= counter_rrequests+1;						// SHIFTING
				else
					counter_rrequests <= 0;
			end
		end
	end
	
	always @ (posedge CLK)
	begin
		if (RST == 1'b0)
		begin
			counter_wrequests <= {numbit_masters{1'b0}};		// RESET 
		end else 
		begin
			if (en_wrequests == 1'b0)
			begin
				counter_wrequests <= counter_wrequests;	// NOTHING 
			end else
			begin
				if(counter_wrequests < masters)
					counter_wrequests <= counter_wrequests+1;						// SHIFTING
				else
					counter_wrequests <= 0;					// SHIFTING
			end
		end
	end
	
	wire [masters-1:0] dec_wrequests;
	assign dec_wrequests = 1 << counter_wrequests;
	wire [masters-1:0] dec_rrequests;
	assign dec_rrequests = 1 << counter_rrequests;
	
	// INTENTION: Send to fsms that there is a request
	wire is_rrequests;	// TODO: NOT USED ALREADY
	assign is_rrequests = |(dec_rrequests&rrequests);
	wire is_wrequests;	// TODO: NOT USED ALREADY
	assign is_wrequests = |(dec_wrequests&wrequests);
	
	// INTENTION: Recv from fsms that the request is complete
	/*wire erase_cur_rrequest;	// TODO: NOT ASSIGNED ALREADY
	wire erase_cur_wrequest;	// TODO: NOT ASSIGNED ALREADY
	wire [masters-1] erase_rrequest;
	assign erase_rrequest = counter_rrequests & {masters{erase_cur_rrequest}};
	wire [masters-1] erase_wrequest;
	assign erase_rrequest = counter_rrequests & {masters{erase_cur_rrequest}};*/
	
	
	// The global addr
	wire [sword-1:0] awaddr;
	wire [sword-1:0] araddr;
	reg [sword-1:0] m_axi_awaddr_g [0:masters-1];
	reg [sword-1:0] m_axi_araddr_g [0:masters-1];
	// Phase 1 - Convert to latched array
	generate 
		for (unpk_idx=0; unpk_idx<(masters); unpk_idx=unpk_idx+1) begin 
			always @(m_axi_awvalid[unpk_idx] or RST or m_axi_awaddr[((sword)*unpk_idx+(sword-1)):((sword)*unpk_idx)]) begin
				if(RST == 1'b0) begin
					m_axi_awaddr_g[unpk_idx] = {sword{1'b0}};
				end else if (m_axi_awvalid[unpk_idx] == 1'b1) begin
					m_axi_awaddr_g[unpk_idx] = m_axi_awaddr[((sword)*unpk_idx+(sword-1)):((sword)*unpk_idx)];
				end
			end
			always @(m_axi_arvalid[unpk_idx] or RST or m_axi_araddr[((sword)*unpk_idx+(sword-1)):((sword)*unpk_idx)]) begin
				if(RST == 1'b0) begin
					m_axi_araddr_g[unpk_idx] = {sword{1'b0}};
				end else if (m_axi_arvalid[unpk_idx] == 1'b1) begin
					m_axi_araddr_g[unpk_idx] = m_axi_araddr[((sword)*unpk_idx+(sword-1)):((sword)*unpk_idx)];
				end
			end
		end 
	endgenerate
	// Phase 2 - Do the addressing
	generate
		if(addressing) begin
			// Giant MUX
			assign awaddr = m_axi_awaddr_g[counter_rrequests];
			assign araddr = m_axi_araddr_g[counter_rrequests];
		end else begin
			// tri-state buff bus
			wire [masters*sword-1:0] trib_wd;
			wire [masters*sword-1:0] trib_rd;
			for (i = 0; i < masters; i = i + 1) begin 
				assign trib_wd[(i+1)*sword - 1:i*sword] = dec_wrequests[i]?m_axi_awaddr_g[i]:{sword{1'bz}};
				assign awaddr = trib_wd[(i+1)*sword - 1:i*sword];
				assign trib_rd[(i+1)*sword - 1:i*sword] = dec_rrequests[i]?m_axi_araddr_g[i]:{sword{1'bz}};
				assign araddr = trib_rd[(i+1)*sword - 1:i*sword];
			end
		end
	endgenerate
	
	// Addr mask-use packing (Easier for us, no repercution into gates)
	wire [sword-1:0] addr_mask_o [0:slaves-1];
	wire [sword-1:0] addr_ruse_o [0:slaves-1];
	wire [sword-1:0] addr_wuse_o [0:slaves-1];
	generate 
		for (unpk_idx=0; unpk_idx<(slaves); unpk_idx=unpk_idx+1) begin 
			assign addr_mask_o[unpk_idx][((sword)-1):0] = addr_mask[((sword)*unpk_idx+(sword-1)):((sword)*unpk_idx)]; 
			assign addr_ruse_o[unpk_idx][((sword)-1):0] = addr_use[((sword)*unpk_idx+(sword-1)):((sword)*unpk_idx)] ^
														  (araddr & ~addr_mask_o[unpk_idx]);  
			assign addr_wuse_o[unpk_idx][((sword)-1):0] = addr_use[((sword)*unpk_idx+(sword-1)):((sword)*unpk_idx)] ^
														  (awaddr & ~addr_mask_o[unpk_idx]); 
		end 
	endgenerate
	
	// Addr decoder (yeah... this is the longest gate-path 
	// because there is a and logic, an encoder an a decoder, f*ck me)
	wire slave_rvalid, slave_wvalid;
	wire [slaves-1:0] slave_rdec1, slave_wdec1;
	// First-generate decoder via addr_mask-use rainbow
	generate 
		for (i=0; i<(slaves); i=i+1) begin 
			assign slave_rdec1[i] = ~(|(addr_ruse_o[i])); 
			assign slave_wdec1[i] = ~(|(addr_wuse_o[i]));
		end 
	endgenerate
	wire [numbit_slaves-1:0] slave_raddr, slave_waddr;
	// Pri-encoder for address
	generate
		if(addressing) begin
			// Giant Encoder
			priencr #(.width(slaves)) priencr_raddrencr(.decode(slave_rdec1),.encode(slave_raddr),.valid(slave_rvalid));
			priencr #(.width(slaves)) priencr_waddrencr(.decode(slave_wdec1),.encode(slave_waddr),.valid(slave_wvalid));
		end else begin	// TODO: This maybe is not necesary
			assign slave_raddr = {numbit_slaves{1'b0}};
			assign slave_waddr = {numbit_slaves{1'b0}};
		end
	endgenerate
	
	// Master-slave end requests
	// The condition for reading is that slave tiggers arvalid and master triggers arready
	// The condition for writting is that slave tiggers bvalid and master triggers bready
	wire slave_arvalid, slave_bvalid;
	generate
		if(addressing) begin
			// Giant MUX 
			assign slave_rvalid = s_axi_rvalid[slave_raddr];
			assign slave_bvalid = s_axi_bvalid[slave_waddr];
		end else begin
			// tri-state buff bus
			wire [slaves-1:0] trib_rvalid;
			wire [slaves-1:0] trib_bvalid;
			for (i = 0; i < slaves; i = i + 1) begin 
				assign trib_rvalid[i] = slave_rdec1[i]?s_axi_rvalid[i]:1'bz;
				assign slave_rvalid = trib_rvalid[i];
				assign trib_bvalid[i] = slave_wdec1[i]?s_axi_bvalid[i]:1'bz;
				assign slave_bvalid = trib_bvalid[i];
			end
		end
	endgenerate
	wire master_rready, master_bready;
	generate
		if(addressing) begin
			// Giant MUX
			assign master_rready = m_axi_rready[counter_rrequests];
			assign master_bready = m_axi_bready[counter_wrequests];
		end else begin
			// tri-state buff bus
			wire [masters-1:0] trib_rready;
			wire [masters-1:0] trib_bready;
			for (i = 0; i < masters; i = i + 1) begin 
				assign trib_rready[i] = dec_rrequests[i]?m_axi_rready[i]:1'bz;
				assign master_rready = trib_rready[i];
				assign trib_bready[i] = dec_wrequests[i]?m_axi_bready[i]:1'bz;
				assign master_bready = trib_bready[i];
			end
		end
	endgenerate
	wire fi_rrequests, fi_wrequests;
	assign fi_rrequests = master_rready & slave_rvalid;
	assign fi_wrequests = master_bready & slave_bvalid;
	
	// Little state machine
	reg rtrans, wtrans;
	always @ (posedge CLK)
	begin
		if (RST == 1'b0)
		begin
			rtrans <= 1'b0;		// RESET 
		end else 
		begin
			if (rtrans == 1'b0) begin
				if(is_rrequests == 1'b1)
				begin
					rtrans <= 1'b1;	// BEGIN TRANSMISSION, GOTO TRANSMITTING
				end 
			end else begin
				if(fi_rrequests == 1'b1)
				begin
					rtrans <= 1'b0;	// FINISHED TRANSMITTING, GOTO INIT
				end 
			end
		end
	end
	always @ (posedge CLK)
	begin
		if (RST == 1'b0)
		begin
			wtrans <= 1'b0;		// RESET 
		end else 
		begin
			if (wtrans == 1'b0) begin
				if(is_wrequests == 1'b1)
				begin
					wtrans <= 1'b1;	// BEGIN TRANSMISSION, GOTO TRANSMITTING
				end 
			end else begin
				if(fi_wrequests == 1'b1)
				begin
					wtrans <= 1'b0;	// FINISHED TRANSMITTING, GOTO INIT
				end 
			end
		end
	end
	assign en_rrequests = ~rtrans & ~is_rrequests;
	assign en_wrequests = ~wtrans & ~is_wrequests;

	// Send the channel 
	// For writting
	// Master-slave dir
	localparam numbit_bus_wms = 1+sword+3+1+sword+4+1;
	wire [numbit_bus_wms-1:0] axi_wms;
	wire [numbit_bus_wms-1:0] axi_wms_o [0:masters-1];
	generate // PACK FIRST
		for (unpk_idx=0; unpk_idx<(masters); unpk_idx=unpk_idx+1) begin 
			assign axi_wms_o[unpk_idx] = {m_axi_awvalid[unpk_idx], 
										  m_axi_awaddr[(unpk_idx+1)*sword-1:unpk_idx*sword], 
										  m_axi_awprot[(unpk_idx+1)*3-1:unpk_idx*3], 
										  m_axi_wvalid[unpk_idx], 
										  m_axi_wdata[(unpk_idx+1)*sword-1:unpk_idx*sword], 
										  m_axi_wstrb[(unpk_idx+1)*4-1:unpk_idx*4], 
										  m_axi_bready[unpk_idx]};
		end 
	endgenerate
	generate // DO ADDRESSING
		if(addressing) begin
			// Giant MUX
			assign axi_wms = axi_wms_o[counter_wrequests];
		end else begin
			// tri-state buff bus
			wire [numbit_bus_wms-1:0] trib_axi_wms [0:masters-1];
			for (i = 0; i < masters; i = i + 1) begin 
				assign trib_axi_wms[i] = dec_wrequests[i]?axi_wms_o[i]:{numbit_bus_wms{1'bz}};
				assign axi_wms = trib_axi_wms[i];
			end
		end
	endgenerate
	generate // UNPACK AND SEND TO SLAVES
		for (unpk_idx=0; unpk_idx<(slaves); unpk_idx=unpk_idx+1) begin 
			assign {s_axi_awvalid[unpk_idx], 
				    s_axi_awaddr[(unpk_idx+1)*sword-1:unpk_idx*sword], 
				    s_axi_awprot[(unpk_idx+1)*3-1:unpk_idx*3], 
				    s_axi_wvalid[unpk_idx], 
				    s_axi_wdata[(unpk_idx+1)*sword-1:unpk_idx*sword], 
				    s_axi_wstrb[(unpk_idx+1)*4-1:unpk_idx*4], 
				    s_axi_bready[unpk_idx]} = axi_wms & {numbit_bus_wms{slave_wdec1[unpk_idx] & wtrans}};
				    // TODO: This assignment is LAZY. This will waste ANDs
				    // but, as for we need this urgent... well.. this
				    // We only need "and" the control messages
		end 
	endgenerate
	// Slave-master dir
	localparam numbit_bus_wsm = 1+1+1;
	wire [numbit_bus_wsm-1:0] axi_wsm;
	wire [numbit_bus_wsm-1:0] axi_wsm_o [0:slaves-1];
	generate // PACK FIRST
		for (unpk_idx=0; unpk_idx<(slaves); unpk_idx=unpk_idx+1) begin 
			assign axi_wsm_o[unpk_idx] = {s_axi_awready[unpk_idx], 
										  s_axi_wready[unpk_idx], 
										  s_axi_bvalid[unpk_idx]};
		end 
	endgenerate
	generate // DO ADDRESSING
		if(addressing) begin
			// Giant MUX
			assign axi_wsm = axi_wsm_o[slave_waddr];
		end else begin
			// tri-state buff bus
			wire [numbit_bus_wsm-1:0] trib_axi_wsm [0:slaves-1];
			for (i = 0; i < slaves; i = i + 1) begin 
				assign trib_axi_wsm[i] = slave_wdec1[i]?axi_wsm_o[i]:{numbit_bus_wsm{1'bz}};
				assign axi_wsm = trib_axi_wsm[i];
			end
		end
	endgenerate
	generate // UNPACK AND SEND TO MASTERS
		for (unpk_idx=0; unpk_idx<(masters); unpk_idx=unpk_idx+1) begin 
			assign {m_axi_awready[unpk_idx],  
				    m_axi_wready[unpk_idx], 
				    m_axi_bvalid[unpk_idx]} = axi_wsm & {numbit_bus_wsm{dec_wrequests[unpk_idx] & wtrans}};
				    // TODO: This assignment is LAZY. This will waste ANDs
				    // but, as for we need this urgent... well.. this
				    // We only need "and" the control messages
		end 
	endgenerate
	// For reading
	// Master-Slave dir
	localparam numbit_bus_rms = 1+sword+3+1;
	wire [numbit_bus_rms-1:0] axi_rms;
	wire [numbit_bus_rms-1:0] axi_rms_o [0:masters-1];
	generate // PACK FIRST
		for (unpk_idx=0; unpk_idx<(masters); unpk_idx=unpk_idx+1) begin 
			assign axi_rms_o[unpk_idx] = {m_axi_arvalid[unpk_idx], 
										  m_axi_araddr[(unpk_idx+1)*sword-1:unpk_idx*sword], 
										  m_axi_arprot[(unpk_idx+1)*3-1:unpk_idx*3], 
										  m_axi_rready[unpk_idx]};
		end 
	endgenerate
	generate // DO ADDRESSING
		if(addressing) begin
			// Giant MUX
			assign axi_rms = axi_rms_o[counter_rrequests];
		end else begin
			// tri-state buff bus
			wire [numbit_bus_rms-1:0] trib_axi_rms [0:masters-1];
			for (i = 0; i < masters; i = i + 1) begin 
				assign trib_axi_rms[i] = dec_rrequests[i]?axi_rms_o[i]:{numbit_bus_rms{1'bz}};
				assign axi_rms = trib_axi_rms[i];
			end
		end
	endgenerate
	generate // UNPACK AND SEND TO SLAVES
		for (unpk_idx=0; unpk_idx<(slaves); unpk_idx=unpk_idx+1) begin 
			assign {s_axi_arvalid[unpk_idx], 
				    s_axi_araddr[(unpk_idx+1)*sword-1:unpk_idx*sword], 
				    s_axi_arprot[(unpk_idx+1)*3-1:unpk_idx*3], 
				    s_axi_rready[unpk_idx]} = axi_rms & {numbit_bus_rms{slave_rdec1[unpk_idx] & rtrans}};
				    // TODO: This assignment is LAZY. This will waste ANDs
				    // but, as for we need this urgent... well.. this
				    // We only need "and" the control messages
		end 
	endgenerate
	// Slave-master dir
	localparam numbit_bus_rsm = 1+sword+1;
	wire [numbit_bus_rsm-1:0] axi_rsm;
	wire [numbit_bus_rsm-1:0] axi_rsm_o [0:slaves-1];
	generate // PACK FIRST
		for (unpk_idx=0; unpk_idx<(slaves); unpk_idx=unpk_idx+1) begin 

			assign axi_rsm_o[unpk_idx] = {s_axi_arready[unpk_idx], 
										  s_axi_rdata[(unpk_idx+1)*sword-1:unpk_idx*sword], 
										  s_axi_rvalid[unpk_idx]};
		end 
	endgenerate
	generate // DO ADDRESSING
		if(addressing) begin
			// Giant MUX
			assign axi_rsm = axi_rsm_o[slave_raddr];
		end else begin
			// tri-state buff bus
			wire [numbit_bus_rsm-1:0] trib_axi_rsm [0:slaves-1];
			for (i = 0; i < slaves; i = i + 1) begin 
				assign trib_axi_rsm[i] = slave_rdec1[i]?axi_rsm_o[i]:{numbit_bus_rsm{1'bz}};
				assign axi_rsm = trib_axi_rsm[i];
			end
		end
	endgenerate
	generate // UNPACK AND SEND TO MASTERS
		for (unpk_idx=0; unpk_idx<(masters); unpk_idx=unpk_idx+1) begin 
			assign {m_axi_arready[unpk_idx],  
				    m_axi_rdata[(unpk_idx+1)*sword-1:unpk_idx*sword], 
				    m_axi_rvalid[unpk_idx]} = axi_rsm & {numbit_bus_rsm{dec_rrequests[unpk_idx] & rtrans}};
				    // TODO: This assignment is LAZY. This will waste ANDs
				    // but, as for we need this urgent... well.. this
				    // We only need "and" the control messages
		end 
	endgenerate

endmodule
