`timescale 1ns/1ns

module impl_axi(
    // General
    input             CLK,
    input             RST,
    // Master 1 (picorv32_axi), trap
    output            trap,
    // Master 2 (spi_axi_master), SPI Slave Interface
    input             spi_axi_master_CEB, 
    input             spi_axi_master_SCLK, 
    input             spi_axi_master_DATA, 
    output             spi_axi_master_DOUT,
    // Slave 1 (AXI_SP32B1024), NOTHING
    // Slave 2 (DAC_interface_AXI), DAC Interface
    output [11:0]     DAC_interface_AXI_DATA,
    // Slave 3 (ADC_interface_AXI), ADC Interface
    input             ADC_interface_AXI_BUSY,
    input  [9:0]     ADC_interface_AXI_DATA,
    // Slave 4 (completogpio), GPIO Control Pins
    input  [7:0]     completogpio_pindata,
    output [7:0]     completogpio_Rx,
    output [7:0]     completogpio_Tx,
    output [7:0]     completogpio_datanw,
    output [7:0]     completogpio_DSE,
    // Slave 5 (spi_axi_slave), SPI Master Interface
    output             spi_axi_slave_CEB, 
    output             spi_axi_slave_SCLK, 
    output             spi_axi_slave_DATA
    );
    
    // Internals
    // Picorv RST
    wire PICORV_RST;
    
    // ALL-AXI and its distribution
    // MEMORY MAP SPEC
    localparam                sword = 32;
    localparam              masters = 2;
    localparam              slaves = 5;
    localparam [slaves*sword-1:0] addr_mask = {32'h00000000,32'h0000000F,32'h00000001,32'h00000001,32'h000003FF};
    localparam [slaves*sword-1:0] addr_use  = {32'h04000000,32'h00000410,32'h00000408,32'h00000400,32'h00000000};
    
    // AXI4-lite master memory interfaces

    wire [masters-1:0]       m_axi_awvalid;
    wire [masters-1:0]       m_axi_awready;
    wire [masters*sword-1:0] m_axi_awaddr;
    wire [masters*3-1:0]     m_axi_awprot;

    wire [masters-1:0]       m_axi_wvalid;
    wire [masters-1:0]       m_axi_wready;
    wire [masters*sword-1:0] m_axi_wdata;
    wire [masters*4-1:0]     m_axi_wstrb;

    wire [masters-1:0]       m_axi_bvalid;
    wire [masters-1:0]       m_axi_bready;

    wire [masters-1:0]       m_axi_arvalid;
    wire [masters-1:0]       m_axi_arready;
    wire [masters*sword-1:0] m_axi_araddr;
    wire [masters*3-1:0]     m_axi_arprot;

    wire [masters-1:0]       m_axi_rvalid;
    wire [masters-1:0]       m_axi_rready;
    wire [masters*sword-1:0] m_axi_rdata;

    // AXI4-lite slave memory interfaces

    wire [slaves-1:0]       s_axi_awvalid;
    wire [slaves-1:0]       s_axi_awready;
    wire [slaves*sword-1:0] s_axi_awaddr;
    wire [slaves*3-1:0]     s_axi_awprot;

    wire [slaves-1:0]       s_axi_wvalid;
    wire [slaves-1:0]       s_axi_wready;
    wire [slaves*sword-1:0] s_axi_wdata;
    wire [slaves*4-1:0]     s_axi_wstrb;

    wire [slaves-1:0]       s_axi_bvalid;
    wire [slaves-1:0]       s_axi_bready;

    wire [slaves-1:0]       s_axi_arvalid;
    wire [slaves-1:0]       s_axi_arready;
    wire [slaves*sword-1:0] s_axi_araddr;
    wire [slaves*3-1:0]     s_axi_arprot;

    wire [slaves-1:0]       s_axi_rvalid;
    wire [slaves-1:0]       s_axi_rready;
    wire [slaves*sword-1:0] s_axi_rdata;

    // THE CONCENTRATION

    wire [sword-1:0] m_axi_awaddr_o [0:masters-1];
    wire [3-1:0]     m_axi_awprot_o [0:masters-1];
    wire [sword-1:0] m_axi_wdata_o [0:masters-1];
    wire [4-1:0]     m_axi_wstrb_o [0:masters-1];
    wire [sword-1:0] m_axi_araddr_o [0:masters-1];
    wire [3-1:0]     m_axi_arprot_o [0:masters-1];
    wire [sword-1:0] m_axi_rdata_o [0:masters-1];
    wire [sword-1:0] s_axi_awaddr_o [0:slaves-1];
    wire [3-1:0]     s_axi_awprot_o [0:slaves-1];
    wire [sword-1:0] s_axi_wdata_o [0:slaves-1];
    wire [4-1:0]     s_axi_wstrb_o [0:slaves-1];
    wire [sword-1:0] s_axi_araddr_o [0:slaves-1];
    wire [3-1:0]     s_axi_arprot_o [0:slaves-1];
    wire [sword-1:0] s_axi_rdata_o [0:slaves-1];

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
    
    // Slave 1 (AXI_SP32B1024), Memory Interface
    wire  [31:0]     AXI_SP32B1024_D;
    wire  [31:0]     AXI_SP32B1024_Q;
    wire  [9:0]      AXI_SP32B1024_A;
    wire             AXI_SP32B1024_CEN;
    wire             AXI_SP32B1024_WEN;
    
    // Instances
    
    // AXI INTERCONNECT, axi4_interconnect
    axi4_interconnect inst_axi4_interconnect
    (
        .CLK        (CLK),
        .RST    (RST),
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
    
    // Master 1, processor
    // For everyone in this vast processor world, address increments in 4-terms
    // For us, only increment one
    // This is a fix for this issue (as expresed on the testbench)
    // This is a little workaround for the RAM
    wire [31:0] mriscvcore_awaddr; assign m_axi_awaddr_o[0] = {2'b00, mriscvcore_awaddr[31:2]};
    wire [31:0] mriscvcore_araddr; assign m_axi_araddr_o[0] = {2'b00, mriscvcore_araddr[31:2]};
    mriscvcore mriscvcore_inst (
        .clk    (CLK            ),
        .rstn   (PICORV_RST         ),
        .trap   (trap           ),
        .AWvalid(m_axi_awvalid[0]),
        .AWready(m_axi_awready[0]),
        .AWdata (mriscvcore_awaddr),
        .AWprot (m_axi_awprot_o[0]),
        .Wvalid (m_axi_wvalid[0]),
        .Wready (m_axi_wready[0]),
        .Wdata  (m_axi_wdata_o[0]),
        .Wstrb  (m_axi_wstrb_o[0]),
        .Bvalid (m_axi_bvalid[0]),
        .Bready (m_axi_bready[0]),
        .ARvalid(m_axi_arvalid[0]),
        .ARready(m_axi_arready[0]),
        .ARdata (mriscvcore_araddr),
        .ARprot (m_axi_arprot_o[0]),
        .Rvalid (m_axi_rvalid[0]),
        .RReady (m_axi_rready[0]),
        .Rdata  (m_axi_rdata_o[0]),
        //.outirr (irq            ),
        .inirr  (32'd0          )
    );
    
    // Master 2, spi_axi_master
    spi_axi_master inst_spi_axi_master
    (
        .CEB(spi_axi_master_CEB), 
        .SCLK(spi_axi_master_SCLK), 
        .DATA(spi_axi_master_DATA), 
        .DOUT(spi_axi_master_DOUT), 
        .RST(RST), 
        .PICORV_RST(PICORV_RST), 
        .CLK(CLK), 
        .axi_awvalid(m_axi_awvalid[1]), 
        .axi_awready(m_axi_awready[1]), 
        .axi_awaddr(m_axi_awaddr_o[1]), 
        .axi_awprot(m_axi_awprot_o[1]), 
        .axi_wvalid(m_axi_wvalid[1]),
        .axi_wready(m_axi_wready[1]), 
        .axi_wdata(m_axi_wdata_o[1]), 
        .axi_wstrb(m_axi_wstrb_o[1]), 
        .axi_bvalid(m_axi_bvalid[1]), 
        .axi_bready(m_axi_bready[1]),
        .axi_arvalid(m_axi_arvalid[1]), 
        .axi_arready(m_axi_arready[1]), 
        .axi_araddr(m_axi_araddr_o[1]), 
        .axi_arprot(m_axi_arprot_o[1]), 
        .axi_rvalid(m_axi_rvalid[1]),
        .axi_rready(m_axi_rready[1]), 
        .axi_rdata(m_axi_rdata_o[1])
    );
    
    // Slave 1, AXI_SP32B1024
    AXI_SP32B1024 inst_AXI_SP32B1024(
        .CLK(CLK),
        .RST(RST),
        .axi_awvalid(s_axi_awvalid[0]),
        .axi_awready(s_axi_awready[0]),
        .axi_awaddr(s_axi_awaddr_o[0]),
        .axi_awprot(s_axi_awprot_o[0]),
        .axi_wvalid(s_axi_wvalid[0]),
        .axi_wready(s_axi_wready[0]),
        .axi_wdata(s_axi_wdata_o[0]),
        .axi_wstrb(s_axi_wstrb_o[0]),
        .axi_bvalid(s_axi_bvalid[0]),
        .axi_bready(s_axi_bready[0]),
        .axi_arvalid(s_axi_arvalid[0]),
        .axi_arready(s_axi_arready[0]),
        .axi_araddr(s_axi_araddr_o[0]),
        .axi_arprot(s_axi_arprot_o[0]),
        .axi_rvalid(s_axi_rvalid[0]),
        .axi_rready(s_axi_rready[0]),
        .axi_rdata(s_axi_rdata_o[0]),
        .Q(AXI_SP32B1024_Q),
        .CEN(AXI_SP32B1024_CEN),
        .WEN(AXI_SP32B1024_WEN),
        .A(AXI_SP32B1024_A),
        .D(AXI_SP32B1024_D)
    );
    // THIS IS A STANDARD CELL! YOU IDIOT!
    SP32B1024 SP32B1024_INT(
    .Q        (AXI_SP32B1024_Q),
    .CLK      (CLK),
    .CEN      (AXI_SP32B1024_CEN),
    .WEN      (AXI_SP32B1024_WEN),
    .A        (AXI_SP32B1024_A),
    .D        (AXI_SP32B1024_D)
    );
    
    // Slave 2, DAC_interface_AXI
    DAC_interface_AXI inst_DAC_interface_AXI(
        .CLK(CLK),
        .RST(RST),
        .AWVALID(s_axi_awvalid[1]),
        .WVALID(s_axi_wvalid[1]),
        .BREADY(s_axi_bready[1]),
        .AWADDR(s_axi_awaddr_o[1]),
        .WDATA(s_axi_wdata_o[1]),
        .WSTRB(s_axi_wstrb_o[1]),
        .AWREADY(s_axi_awready[1]),
        .WREADY(s_axi_wready[1]),
        .BVALID(s_axi_bvalid[1]),
        .ARVALID(s_axi_arvalid[1]),
        .RREADY(s_axi_rready[1]),
        .ARREADY(s_axi_arready[1]),
        .RVALID(s_axi_rvalid[1]),
        .RDATA(s_axi_rdata_o[1]),
        .DATA(DAC_interface_AXI_DATA)
    );
    
    //Slave 3, ADC_interface_AXI
    ADC_interface_AXI inst_ADC_interface_AXI(
        .CLK(CLK),
        .RST(RST),
        .AWVALID(s_axi_awvalid[2]),
        .WVALID(s_axi_wvalid[2]),
        .BREADY(s_axi_bready[2]),
        .AWADDR(s_axi_awaddr_o[2]),
        .WDATA(s_axi_wdata_o[2]),
        .WSTRB(s_axi_wstrb_o[2]),
        .AWREADY(s_axi_awready[2]),
        .WREADY(s_axi_wready[2]),
        .BVALID(s_axi_bvalid[2]),
        .ARADDR(s_axi_araddr_o[2]),
        .ARVALID(s_axi_arvalid[2]),
        .RREADY(s_axi_rready[2]),
        .ARREADY(s_axi_arready[2]),
        .RVALID(s_axi_rvalid[2]),
        .RDATA(s_axi_rdata_o[2]),
        .DATA(ADC_interface_AXI_DATA),
        .BUSY(ADC_interface_AXI_BUSY)
    );
    
    //Slave 4, completogpio
    completogpio inst_completogpio(
        .clock(CLK),
        .reset(RST),
        .WAddress(s_axi_awaddr_o[3]),
        .Wdata(s_axi_wdata_o[3]),
        .Rdata(s_axi_rdata_o[3]),
        .AWvalid(s_axi_awvalid[3]),
        .RAddress(s_axi_araddr_o[3]),
        .Wvalid(s_axi_wvalid[3]),
        .ARvalid(s_axi_arvalid[3]),
        .Rready(s_axi_rready[3]),
        .Bready(s_axi_bready[3]),
        .ARready(s_axi_arready[3]),
        .Rvalid(s_axi_rvalid[3]),
        .AWready(s_axi_awready[3]),
        .Wready(s_axi_wready[3]),
        .Bvalid(s_axi_bvalid[3]),
        .pindata(completogpio_pindata),
        .Rx(completogpio_Rx),
        .datanw(completogpio_datanw),
        .Tx(completogpio_Tx),
        .DSE(completogpio_DSE)
    );
    
    // Slave 5, spi_axi_slave
    spi_axi_slave inst_spi_axi_slave
    (
        .CEB(spi_axi_slave_CEB), 
        .SCLK(spi_axi_slave_SCLK), 
        .DATA(spi_axi_slave_DATA), 
        .RST(RST), 
        .CLK(CLK), 
        .axi_awvalid(s_axi_awvalid[4]), 
        .axi_awready(s_axi_awready[4]), 
        .axi_awaddr(s_axi_awaddr_o[4]), 
        .axi_awprot(s_axi_awprot_o[4]), 
        .axi_wvalid(s_axi_wvalid[4]),
        .axi_wready(s_axi_wready[4]), 
        .axi_wdata(s_axi_wdata_o[4]), 
        .axi_wstrb(s_axi_wstrb_o[4]), 
        .axi_bvalid(s_axi_bvalid[4]), 
        .axi_bready(s_axi_bready[4]),
        .axi_arvalid(s_axi_arvalid[4]), 
        .axi_arready(s_axi_arready[4]), 
        .axi_araddr(s_axi_araddr_o[4]), 
        .axi_arprot(s_axi_arprot_o[4]), 
        .axi_rvalid(s_axi_rvalid[4]),
        .axi_rready(s_axi_rready[4]), 
        .axi_rdata(s_axi_rdata_o[4])
    );
    
endmodule
