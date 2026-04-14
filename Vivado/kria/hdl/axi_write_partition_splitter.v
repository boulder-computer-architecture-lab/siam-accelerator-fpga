`timescale 1ns / 1ps

module axi_write_partition_splitter #(
    parameter NUM_PARTITIONS = 4,

    parameter ADDR_WIDTH   = 64,
    parameter DATA_WIDTH   = 256,
    parameter STRB_WIDTH   = DATA_WIDTH / 8,

    parameter S_ID_WIDTH   = 8,
    parameter M_ID_WIDTH   = 10,

    // Number of AXI write beats stored in EACH partition
    parameter PARTITION_BEATS = 128,

    // Base address of upstream AXI slave window
    parameter [ADDR_WIDTH-1:0] S_AXI_EXPECTED_AWADDR = 64'h0000_0000_8000_0000
)(
    input  wire                     clk,
    input  wire                     rstn,

    // =========================================================
    // Upstream AXI slave interface (from CDMA)
    // =========================================================
    input  wire [S_ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,

    output wire [S_ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,

    // =========================================================
    // Downstream AXI master interfaces (to partitioned RAMs)
    // =========================================================
    output wire [NUM_PARTITIONS*M_ID_WIDTH-1:0] m_axi_awid,
    output wire [NUM_PARTITIONS*ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [NUM_PARTITIONS*8-1:0]          m_axi_awlen,
    output wire [NUM_PARTITIONS*3-1:0]          m_axi_awsize,
    output wire [NUM_PARTITIONS*2-1:0]          m_axi_awburst,
    output wire [NUM_PARTITIONS-1:0]            m_axi_awlock,
    output wire [NUM_PARTITIONS*4-1:0]          m_axi_awcache,
    output wire [NUM_PARTITIONS*3-1:0]          m_axi_awprot,
    output wire [NUM_PARTITIONS-1:0]            m_axi_awvalid,
    input  wire [NUM_PARTITIONS-1:0]            m_axi_awready,

    output wire [NUM_PARTITIONS*DATA_WIDTH-1:0] m_axi_wdata,
    output wire [NUM_PARTITIONS*STRB_WIDTH-1:0] m_axi_wstrb,
    output wire [NUM_PARTITIONS-1:0]            m_axi_wlast,
    output wire [NUM_PARTITIONS-1:0]            m_axi_wvalid,
    input  wire [NUM_PARTITIONS-1:0]            m_axi_wready,

    input  wire [NUM_PARTITIONS*M_ID_WIDTH-1:0] m_axi_bid,
    input  wire [NUM_PARTITIONS*2-1:0]          m_axi_bresp,
    input  wire [NUM_PARTITIONS-1:0]            m_axi_bvalid,
    output wire [NUM_PARTITIONS-1:0]            m_axi_bready
);

    localparam PART_IDX_W   = (NUM_PARTITIONS <= 1) ? 1 : $clog2(NUM_PARTITIONS);
    localparam BEAT_IDX_W   = (PARTITION_BEATS <= 1) ? 1 : $clog2(PARTITION_BEATS);
    localparam TOTAL_BEATS  = NUM_PARTITIONS * PARTITION_BEATS;
    localparam TOTAL_BEAT_W = (TOTAL_BEATS <= 1) ? 1 : $clog2(TOTAL_BEATS + 1);
    localparam CHILD_BEAT_W = 9; // enough for 1..256 beats

    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;

    // =========================================================
    // Internal state
    // =========================================================

    // Logical whole-vector transfer state
    reg                        busy;
    reg [ADDR_WIDTH-1:0]       expected_awaddr_reg;
    reg [TOTAL_BEAT_W-1:0]     total_beats_done;
    reg [PART_IDX_W-1:0]       active_part;
    reg [BEAT_IDX_W-1:0]       beat_in_part;

    // Latched protocol fields from first burst of current vector write
    reg [S_ID_WIDTH-1:0]       awid_reg;
    reg [2:0]                  awsize_reg;
    reg [1:0]                  awburst_reg;
    reg                        awlock_reg;
    reg [3:0]                  awcache_reg;
    reg [2:0]                  awprot_reg;

    // Current upstream burst state (one upstream burst at a time)
    reg                        burst_active;
    reg                        burst_resp_pending;
    reg [8:0]                  burst_beats_left;   // 1..256
    reg [1:0]                  burst_bresp;
    reg                        burst_error;

    // Current downstream child burst state (one child burst at a time)
    reg                        child_active;
    reg                        child_aw_done;
    reg                        child_wait_b;
    reg [PART_IDX_W-1:0]       child_part;
    reg [BEAT_IDX_W-1:0]       child_start_beat;
    reg [CHILD_BEAT_W-1:0]     child_beats_total;  // 1..256
    reg [CHILD_BEAT_W-1:0]     child_beats_left;   // remaining

    // =========================================================
    // Helper wires
    // =========================================================

    wire transfer_done;
    wire burst_done_now;
    wire child_aw_fire;
    wire child_w_fire;
    wire child_b_fire;

    wire [BEAT_IDX_W:0]        part_beats_remaining_wide;
    wire [CHILD_BEAT_W-1:0]    part_beats_remaining_capped;
    wire [CHILD_BEAT_W-1:0]    next_child_beats;

    wire [ADDR_WIDTH-1:0]      up_burst_beats_ext;
    wire [ADDR_WIDTH-1:0]      up_burst_bytes_ext;

    assign transfer_done = (total_beats_done == TOTAL_BEATS);

    assign part_beats_remaining_wide =
        PARTITION_BEATS - beat_in_part;

    assign part_beats_remaining_capped =
        (part_beats_remaining_wide >= 256) ?
            9'd256 :
            {{(CHILD_BEAT_W-(BEAT_IDX_W+1)){1'b0}}, part_beats_remaining_wide};

    assign next_child_beats =
        (burst_beats_left < part_beats_remaining_capped) ?
            burst_beats_left :
            part_beats_remaining_capped;

    assign up_burst_beats_ext = {{(ADDR_WIDTH-8){1'b0}}, s_axi_awlen} + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
    assign up_burst_bytes_ext = up_burst_beats_ext << s_axi_awsize;

    assign child_aw_fire = child_active && !child_aw_done && m_axi_awready[child_part];
    assign child_w_fire  = s_axi_wvalid && s_axi_wready;
    assign child_b_fire  = child_wait_b && m_axi_bvalid[child_part] && m_axi_bready[child_part];

    assign burst_done_now = burst_resp_pending && !child_active;

    // =========================================================
    // Upstream interface
    // =========================================================

    // Accept a new upstream AW only when there is no in-flight upstream burst
    assign s_axi_awready = !burst_active && !burst_resp_pending;

    assign s_axi_wready  = burst_active
                        && child_active
                        && child_aw_done
                        && !child_wait_b
                        && m_axi_wready[child_part];

    assign s_axi_bid     = awid_reg;
    assign s_axi_bvalid  = burst_done_now;
    assign s_axi_bresp   = burst_error ? AXI_RESP_SLVERR : burst_bresp;

    // =========================================================
    // Downstream AW channels
    // =========================================================

    genvar p;
    generate
        for (p = 0; p < NUM_PARTITIONS; p = p + 1) begin : GEN_AW
            wire sel;
            assign sel = child_active && !child_aw_done && (child_part == p);

            assign m_axi_awid[p*M_ID_WIDTH +: M_ID_WIDTH] =
                sel ? {{(M_ID_WIDTH-S_ID_WIDTH){1'b0}}, awid_reg} : {M_ID_WIDTH{1'b0}};

            // local RAM address = child_start_beat * bytes_per_beat
            assign m_axi_awaddr[p*ADDR_WIDTH +: ADDR_WIDTH] =
                sel ? ({{(ADDR_WIDTH-BEAT_IDX_W){1'b0}}, child_start_beat} << awsize_reg)
                    : {ADDR_WIDTH{1'b0}};

            assign m_axi_awlen[p*8 +: 8] =
                sel ? (child_beats_total - 1'b1) : 8'd0;

            assign m_axi_awsize[p*3 +: 3] =
                sel ? awsize_reg : 3'd0;

            assign m_axi_awburst[p*2 +: 2] =
                sel ? awburst_reg : 2'd0;

            assign m_axi_awlock[p] =
                sel ? awlock_reg : 1'b0;

            assign m_axi_awcache[p*4 +: 4] =
                sel ? awcache_reg : 4'd0;

            assign m_axi_awprot[p*3 +: 3] =
                sel ? awprot_reg : 3'd0;

            assign m_axi_awvalid[p] = sel;
        end
    endgenerate

    // =========================================================
    // Downstream W channels
    // =========================================================

    generate
        for (p = 0; p < NUM_PARTITIONS; p = p + 1) begin : GEN_W
            wire sel;
            assign sel = child_active && child_aw_done && !child_wait_b && (child_part == p);

            assign m_axi_wdata[p*DATA_WIDTH +: DATA_WIDTH] = s_axi_wdata;
            assign m_axi_wstrb[p*STRB_WIDTH +: STRB_WIDTH] = s_axi_wstrb;
            assign m_axi_wvalid[p] = sel && burst_active && s_axi_wvalid;
            assign m_axi_wlast[p]  = sel && burst_active && s_axi_wvalid && (child_beats_left == 1);
        end
    endgenerate

    // =========================================================
    // Downstream B channels
    // =========================================================

    generate
        for (p = 0; p < NUM_PARTITIONS; p = p + 1) begin : GEN_B
            assign m_axi_bready[p] = child_wait_b && (child_part == p);
        end
    endgenerate

    // =========================================================
    // Sequential control
    // =========================================================

    always @(posedge clk) begin
        if (!rstn) begin
            busy                <= 1'b0;
            expected_awaddr_reg <= S_AXI_EXPECTED_AWADDR;
            total_beats_done    <= {TOTAL_BEAT_W{1'b0}};
            active_part         <= {PART_IDX_W{1'b0}};
            beat_in_part        <= {BEAT_IDX_W{1'b0}};

            awid_reg            <= {S_ID_WIDTH{1'b0}};
            awsize_reg          <= 3'b000;
            awburst_reg         <= 2'b01;
            awlock_reg          <= 1'b0;
            awcache_reg         <= 4'b0000;
            awprot_reg          <= 3'b000;

            burst_active        <= 1'b0;
            burst_resp_pending  <= 1'b0;
            burst_beats_left    <= 9'd0;
            burst_bresp         <= AXI_RESP_OKAY;
            burst_error         <= 1'b0;

            child_active        <= 1'b0;
            child_aw_done       <= 1'b0;
            child_wait_b        <= 1'b0;
            child_part          <= {PART_IDX_W{1'b0}};
            child_start_beat    <= {BEAT_IDX_W{1'b0}};
            child_beats_total   <= {CHILD_BEAT_W{1'b0}};
            child_beats_left    <= {CHILD_BEAT_W{1'b0}};
        end else begin

            // -------------------------------------------------
            // Accept an upstream AW burst
            // -------------------------------------------------
            if (s_axi_awvalid && s_axi_awready) begin
                if (!busy) begin
                    busy                <= 1'b1;
                    expected_awaddr_reg <= S_AXI_EXPECTED_AWADDR;

                    total_beats_done    <= {TOTAL_BEAT_W{1'b0}};
                    active_part         <= {PART_IDX_W{1'b0}};
                    beat_in_part        <= {BEAT_IDX_W{1'b0}};

                    awid_reg            <= s_axi_awid;
                    awsize_reg          <= s_axi_awsize;
                    awburst_reg         <= s_axi_awburst;
                    awlock_reg          <= s_axi_awlock;
                    awcache_reg         <= s_axi_awcache;
                    awprot_reg          <= s_axi_awprot;
                end else begin
                    if (s_axi_awid    != awid_reg)    burst_error <= 1'b1;
                    if (s_axi_awsize  != awsize_reg)  burst_error <= 1'b1;
                    if (s_axi_awburst != awburst_reg) burst_error <= 1'b1;
                    if (s_axi_awlock  != awlock_reg)  burst_error <= 1'b1;
                    if (s_axi_awcache != awcache_reg) burst_error <= 1'b1;
                    if (s_axi_awprot  != awprot_reg)  burst_error <= 1'b1;
                end

                burst_active       <= 1'b1;
                burst_resp_pending <= 1'b0;
                burst_beats_left   <= {1'b0, s_axi_awlen} + 1'b1;
                burst_bresp        <= AXI_RESP_OKAY;
                burst_error        <= 1'b0;

                if (s_axi_awburst != 2'b01)
                    burst_error <= 1'b1;

                if (s_axi_awaddr != expected_awaddr_reg)
                    burst_error <= 1'b1;

                if (total_beats_done + ({1'b0, s_axi_awlen} + 1'b1) > TOTAL_BEATS)
                    burst_error <= 1'b1;

                expected_awaddr_reg <= s_axi_awaddr + up_burst_bytes_ext;
            end

            // -------------------------------------------------
            // Allocate next downstream child burst for CURRENT upstream burst
            // -------------------------------------------------
            if (burst_active && !child_active && (burst_beats_left != 0)) begin
                child_active      <= 1'b1;
                child_aw_done     <= 1'b0;
                child_wait_b      <= 1'b0;
                child_part        <= active_part;
                child_start_beat  <= beat_in_part;
                child_beats_total <= next_child_beats;
                child_beats_left  <= next_child_beats;
            end

            // -------------------------------------------------
            // Downstream child AW handshake
            // -------------------------------------------------
            if (child_aw_fire) begin
                child_aw_done <= 1'b1;
            end

            // -------------------------------------------------
            // Accepted W beat
            // -------------------------------------------------
            if (child_w_fire) begin
                // Upstream burst bookkeeping
                if (burst_beats_left == 1) begin
                    if (!s_axi_wlast)
                        burst_error <= 1'b1;

                    burst_beats_left   <= 9'd0;
                    burst_active       <= 1'b0;
                    burst_resp_pending <= 1'b1;
                end else begin
                    if (s_axi_wlast)
                        burst_error <= 1'b1;

                    burst_beats_left <= burst_beats_left - 1'b1;
                end

                // Whole-transfer bookkeeping
                total_beats_done <= total_beats_done + 1'b1;

                if (beat_in_part == PARTITION_BEATS-1) begin
                    beat_in_part <= {BEAT_IDX_W{1'b0}};
                    if (active_part != NUM_PARTITIONS-1)
                        active_part <= active_part + 1'b1;
                end else begin
                    beat_in_part <= beat_in_part + 1'b1;
                end

                // Current child burst bookkeeping
                if (child_beats_left == 1) begin
                    child_beats_left <= 9'd0;
                    child_wait_b     <= 1'b1;
                end else begin
                    child_beats_left <= child_beats_left - 1'b1;
                end
            end

            // -------------------------------------------------
            // Downstream child B response
            // -------------------------------------------------
            if (child_b_fire) begin
                if (m_axi_bresp[child_part*2 +: 2] != AXI_RESP_OKAY)
                    burst_bresp <= m_axi_bresp[child_part*2 +: 2];

                child_active      <= 1'b0;
                child_aw_done     <= 1'b0;
                child_wait_b      <= 1'b0;
                child_beats_total <= {CHILD_BEAT_W{1'b0}};
                child_beats_left  <= {CHILD_BEAT_W{1'b0}};
            end

            // -------------------------------------------------
            // Upstream B handshake for THIS upstream burst
            // -------------------------------------------------
            if (s_axi_bvalid && s_axi_bready) begin
                burst_resp_pending <= 1'b0;

                // If whole vector write is complete, reset for the next one
                if (transfer_done) begin
                    busy                <= 1'b0;
                    expected_awaddr_reg <= S_AXI_EXPECTED_AWADDR;
                    total_beats_done    <= {TOTAL_BEAT_W{1'b0}};
                    active_part         <= {PART_IDX_W{1'b0}};
                    beat_in_part        <= {BEAT_IDX_W{1'b0}};
                end

                burst_bresp <= AXI_RESP_OKAY;
                burst_error <= 1'b0;
            end
        end
    end

endmodule
