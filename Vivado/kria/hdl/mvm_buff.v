`timescale 1ns / 1ps

module mvm_buff #(
    parameter MAX_CH = 4,

    parameter DATA_WIDTH         = 128,
    parameter ADDR_WIDTH         = 64,
    parameter STRB_WIDTH         = DATA_WIDTH / 8,
    parameter ID_WIDTH           = 8,
    
    parameter ELEMENT_WIDTH      = 16,

    parameter NUM_ROWS           = 17048,
    parameter ELEMENTS_PER_ROW   = 17048,

    parameter NUM_CHANNELS       = 4,
    parameter NUM_RAM_PARTITIONS = NUM_CHANNELS,

    parameter ELEMENTS_PER_WORD  = DATA_WIDTH / ELEMENT_WIDTH,
    parameter WORDS_PER_ROW      = ELEMENTS_PER_ROW / ELEMENTS_PER_WORD,
    parameter ROWS_PER_CHANNEL   = NUM_ROWS / NUM_CHANNELS,
    
    parameter AXI_RAM_DATA_WIDTH = 256,
    parameter AXI_RAM_BASE_ADDR  = 64'h8000_0000,
    parameter AXI_RAM_STRB_WIDTH = AXI_RAM_DATA_WIDTH / 8
)(
    input wire clk,
    input wire rstn,
    
    // Input stream arrays
    input  wire [DATA_WIDTH*MAX_CH-1:0] s_axis_a_tdata,
    input  wire [MAX_CH-1:0]            s_axis_a_tvalid,
    output wire [MAX_CH-1:0]            s_axis_a_tready,
    input  wire [MAX_CH-1:0]            s_axis_a_tlast,
    
    // Output stream arrays
    output wire [ELEMENT_WIDTH*MAX_CH-1:0] m_axis_tdata,
    output wire [MAX_CH-1:0]               m_axis_tvalid,
    input  wire [MAX_CH-1:0]               m_axis_tready,
    output wire [MAX_CH-1:0]               m_axis_tlast,
    
    // S-AXI interface
    input  wire [ID_WIDTH-1:0]           s_axi_b_awid,
    input  wire [ADDR_WIDTH-1:0]         s_axi_b_awaddr,
    input  wire [7:0]                    s_axi_b_awlen,
    input  wire [2:0]                    s_axi_b_awsize,
    input  wire [1:0]                    s_axi_b_awburst,
    input  wire                          s_axi_b_awlock,
    input  wire [3:0]                    s_axi_b_awcache,
    input  wire [2:0]                    s_axi_b_awprot,
    input  wire                          s_axi_b_awvalid,
    output wire                          s_axi_b_awready,
    input  wire [AXI_RAM_DATA_WIDTH-1:0] s_axi_b_wdata,
    input  wire [AXI_RAM_STRB_WIDTH-1:0] s_axi_b_wstrb,
    input  wire                          s_axi_b_wlast,
    input  wire                          s_axi_b_wvalid,
    output wire                          s_axi_b_wready,
    output wire [ID_WIDTH-1:0]           s_axi_b_bid,
    output wire [1:0]                    s_axi_b_bresp,
    output wire                          s_axi_b_bvalid,
    input  wire                          s_axi_b_bready
);  

    // =============================================================
    //                      MATRIX BUFFER
    // =============================================================

    // TODO

    // =============================================================
    //                      MVM BLOCK
    // =============================================================

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
    
endmodule
