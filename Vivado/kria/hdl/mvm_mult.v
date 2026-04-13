`timescale 1ns / 1ps

module mvm_mult #(
    parameter NUM_GUESSES = 2,

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
    //                      LOCAL RESET
    // =============================================================

    wire [NUM_CHANNELS-1:0] ch_done;
    wire all_done = (ch_done == {NUM_CHANNELS{1'b1}});
    reg  done_rstn;

    localparam LOCAL_RSTN_CYCLES = 4;
    reg [$clog2(LOCAL_RSTN_CYCLES):0] done_rstn_count;

    always @(posedge clk) begin
        if (!rstn) begin
            done_rstn <= 1'b1; 
            done_rstn_count <= 0;
        end else if (!done_rstn) begin
            // hold rstn signal low for LOCAL_RSTN_CYCLES cycles
            if (done_rstn_count < LOCAL_RSTN_CYCLES-1)
                done_rstn_count <= done_rstn_count + 1;
            else
                done_rstn <= 1'b1;
        end else begin
            // assert rstn when channels are done
            done_rstn <= !all_done;
            done_rstn_count <= 0;
        end
    end

    // =============================================================
    //                  PARTITION ACCESS LOGIC
    // =============================================================

    localparam NUM_CHANNELS_WIDTH     = $clog2(NUM_CHANNELS+1);
    localparam NUM_PARTITIONS_WIDTH   = $clog2(NUM_RAM_PARTITIONS+1);
    localparam ROWS_PER_CHANNEL_WIDTH = $clog2(ROWS_PER_CHANNEL+1);

    reg  [NUM_CHANNELS_WIDTH-1:0]     rr_ptr              [NUM_RAM_PARTITIONS-1:0]; // round-robin arbiter

    reg                               ch_start            [NUM_CHANNELS-1:0];
    reg  [NUM_PARTITIONS_WIDTH-1:0]   ch_pidx             [NUM_CHANNELS-1:0];
    wire                              ch_pdone            [NUM_CHANNELS-1:0];
    wire                              ch_has_room         [NUM_CHANNELS-1:0];
    wire                              ch_a_data           [NUM_CHANNELS-1:0];
    wire                              ch_wants_part       [NUM_CHANNELS-1:0];
    reg  [ROWS_PER_CHANNEL_WIDTH-1:0] ch_num_rows_fetched [NUM_CHANNELS-1:0];
    wire                              ch_all_rows_fetched [NUM_CHANNELS-1:0];

    reg  part_in_use [NUM_RAM_PARTITIONS-1:0];
    
    genvar ch;
    generate
        for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin : assign_ch
            assign ch_all_rows_fetched[ch] = (ch_num_rows_fetched[ch] == ROWS_PER_CHANNEL);
            assign ch_wants_part[ch]       = !ch_all_rows_fetched[ch]
                                          &&  ch_has_room[ch]
                                          &&  ch_a_data[ch]
                                          && !ch_start[ch];
        end
    endgenerate

    integer p;
    always @(posedge clk) begin
        if (!rstn || !done_rstn) begin
            for (p = 0; p < NUM_CHANNELS; p = p + 1) begin
                ch_pidx[p]             <= 0;
                ch_num_rows_fetched[p] <= 0;
            end
        end else begin
            for (p = 0; p < NUM_CHANNELS; p = p + 1) begin
                if (ch_pdone[p]) begin
                    if (ch_pidx[p] == NUM_RAM_PARTITIONS-1) begin
                        ch_num_rows_fetched[p] <= ch_num_rows_fetched[p] + 1;
                        ch_pidx[p] <= 0;
                    end else begin
                        ch_pidx[p] <= ch_pidx[p] + 1;
                    end
                end
            end
        end
    end
    
    integer q, r, idx;
    always @(posedge clk) begin
        if (!rstn || !done_rstn) begin
            for (r = 0; r < NUM_CHANNELS; r = r + 1) begin
                ch_start[r] <= 1'b0;
            end
            for (q = 0; q < NUM_RAM_PARTITIONS; q = q + 1) begin
                part_in_use[q] <= 1'b0;
                rr_ptr[q]      <= {NUM_CHANNELS_WIDTH{1'b0}};
            end
        end else begin
            for (r = 0; r < NUM_CHANNELS; r = r + 1) begin
                ch_start[r] <= 1'b0; // clear by default
            end
            for (q = 0; q < NUM_RAM_PARTITIONS; q = q + 1) begin

                if (part_in_use[q]) begin
                    for (r = 0; r < NUM_CHANNELS; r = r + 1) begin
                        if (ch_pdone[r] && ch_pidx[r] == q)
                            part_in_use[q] <= 1'b0;
                    end
                end else begin : GRANT_LOOP

                    for (r = 0; r < NUM_CHANNELS; r = r + 1) begin

                        idx = rr_ptr[q] + 1 + r; // start with the channel after 
                                                 // the one we just granted to

                        if (idx >= NUM_CHANNELS)
                            idx = idx - NUM_CHANNELS;

                        if (ch_wants_part[idx] && ch_pidx[idx] == q) begin
                            ch_start[idx] <= 1'b1;
                            part_in_use[q] <= 1'b1;
                            rr_ptr[q] <= idx[NUM_CHANNELS_WIDTH-1:0];
                            disable GRANT_LOOP; // only grant to one waiting channel
                        end
                    end
                end
            end
        end
    end

    // =============================================================
    //                  GENERATE CHANNELS
    // =============================================================
    
    wire [ID_WIDTH-1:0]           m_axi_arid     [MAX_CH-1:0];
    wire [ADDR_WIDTH-1:0]         m_axi_araddr   [MAX_CH-1:0];
    wire [7:0]                    m_axi_arlen    [MAX_CH-1:0];
    wire [2:0]                    m_axi_arsize   [MAX_CH-1:0];
    wire [1:0]                    m_axi_arburst  [MAX_CH-1:0];
    wire                          m_axi_arlock   [MAX_CH-1:0];
    wire [3:0]                    m_axi_arcache  [MAX_CH-1:0];
    wire [2:0]                    m_axi_arprot   [MAX_CH-1:0];
    wire                          m_axi_arvalid  [MAX_CH-1:0];
    wire                          m_axi_arready  [MAX_CH-1:0];
    wire [ID_WIDTH-1:0]           m_axi_rid      [MAX_CH-1:0];
    wire [AXI_RAM_DATA_WIDTH-1:0] m_axi_rdata    [MAX_CH-1:0];
    wire [1:0]                    m_axi_rresp    [MAX_CH-1:0];
    wire                          m_axi_rlast    [MAX_CH-1:0];
    wire                          m_axi_rvalid   [MAX_CH-1:0];
    wire                          m_axi_rready   [MAX_CH-1:0];

    generate
        for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin : channel_gen
        
            mvm_channel_mult #(
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .STRB_WIDTH(STRB_WIDTH),
                .ID_WIDTH(ID_WIDTH),
                .TAG(ch),

                .ELEMENT_WIDTH(ELEMENT_WIDTH),
                .ELEMENTS_PER_WORD(ELEMENTS_PER_WORD),
                .ELEMENTS_PER_ROW(ELEMENTS_PER_ROW),
                .WORDS_PER_ROW(WORDS_PER_ROW),
                .NUM_ROWS(NUM_ROWS),

                .AXI_RAM_DATA_WIDTH(AXI_RAM_DATA_WIDTH),
                .AXI_RAM_BASE_ADDR(AXI_RAM_BASE_ADDR),
                .NUM_CHANNELS(NUM_CHANNELS),
                .NUM_RAM_PARTITIONS(NUM_RAM_PARTITIONS),
                .ROWS_PER_CHANNEL(ROWS_PER_CHANNEL)
            ) channel_inst (
                .clk(clk),
                .rstn(rstn),
                        
                .s_axis_a_tdata (s_axis_a_tdata [DATA_WIDTH*ch +: DATA_WIDTH]),
                .s_axis_a_tvalid(s_axis_a_tvalid[ch]),
                .s_axis_a_tready(s_axis_a_tready[ch]),
                .s_axis_a_tlast (s_axis_a_tlast [ch]),
                .m_axis_tdata   (m_axis_tdata   [ELEMENT_WIDTH*ch +: ELEMENT_WIDTH]),
                .m_axis_tvalid  (m_axis_tvalid  [ch]),
                .m_axis_tready  (m_axis_tready  [ch]),
                .m_axis_tlast   (m_axis_tlast   [ch]),
                
                .m_axi_arid     (m_axi_arid   [ch]),
                .m_axi_araddr   (m_axi_araddr [ch]),
                .m_axi_arlen    (m_axi_arlen  [ch]),
                .m_axi_arsize   (m_axi_arsize [ch]),
                .m_axi_arburst  (m_axi_arburst[ch]),
                .m_axi_arlock   (m_axi_arlock [ch]),
                .m_axi_arcache  (m_axi_arcache[ch]),
                .m_axi_arprot   (m_axi_arprot [ch]),
                .m_axi_arvalid  (m_axi_arvalid[ch]),
                .m_axi_arready  (m_axi_arready[ch]),
                .m_axi_rid      (m_axi_rid    [ch]),
                .m_axi_rdata    (m_axi_rdata  [ch]),
                .m_axi_rresp    (m_axi_rresp  [ch]),
                .m_axi_rlast    (m_axi_rlast  [ch]),
                .m_axi_rvalid   (m_axi_rvalid [ch]),
                .m_axi_rready   (m_axi_rready [ch]),
                
                .start          (ch_start   [ch]),
                .partition_done (ch_pdone   [ch]),
                .partition_index(ch_pidx    [ch]),
                .channel_done   (ch_done    [ch]),
                .has_room       (ch_has_room[ch]),
                .is_a_data      (ch_a_data  [ch]),
                .done_rstn      (done_rstn)
            );
        end
    endgenerate

    // =============================================================
    //                        AXI CROSSBARS
    // =============================================================
    
    function automatic [NUM_RAM_PARTITIONS*ADDR_WIDTH-1:0] gen_m_base_addr;
        input [ADDR_WIDTH-1:0] base;
        input [ADDR_WIDTH-1:0] stride;
        integer i;
        begin
            for (i = 0; i < NUM_RAM_PARTITIONS; i = i + 1) begin
                gen_m_base_addr[i*ADDR_WIDTH +: ADDR_WIDTH] = base + ( ( {ADDR_WIDTH{1'b0}} | stride ) * i );
            end
        end
    endfunction
    
    localparam AXI_RAM_ELEMENTS_PER_WORD   = AXI_RAM_DATA_WIDTH / ELEMENT_WIDTH;
    localparam AXI_RAM_WORDS_PER_ROW       = ELEMENTS_PER_ROW / AXI_RAM_ELEMENTS_PER_WORD;
    localparam AXI_RAM_WORDS_PER_PARTITION = AXI_RAM_WORDS_PER_ROW / NUM_RAM_PARTITIONS;
    localparam AXI_RAM_BYTES_PER_PARTITION = AXI_RAM_WORDS_PER_PARTITION * AXI_RAM_STRB_WIDTH;
    localparam AXI_RAM_ID_WIDTH            = ID_WIDTH + $clog2(NUM_CHANNELS);

    localparam AXI_RAM_LOCAL_ADDR_WIDTH  = $clog2(AXI_RAM_BYTES_PER_PARTITION);
    localparam AXI_RAM_DECODE_ADDR_WIDTH = (AXI_RAM_LOCAL_ADDR_WIDTH < 12) ? 12 : AXI_RAM_LOCAL_ADDR_WIDTH;

    localparam [ADDR_WIDTH-1:0] REGION_STRIDE = (1 << AXI_RAM_DECODE_ADDR_WIDTH);
    localparam [NUM_RAM_PARTITIONS*ADDR_WIDTH-1:0] M_BASE_ADDR = gen_m_base_addr(AXI_RAM_BASE_ADDR, REGION_STRIDE);
    localparam [NUM_RAM_PARTITIONS*32-1:0] M_ADDR_WIDTH = {NUM_RAM_PARTITIONS{AXI_RAM_DECODE_ADDR_WIDTH}};
    
    wire [AXI_RAM_ID_WIDTH-1:0]   ram_m_axi_awid    [NUM_RAM_PARTITIONS-1:0];
    wire [ADDR_WIDTH-1:0]         ram_m_axi_awaddr  [NUM_RAM_PARTITIONS-1:0];
    wire [7:0]                    ram_m_axi_awlen   [NUM_RAM_PARTITIONS-1:0];
    wire [2:0]                    ram_m_axi_awsize  [NUM_RAM_PARTITIONS-1:0];
    wire [1:0]                    ram_m_axi_awburst [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_awlock  [NUM_RAM_PARTITIONS-1:0];
    wire [3:0]                    ram_m_axi_awcache [NUM_RAM_PARTITIONS-1:0];
    wire [2:0]                    ram_m_axi_awprot  [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_awvalid [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_awready [NUM_RAM_PARTITIONS-1:0];

    wire [AXI_RAM_DATA_WIDTH-1:0] ram_m_axi_wdata   [NUM_RAM_PARTITIONS-1:0];
    wire [AXI_RAM_STRB_WIDTH-1:0] ram_m_axi_wstrb   [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_wlast   [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_wvalid  [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_wready  [NUM_RAM_PARTITIONS-1:0];

    wire [AXI_RAM_ID_WIDTH-1:0]   ram_m_axi_bid     [NUM_RAM_PARTITIONS-1:0];
    wire [1:0]                    ram_m_axi_bresp   [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_bvalid  [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_bready  [NUM_RAM_PARTITIONS-1:0];
    
    wire [AXI_RAM_ID_WIDTH-1:0]   ram_m_axi_arid    [NUM_RAM_PARTITIONS-1:0];
    wire [ADDR_WIDTH-1:0]         ram_m_axi_araddr  [NUM_RAM_PARTITIONS-1:0];
    wire [7:0]                    ram_m_axi_arlen   [NUM_RAM_PARTITIONS-1:0];
    wire [2:0]                    ram_m_axi_arsize  [NUM_RAM_PARTITIONS-1:0];
    wire [1:0]                    ram_m_axi_arburst [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_arlock  [NUM_RAM_PARTITIONS-1:0];
    wire [3:0]                    ram_m_axi_arcache [NUM_RAM_PARTITIONS-1:0];
    wire [2:0]                    ram_m_axi_arprot  [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_arvalid [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_arready [NUM_RAM_PARTITIONS-1:0];

    wire [AXI_RAM_ID_WIDTH-1:0]   ram_m_axi_rid     [NUM_RAM_PARTITIONS-1:0];
    wire [AXI_RAM_DATA_WIDTH-1:0] ram_m_axi_rdata   [NUM_RAM_PARTITIONS-1:0];
    wire [1:0]                    ram_m_axi_rresp   [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_rlast   [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_rvalid  [NUM_RAM_PARTITIONS-1:0];
    wire                          ram_m_axi_rready  [NUM_RAM_PARTITIONS-1:0];

    axi_crossbar_wr #(
        .S_COUNT(1),
        .M_COUNT(NUM_RAM_PARTITIONS),
        .DATA_WIDTH(AXI_RAM_DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .S_ID_WIDTH(ID_WIDTH),
        .M_ID_WIDTH(AXI_RAM_ID_WIDTH),

        .M_BASE_ADDR(M_BASE_ADDR),
        .M_ADDR_WIDTH(M_ADDR_WIDTH),
    
        .S_AW_REG_TYPE(2'd2),
        .S_W_REG_TYPE(2'd2),
        .S_B_REG_TYPE(2'd2),
        .M_AW_REG_TYPE({NUM_RAM_PARTITIONS{2'd2}}),
        .M_W_REG_TYPE({NUM_RAM_PARTITIONS{2'd2}}),
        .M_B_REG_TYPE({NUM_RAM_PARTITIONS{2'd2}})
    ) xbar_wr_inst (
        .clk(clk), .rstn(rstn),
        `include "xbar_wr_channels.vh"
        .s_axi_awqos(4'b0),
        .s_axi_awuser(1'b0),
        .s_axi_wuser(1'b0),
        .m_axi_wuser(),
        .m_axi_buser()
    );

    axi_crossbar_rd #(
        .S_COUNT(NUM_CHANNELS),
        .M_COUNT(NUM_RAM_PARTITIONS),
        .DATA_WIDTH(AXI_RAM_DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .S_ID_WIDTH(ID_WIDTH),
        .M_ID_WIDTH(AXI_RAM_ID_WIDTH),

        .M_BASE_ADDR(M_BASE_ADDR),
        .M_ADDR_WIDTH(M_ADDR_WIDTH),
    
        .S_AR_REG_TYPE({NUM_CHANNELS{2'd2}}),
        .S_R_REG_TYPE({NUM_CHANNELS{2'd2}}),
        .M_AR_REG_TYPE({NUM_RAM_PARTITIONS{2'd2}}),
        .M_R_REG_TYPE({NUM_RAM_PARTITIONS{2'd2}})
    ) xbar_rd_inst (
        .clk(clk), .rstn(rstn),
        `include "xbar_rd_channels.vh"
        .s_axi_arqos({NUM_CHANNELS{4'b0}}),
        .s_axi_aruser({NUM_CHANNELS{1'b0}}),
        .s_axi_ruser(),
        .m_axi_ruser({NUM_RAM_PARTITIONS{1'b0}})
    );

    // =============================================================
    //                          AXI RAM
    // =============================================================
    
    genvar k;
    generate
        for (k = 0; k < NUM_RAM_PARTITIONS; k = k + 1) begin : ram_gen
            
            axi_ram #(
                .DATA_WIDTH(AXI_RAM_DATA_WIDTH),
                .ADDR_WIDTH(AXI_RAM_LOCAL_ADDR_WIDTH),
                .STRB_WIDTH(AXI_RAM_STRB_WIDTH),
                .ID_WIDTH  (AXI_RAM_ID_WIDTH),
                .NUM_WORDS (AXI_RAM_WORDS_PER_PARTITION)
            ) axi_ram_inst (
                .clk(clk), .rstn(rstn),
        
                .s_axi_awid   (ram_m_axi_awid   [k]),
                .s_axi_awaddr (ram_m_axi_awaddr [k][AXI_RAM_LOCAL_ADDR_WIDTH-1:0]),
                .s_axi_awlen  (ram_m_axi_awlen  [k]),
                .s_axi_awsize (ram_m_axi_awsize [k]),
                .s_axi_awburst(ram_m_axi_awburst[k]),
                .s_axi_awlock (ram_m_axi_awlock [k]),
                .s_axi_awcache(ram_m_axi_awcache[k]),
                .s_axi_awprot (ram_m_axi_awprot [k]),
                .s_axi_awvalid(ram_m_axi_awvalid[k]),
                .s_axi_awready(ram_m_axi_awready[k]),
                
                .s_axi_wdata  (ram_m_axi_wdata  [k]),
                .s_axi_wstrb  (ram_m_axi_wstrb  [k]),
                .s_axi_wlast  (ram_m_axi_wlast  [k]),
                .s_axi_wvalid (ram_m_axi_wvalid [k]),
                .s_axi_wready (ram_m_axi_wready [k]),
                
                .s_axi_bid    (ram_m_axi_bid    [k]),
                .s_axi_bresp  (ram_m_axi_bresp  [k]),
                .s_axi_bvalid (ram_m_axi_bvalid [k]),
                .s_axi_bready (ram_m_axi_bready [k]),
        
                .s_axi_arid   (ram_m_axi_arid   [k]),
                .s_axi_araddr (ram_m_axi_araddr [k][AXI_RAM_LOCAL_ADDR_WIDTH-1:0]),
                .s_axi_arlen  (ram_m_axi_arlen  [k]),
                .s_axi_arsize (ram_m_axi_arsize [k]),
                .s_axi_arburst(ram_m_axi_arburst[k]),
                .s_axi_arlock (ram_m_axi_arlock [k]),
                .s_axi_arcache(ram_m_axi_arcache[k]),
                .s_axi_arprot (ram_m_axi_arprot [k]),
                .s_axi_arvalid(ram_m_axi_arvalid[k]),
                .s_axi_arready(ram_m_axi_arready[k]),
            
                .s_axi_rid    (ram_m_axi_rid    [k]),
                .s_axi_rdata  (ram_m_axi_rdata  [k]),
                .s_axi_rresp  (ram_m_axi_rresp  [k]),
                .s_axi_rlast  (ram_m_axi_rlast  [k]),
                .s_axi_rvalid (ram_m_axi_rvalid [k]),
                .s_axi_rready (ram_m_axi_rready [k])
            );
        end
    endgenerate
    
endmodule
