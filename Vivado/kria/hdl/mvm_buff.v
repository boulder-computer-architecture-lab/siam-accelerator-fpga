`timescale 1ns / 1ps

module mvm_buff #(
    parameter MAX_CH = 4,

    parameter DATA_WIDTH         = 128,
    parameter ADDR_WIDTH         = 64,
    parameter STRB_WIDTH         = DATA_WIDTH / 8,
    parameter ID_WIDTH           = 8,

    parameter ELEMENT_WIDTH      = 16,

    parameter NUM_ROWS           = 192,
    parameter ELEMENTS_PER_ROW   = 192,

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

    localparam TOTAL_WORDS_PER_CH = ROWS_PER_CHANNEL * WORDS_PER_ROW;

    localparam MATRIX_MEMFILE_0 = (ELEMENT_WIDTH == 16) ? "a_ch0_16.mem"
                                                        : "a_ch0_64.mem";
    localparam MATRIX_MEMFILE_1 = (ELEMENT_WIDTH == 16) ? "a_ch1_16.mem"
                                                        : "a_ch1_64.mem";
    localparam MATRIX_MEMFILE_2 = (ELEMENT_WIDTH == 16) ? "a_ch2_16.mem"
                                                        : "a_ch2_64.mem";
    localparam MATRIX_MEMFILE_3 = (ELEMENT_WIDTH == 16) ? "a_ch3_16.mem"
                                                        : "a_ch3_64.mem";

    // =============================================================
    //               LOCAL A-STREAM GENERATED FROM ROM
    // =============================================================

    // A-stream wires driven into mvm_base
    wire [DATA_WIDTH*MAX_CH-1:0] a_rom_tdata;
    wire [MAX_CH-1:0]            a_rom_tvalid;
    wire [MAX_CH-1:0]            a_rom_tready;
    wire [MAX_CH-1:0]            a_rom_tlast;

    // Fire the ROM streamers when the vector write transaction completes.
    // This assumes one B-channel response per logical vector write, which matches
    // the intended usage here.
    wire vec_write_done_pulse = s_axi_b_bvalid & s_axi_b_bready;

    genvar ch;
    generate
        for (ch = 0; ch < MAX_CH; ch = ch + 1) begin : GEN_A_STREAMS
            if (ch < NUM_CHANNELS) begin : GEN_ACTIVE_CH
                if (ch == 0) begin : GEN_CH0
                    axis_matrix_rom_streamer #(
                        .DATA_WIDTH   (DATA_WIDTH),
                        .DEPTH_WORDS  (TOTAL_WORDS_PER_CH),
                        .WORDS_PER_ROW(WORDS_PER_ROW),
                        .MEMFILE      (MATRIX_MEMFILE_0)
                    ) a_streamer (
                        .clk          (clk),
                        .rstn         (rstn),
                        .start        (vec_write_done_pulse),
                        .m_axis_tdata (a_rom_tdata [ch*DATA_WIDTH +: DATA_WIDTH]),
                        .m_axis_tvalid(a_rom_tvalid[ch]),
                        .m_axis_tready(a_rom_tready[ch]),
                        .m_axis_tlast (a_rom_tlast [ch])
                    );
                end else if (ch == 1) begin : GEN_CH1
                    axis_matrix_rom_streamer #(
                        .DATA_WIDTH   (DATA_WIDTH),
                        .DEPTH_WORDS  (TOTAL_WORDS_PER_CH),
                        .WORDS_PER_ROW(WORDS_PER_ROW),
                        .MEMFILE      (MATRIX_MEMFILE_1)
                    ) a_streamer (
                        .clk          (clk),
                        .rstn         (rstn),
                        .start        (vec_write_done_pulse),
                        .m_axis_tdata (a_rom_tdata [ch*DATA_WIDTH +: DATA_WIDTH]),
                        .m_axis_tvalid(a_rom_tvalid[ch]),
                        .m_axis_tready(a_rom_tready[ch]),
                        .m_axis_tlast (a_rom_tlast [ch])
                    );
                end else if (ch == 2) begin : GEN_CH2
                    axis_matrix_rom_streamer #(
                        .DATA_WIDTH   (DATA_WIDTH),
                        .DEPTH_WORDS  (TOTAL_WORDS_PER_CH),
                        .WORDS_PER_ROW(WORDS_PER_ROW),
                        .MEMFILE      (MATRIX_MEMFILE_2)
                    ) a_streamer (
                        .clk          (clk),
                        .rstn         (rstn),
                        .start        (vec_write_done_pulse),
                        .m_axis_tdata (a_rom_tdata [ch*DATA_WIDTH +: DATA_WIDTH]),
                        .m_axis_tvalid(a_rom_tvalid[ch]),
                        .m_axis_tready(a_rom_tready[ch]),
                        .m_axis_tlast (a_rom_tlast [ch])
                    );
                end else begin : GEN_CH3
                    axis_matrix_rom_streamer #(
                        .DATA_WIDTH   (DATA_WIDTH),
                        .DEPTH_WORDS  (TOTAL_WORDS_PER_CH),
                        .WORDS_PER_ROW(WORDS_PER_ROW),
                        .MEMFILE      (MATRIX_MEMFILE_3)
                    ) a_streamer (
                        .clk          (clk),
                        .rstn         (rstn),
                        .start        (vec_write_done_pulse),
                        .m_axis_tdata (a_rom_tdata [ch*DATA_WIDTH +: DATA_WIDTH]),
                        .m_axis_tvalid(a_rom_tvalid[ch]),
                        .m_axis_tready(a_rom_tready[ch]),
                        .m_axis_tlast (a_rom_tlast [ch])
                    );
                end
            end else begin : GEN_UNUSED_CH
                assign a_rom_tdata [ch*DATA_WIDTH +: DATA_WIDTH] = {DATA_WIDTH{1'b0}};
                assign a_rom_tvalid[ch] = 1'b0;
                assign a_rom_tlast [ch] = 1'b0;
            end
        end
    endgenerate

    // =============================================================
    //                        MVM BLOCK
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

        // Input channels now come from local ROM streamers
        .s_axis_a_tdata (a_rom_tdata),
        .s_axis_a_tvalid(a_rom_tvalid),
        .s_axis_a_tready(a_rom_tready),
        .s_axis_a_tlast (a_rom_tlast),

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

