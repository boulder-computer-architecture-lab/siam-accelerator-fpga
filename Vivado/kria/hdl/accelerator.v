`timescale 1ns / 1ps

module accelerator #(
    parameter ARCH_TYPE          = 0,
    parameter PROFILE            = 1,
    parameter AXI_RAM_BASE_ADDR  = 64'h8000_0000,
    
    parameter DATA_WIDTH         = 128,
    parameter ADDR_WIDTH         = 64,
    parameter ID_WIDTH           = 8,

    parameter ELEMENT_WIDTH      = 16,
    parameter ELEMENTS_PER_ROW   = 17048,
    parameter NUM_ROWS           = 17048,
    parameter NUM_CHANNELS       = 4,

    parameter AXI_RAM_DATA_WIDTH = 256,

    // Profiler
    parameter AXIL_ADDR_WIDTH = 12,
    parameter AXIL_DATA_WIDTH = 32
)(

    input  wire                  clk,
    input  wire                  rstn,

    // Input streams
    input  wire [DATA_WIDTH-1:0] s_axis_a_0_tdata,
    input  wire                  s_axis_a_0_tvalid,
    output wire                  s_axis_a_0_tready,
    input  wire                  s_axis_a_0_tlast,
    
    input  wire [DATA_WIDTH-1:0] s_axis_a_1_tdata,
    input  wire                  s_axis_a_1_tvalid,
    output wire                  s_axis_a_1_tready,
    input  wire                  s_axis_a_1_tlast,

    input  wire [DATA_WIDTH-1:0] s_axis_a_2_tdata,
    input  wire                  s_axis_a_2_tvalid,
    output wire                  s_axis_a_2_tready,
    input  wire                  s_axis_a_2_tlast,
    
    input  wire [DATA_WIDTH-1:0] s_axis_a_3_tdata,
    input  wire                  s_axis_a_3_tvalid,
    output wire                  s_axis_a_3_tready,
    input  wire                  s_axis_a_3_tlast,

    // Output streams
    output wire [ELEMENT_WIDTH-1:0] m_axis_0_tdata,
    output wire                     m_axis_0_tvalid,
    input  wire                     m_axis_0_tready,
    output wire                     m_axis_0_tlast,
    
    output wire [ELEMENT_WIDTH-1:0] m_axis_1_tdata,
    output wire                     m_axis_1_tvalid,
    input  wire                     m_axis_1_tready,
    output wire                     m_axis_1_tlast,
    
    output wire [ELEMENT_WIDTH-1:0] m_axis_2_tdata,
    output wire                     m_axis_2_tvalid,
    input  wire                     m_axis_2_tready,
    output wire                     m_axis_2_tlast,

    output wire [ELEMENT_WIDTH-1:0] m_axis_3_tdata,
    output wire                     m_axis_3_tvalid,
    input  wire                     m_axis_3_tready,
    output wire                     m_axis_3_tlast,

    // S-AXI interface for writing vector b
    input  wire [ID_WIDTH-1:0]   s_axi_b_awid,
    input  wire [ADDR_WIDTH-1:0] s_axi_b_awaddr,
    input  wire [7:0]            s_axi_b_awlen,
    input  wire [2:0]            s_axi_b_awsize,
    input  wire [1:0]            s_axi_b_awburst,
    input  wire                  s_axi_b_awlock,
    input  wire [3:0]            s_axi_b_awcache,
    input  wire [2:0]            s_axi_b_awprot,
    input  wire                  s_axi_b_awvalid,
    output wire                  s_axi_b_awready,
    
    input  wire [AXI_RAM_DATA_WIDTH-1:0]     s_axi_b_wdata,
    input  wire [(AXI_RAM_DATA_WIDTH/8)-1:0] s_axi_b_wstrb,
    input  wire                              s_axi_b_wlast,
    input  wire                              s_axi_b_wvalid,
    output wire                              s_axi_b_wready,
    
    output wire [ID_WIDTH-1:0] s_axi_b_bid,
    output wire [1:0]          s_axi_b_bresp,
    output wire                s_axi_b_bvalid,
    input  wire                s_axi_b_bready,

    // S-AXIL interface for profiling 
    // (can leave unconnected if PROFILE = 0)
    input  wire                       s_axil_aclk,
    input  wire                       s_axil_aresetn,

    input  wire [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr,
    input  wire                       s_axil_awvalid,
    output wire                       s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0] s_axil_wdata,
    input  wire                       s_axil_wvalid,
    output wire                       s_axil_wready,
    output wire [1:0]                 s_axil_bresp,
    output wire                       s_axil_bvalid,
    input  wire                       s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0] s_axil_araddr,
    input  wire                       s_axil_arvalid,
    output wire                       s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0] s_axil_rdata,
    output wire [1:0]                 s_axil_rresp,
    output wire                       s_axil_rvalid,
    input  wire                       s_axil_rready
);

    localparam NUM_RAM_PARTITIONS = NUM_CHANNELS;
    localparam STRB_WIDTH         = DATA_WIDTH / 8;
    localparam ELEMENTS_PER_WORD  = DATA_WIDTH / ELEMENT_WIDTH;
    localparam WORDS_PER_ROW      = ELEMENTS_PER_ROW / ELEMENTS_PER_WORD;
    localparam ROWS_PER_CHANNEL   = NUM_ROWS / NUM_CHANNELS;

    // =============================================================
    //                      PACK CHANNELS
    // =============================================================
    
    localparam MAX_CH = 4;

    // Input stream arrays
    wire [DATA_WIDTH*MAX_CH-1:0] s_axis_a_tdata;
    wire [MAX_CH-1:0]            s_axis_a_tvalid;
    wire [MAX_CH-1:0]            s_axis_a_tready;
    wire [MAX_CH-1:0]            s_axis_a_tlast;
    
    assign s_axis_a_tdata[DATA_WIDTH*0 +: DATA_WIDTH] = s_axis_a_0_tdata;
    assign s_axis_a_tdata[DATA_WIDTH*1 +: DATA_WIDTH] = s_axis_a_1_tdata;
    assign s_axis_a_tdata[DATA_WIDTH*2 +: DATA_WIDTH] = s_axis_a_2_tdata;
    assign s_axis_a_tdata[DATA_WIDTH*3 +: DATA_WIDTH] = s_axis_a_3_tdata;

    assign s_axis_a_tvalid[0] = s_axis_a_0_tvalid;
    assign s_axis_a_tvalid[1] = s_axis_a_1_tvalid;
    assign s_axis_a_tvalid[2] = s_axis_a_2_tvalid;
    assign s_axis_a_tvalid[3] = s_axis_a_3_tvalid;

    assign s_axis_a_0_tready  = s_axis_a_tready[0];
    assign s_axis_a_1_tready  = s_axis_a_tready[1];
    assign s_axis_a_2_tready  = s_axis_a_tready[2];
    assign s_axis_a_3_tready  = s_axis_a_tready[3];

    assign s_axis_a_tlast[0]  = s_axis_a_0_tlast;
    assign s_axis_a_tlast[1]  = s_axis_a_1_tlast;
    assign s_axis_a_tlast[2]  = s_axis_a_2_tlast;
    assign s_axis_a_tlast[3]  = s_axis_a_3_tlast;

    // Output stream arrays
    wire [ELEMENT_WIDTH*MAX_CH-1:0] m_axis_tdata;
    wire [MAX_CH-1:0]               m_axis_tvalid;
    wire [MAX_CH-1:0]               m_axis_tready;
    wire [MAX_CH-1:0]               m_axis_tlast;

    assign m_axis_0_tdata   = m_axis_tdata[ELEMENT_WIDTH*0 +: ELEMENT_WIDTH];
    assign m_axis_1_tdata   = m_axis_tdata[ELEMENT_WIDTH*1 +: ELEMENT_WIDTH];
    assign m_axis_2_tdata   = m_axis_tdata[ELEMENT_WIDTH*2 +: ELEMENT_WIDTH];
    assign m_axis_3_tdata   = m_axis_tdata[ELEMENT_WIDTH*3 +: ELEMENT_WIDTH];
    
    assign m_axis_0_tvalid  = m_axis_tvalid[0];
    assign m_axis_1_tvalid  = m_axis_tvalid[1];
    assign m_axis_2_tvalid  = m_axis_tvalid[2];
    assign m_axis_3_tvalid  = m_axis_tvalid[3];
    
    assign m_axis_tready[0] = m_axis_0_tready;
    assign m_axis_tready[1] = m_axis_1_tready;
    assign m_axis_tready[2] = m_axis_2_tready;
    assign m_axis_tready[3] = m_axis_3_tready;
    
    assign m_axis_0_tlast   = m_axis_tlast[0];
    assign m_axis_1_tlast   = m_axis_tlast[1];
    assign m_axis_2_tlast   = m_axis_tlast[2];
    assign m_axis_3_tlast   = m_axis_tlast[3];
    
    // =============================================================
    //                         INSTANCES
    // =============================================================
    
    generate
        if (PROFILE) begin

            localparam BEATS_PER_PACKET = WORDS_PER_ROW * ROWS_PER_CHANNEL;

            axis_dma_profiler #(
                .NUM_DMAS(NUM_CHANNELS),

                .AXIS_S_DATA_WIDTH(DATA_WIDTH),
                .AXIS_M_DATA_WIDTH(ELEMENT_WIDTH),

                .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
                .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),

                .USE_BPP_CNT(1),
                .BEATS_PER_PACKET(BEATS_PER_PACKET)
            ) prof (
                .axis_clk       (clk),
                .axis_aresetn   (rstn),
                .s_tvalid_v     (s_axis_a_tvalid),
                .s_tready_v     (s_axis_a_tready),
                .s_tlast_v      (s_axis_a_tlast),
                .m_tvalid_v     (m_axis_tvalid),
                .m_tready_v     (m_axis_tready),
                .m_tlast_v      (m_axis_tlast),

                .s_axil_aclk    (s_axil_aclk),
                .s_axil_aresetn (s_axil_aresetn),
                .s_axil_awaddr  (s_axil_awaddr),
                .s_axil_awvalid (s_axil_awvalid),
                .s_axil_awready (s_axil_awready),
                .s_axil_wdata   (s_axil_wdata),
                .s_axil_wvalid  (s_axil_wvalid),
                .s_axil_wready  (s_axil_wready),
                .s_axil_bresp   (s_axil_bresp),
                .s_axil_bvalid  (s_axil_bvalid),
                .s_axil_bready  (s_axil_bready),
                .s_axil_araddr  (s_axil_araddr),
                .s_axil_arvalid (s_axil_arvalid),
                .s_axil_arready (s_axil_arready),
                .s_axil_rdata   (s_axil_rdata),
                .s_axil_rresp   (s_axil_rresp),
                .s_axil_rvalid  (s_axil_rvalid),
                .s_axil_rready  (s_axil_rready)
            );
        end

        if (ARCH_TYPE == 0) begin
            mvm_base #(
                .DATA_WIDTH         (DATA_WIDTH),
                .ADDR_WIDTH         (ADDR_WIDTH),
                .STRB_WIDTH         (STRB_WIDTH),
                .ID_WIDTH           (ID_WIDTH),
                .ELEMENT_WIDTH      (ELEMENT_WIDTH),
                .ELEMENTS_PER_WORD  (ELEMENTS_PER_WORD),
                .ELEMENTS_PER_ROW   (ELEMENTS_PER_ROW),
                .WORDS_PER_ROW      (WORDS_PER_ROW),
                .NUM_ROWS           (NUM_ROWS),
                .NUM_CHANNELS       (NUM_CHANNELS),
                .NUM_RAM_PARTITIONS (NUM_RAM_PARTITIONS),
                .ROWS_PER_CHANNEL   (ROWS_PER_CHANNEL),
                .AXI_RAM_DATA_WIDTH (AXI_RAM_DATA_WIDTH),
                .AXI_RAM_BASE_ADDR  (AXI_RAM_BASE_ADDR)
            ) mvm (
                .clk(clk),
                .rstn(rstn),
                
                // Input channels
                .s_axis_a_tdata (s_axis_a_tdata),
                .s_axis_a_tvalid(s_axis_a_tvalid),
                .s_axis_a_tready(s_axis_a_tready),
                .s_axis_a_tlast (s_axis_a_tlast),
            
                // Output channels
                .m_axis_tdata (m_axis_tdata),
                .m_axis_tvalid(m_axis_tvalid),
                .m_axis_tready(m_axis_tready),
                .m_axis_tlast (m_axis_tlast),
            
                // AXI slave interface
                .s_axi_b_awid   (s_axi_b_awid),
                .s_axi_b_awaddr (s_axi_b_awaddr),
                .s_axi_b_awlen  (s_axi_b_awlen),
                .s_axi_b_awsize (s_axi_b_awsize),
                .s_axi_b_awburst(s_axi_b_awburst),
                .s_axi_b_awlock (s_axi_b_awlock),
                .s_axi_b_awcache(s_axi_b_awcache),
                .s_axi_b_awprot (s_axi_b_awprot),
                .s_axi_b_awvalid(s_axi_b_awvalid),
                .s_axi_b_awready(s_axi_b_awready),
                .s_axi_b_wdata  (s_axi_b_wdata),
                .s_axi_b_wstrb  (s_axi_b_wstrb),
                .s_axi_b_wlast  (s_axi_b_wlast),
                .s_axi_b_wvalid (s_axi_b_wvalid),
                .s_axi_b_wready (s_axi_b_wready),
                .s_axi_b_bid    (s_axi_b_bid),
                .s_axi_b_bresp  (s_axi_b_bresp),
                .s_axi_b_bvalid (s_axi_b_bvalid),
                .s_axi_b_bready (s_axi_b_bready)
            );
        end else if (ARCH_TYPE == 1) begin
            mvm_mult #(
                .DATA_WIDTH         (DATA_WIDTH),
                .ADDR_WIDTH         (ADDR_WIDTH),
                .STRB_WIDTH         (STRB_WIDTH),
                .ID_WIDTH           (ID_WIDTH),
                .ELEMENT_WIDTH      (ELEMENT_WIDTH),
                .ELEMENTS_PER_WORD  (ELEMENTS_PER_WORD),
                .ELEMENTS_PER_ROW   (ELEMENTS_PER_ROW),
                .WORDS_PER_ROW      (WORDS_PER_ROW),
                .NUM_ROWS           (NUM_ROWS),
                .NUM_CHANNELS       (NUM_CHANNELS),
                .NUM_RAM_PARTITIONS (NUM_RAM_PARTITIONS),
                .ROWS_PER_CHANNEL   (ROWS_PER_CHANNEL),
                .AXI_RAM_DATA_WIDTH (AXI_RAM_DATA_WIDTH),
                .AXI_RAM_BASE_ADDR  (AXI_RAM_BASE_ADDR)
            ) mvm (
                .clk(clk),
                .rstn(rstn),
                
                // Input channels
                .s_axis_a_tdata (s_axis_a_tdata),
                .s_axis_a_tvalid(s_axis_a_tvalid),
                .s_axis_a_tready(s_axis_a_tready),
                .s_axis_a_tlast (s_axis_a_tlast),
            
                // Output channels
                .m_axis_tdata (m_axis_tdata),
                .m_axis_tvalid(m_axis_tvalid),
                .m_axis_tready(m_axis_tready),
                .m_axis_tlast (m_axis_tlast),
            
                // AXI slave interface
                .s_axi_b_awid   (s_axi_b_awid),
                .s_axi_b_awaddr (s_axi_b_awaddr),
                .s_axi_b_awlen  (s_axi_b_awlen),
                .s_axi_b_awsize (s_axi_b_awsize),
                .s_axi_b_awburst(s_axi_b_awburst),
                .s_axi_b_awlock (s_axi_b_awlock),
                .s_axi_b_awcache(s_axi_b_awcache),
                .s_axi_b_awprot (s_axi_b_awprot),
                .s_axi_b_awvalid(s_axi_b_awvalid),
                .s_axi_b_awready(s_axi_b_awready),
                .s_axi_b_wdata  (s_axi_b_wdata),
                .s_axi_b_wstrb  (s_axi_b_wstrb),
                .s_axi_b_wlast  (s_axi_b_wlast),
                .s_axi_b_wvalid (s_axi_b_wvalid),
                .s_axi_b_wready (s_axi_b_wready),
                .s_axi_b_bid    (s_axi_b_bid),
                .s_axi_b_bresp  (s_axi_b_bresp),
                .s_axi_b_bvalid (s_axi_b_bvalid),
                .s_axi_b_bready (s_axi_b_bready)
            );
        end else if (ARCH_TYPE == 2) begin
            ile_iter #(
                .DATA_WIDTH         (DATA_WIDTH),
                .ADDR_WIDTH         (ADDR_WIDTH),
                .STRB_WIDTH         (STRB_WIDTH),
                .ID_WIDTH           (ID_WIDTH),
                .ELEMENT_WIDTH      (ELEMENT_WIDTH),
                .ELEMENTS_PER_WORD  (ELEMENTS_PER_WORD),
                .ELEMENTS_PER_ROW   (ELEMENTS_PER_ROW),
                .WORDS_PER_ROW      (WORDS_PER_ROW),
                .NUM_ROWS           (NUM_ROWS),
                .NUM_CHANNELS       (NUM_CHANNELS),
                .NUM_PARTITIONS     (NUM_RAM_PARTITIONS),
                .ROWS_PER_CHANNEL   (ROWS_PER_CHANNEL),
                .MVM_RAM_DATA_WIDTH (AXI_RAM_DATA_WIDTH),
                .MVM_RAM_BASE_ADDR  (AXI_RAM_BASE_ADDR)
            ) iter (
                .clk(clk),
                .rstn(rstn),
                
                // Input channels
                .s_axis_a_tdata (s_axis_a_tdata),
                .s_axis_a_tvalid(s_axis_a_tvalid),
                .s_axis_a_tready(s_axis_a_tready),
                .s_axis_a_tlast (s_axis_a_tlast),
            
                // Output channels
                .m_axis_tdata (m_axis_tdata),
                .m_axis_tvalid(m_axis_tvalid),
                .m_axis_tready(m_axis_tready),
                .m_axis_tlast (m_axis_tlast),
            
                // AXI slave interface
                .s_axi_b_awid   (s_axi_b_awid),
                .s_axi_b_awaddr (s_axi_b_awaddr),
                .s_axi_b_awlen  (s_axi_b_awlen),
                .s_axi_b_awsize (s_axi_b_awsize),
                .s_axi_b_awburst(s_axi_b_awburst),
                .s_axi_b_awlock (s_axi_b_awlock),
                .s_axi_b_awcache(s_axi_b_awcache),
                .s_axi_b_awprot (s_axi_b_awprot),
                .s_axi_b_awvalid(s_axi_b_awvalid),
                .s_axi_b_awready(s_axi_b_awready),
                .s_axi_b_wdata  (s_axi_b_wdata),
                .s_axi_b_wstrb  (s_axi_b_wstrb),
                .s_axi_b_wlast  (s_axi_b_wlast),
                .s_axi_b_wvalid (s_axi_b_wvalid),
                .s_axi_b_wready (s_axi_b_wready),
                .s_axi_b_bid    (s_axi_b_bid),
                .s_axi_b_bresp  (s_axi_b_bresp),
                .s_axi_b_bvalid (s_axi_b_bvalid),
                .s_axi_b_bready (s_axi_b_bready)
            );
        end
    endgenerate

endmodule
