`timescale 1ns / 1ps

module dot_product #(
    parameter DATA_WIDTH = 64,
    parameter WORDS_PER_ROW = 17048,
    parameter ROWS_PER_CHANNEL = 4262
)(
    input wire clk,
    input wire rstn,

    // Input stream A
    input  wire [DATA_WIDTH-1:0] s_axis_a_tdata,
    input  wire                  s_axis_a_tvalid,
    output wire                  s_axis_a_tready,
    input  wire                  s_axis_a_tlast,

    // Input stream B
    input  wire [DATA_WIDTH-1:0] s_axis_b_tdata,
    input  wire                  s_axis_b_tvalid,
    output wire                  s_axis_b_tready,

    // Output stream
    output reg  [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                   m_axis_tvalid,
    input  wire                  m_axis_tready,
    output reg                   m_axis_tlast
);

    // Removes some simualtion warnings
    wire [DATA_WIDTH-1:0] s_axis_a_tdata_int = s_axis_a_tvalid ? s_axis_a_tdata : {DATA_WIDTH{1'b0}};
    wire [DATA_WIDTH-1:0] s_axis_b_tdata_int = s_axis_b_tvalid ? s_axis_b_tdata : {DATA_WIDTH{1'b0}};
  
    // ========================================
    //            INSTANTIATE MACs
    // ========================================   
     
    // Multiplier output
    wire [DATA_WIDTH-1:0] fp_axis_a_tdata;
    wire                  fp_axis_a_tvalid;
    wire                  fp_axis_a_tready;
    wire                  fp_axis_a_tlast;

    // Accumulator input
    wire [DATA_WIDTH-1:0] acc_axis_a_tdata;
    wire                  acc_axis_a_tvalid;
    wire                  acc_axis_a_tready;
    wire                  acc_axis_a_tlast;
    
    // Accumulator output
    wire [DATA_WIDTH-1:0] acc_axis_result_tdata;
    wire                  acc_axis_result_tvalid;
    wire                  acc_axis_result_tready;
    wire                  acc_axis_result_tlast;

    generate
        if (DATA_WIDTH == 16) begin

            fp16_mult u_fp16_mult (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (s_axis_a_tdata_int),
                .s_axis_a_tvalid(s_axis_a_tvalid   ),
                .s_axis_a_tready(s_axis_a_tready   ),
                .s_axis_a_tlast (s_axis_a_tlast    ),

                .s_axis_b_tdata (s_axis_b_tdata_int),
                .s_axis_b_tvalid(s_axis_b_tvalid   ),
                .s_axis_b_tready(s_axis_b_tready   ),

                .m_axis_result_tdata (fp_axis_a_tdata ),
                .m_axis_result_tvalid(fp_axis_a_tvalid),
                .m_axis_result_tready(fp_axis_a_tready),
                .m_axis_result_tlast (fp_axis_a_tlast )
            );

            assign acc_axis_a_tdata = fp_axis_a_tdata;
            assign acc_axis_a_tvalid = fp_axis_a_tvalid;
            assign fp_axis_a_tready = acc_axis_a_tready;

            fp16_accum u_fp16_accum (
                .aclk(clk), .aresetn(rstn),
            
                .s_axis_a_tdata (acc_axis_a_tdata ),
                .s_axis_a_tvalid(acc_axis_a_tvalid),
                .s_axis_a_tready(acc_axis_a_tready),
                .s_axis_a_tlast (acc_axis_a_tlast ),
            
                .m_axis_result_tdata (acc_axis_result_tdata ),
                .m_axis_result_tvalid(acc_axis_result_tvalid),
                .m_axis_result_tready(acc_axis_result_tready),
                .m_axis_result_tlast (acc_axis_result_tlast )
            );

        end else if (DATA_WIDTH == 32) begin

            fp32_mult u_fp32_mult (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (s_axis_a_tdata_int),
                .s_axis_a_tvalid(s_axis_a_tvalid   ),
                .s_axis_a_tready(s_axis_a_tready   ),
                .s_axis_a_tlast (s_axis_a_tlast    ),

                .s_axis_b_tdata (s_axis_b_tdata_int),
                .s_axis_b_tvalid(s_axis_b_tvalid   ),
                .s_axis_b_tready(s_axis_b_tready   ),

                .m_axis_result_tdata (fp_axis_a_tdata ),
                .m_axis_result_tvalid(fp_axis_a_tvalid),
                .m_axis_result_tready(fp_axis_a_tready),
                .m_axis_result_tlast (fp_axis_a_tlast )
            );

            assign acc_axis_a_tdata = fp_axis_a_tdata;
            assign acc_axis_a_tvalid = fp_axis_a_tvalid;
            assign fp_axis_a_tready = acc_axis_a_tready;

            fp32_accum u_fp32_accum (
                .aclk(clk), .aresetn(rstn),
            
                .s_axis_a_tdata (acc_axis_a_tdata ),
                .s_axis_a_tvalid(acc_axis_a_tvalid),
                .s_axis_a_tready(acc_axis_a_tready),
                .s_axis_a_tlast (acc_axis_a_tlast ),
            
                .m_axis_result_tdata (acc_axis_result_tdata ),
                .m_axis_result_tvalid(acc_axis_result_tvalid),
                .m_axis_result_tready(acc_axis_result_tready),
                .m_axis_result_tlast (acc_axis_result_tlast )
            );

        end else if (DATA_WIDTH == 64) begin

            fp64_mult u_fp64_mult (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (s_axis_a_tdata_int),
                .s_axis_a_tvalid(s_axis_a_tvalid   ),
                .s_axis_a_tready(s_axis_a_tready   ),
                .s_axis_a_tlast (s_axis_a_tlast    ),

                .s_axis_b_tdata (s_axis_b_tdata_int),
                .s_axis_b_tvalid(s_axis_b_tvalid   ),
                .s_axis_b_tready(s_axis_b_tready   ),

                .m_axis_result_tdata (fp_axis_a_tdata ),
                .m_axis_result_tvalid(fp_axis_a_tvalid),
                .m_axis_result_tready(fp_axis_a_tready),
                .m_axis_result_tlast (fp_axis_a_tlast )
            );

            assign acc_axis_a_tdata = fp_axis_a_tdata;
            assign acc_axis_a_tvalid = fp_axis_a_tvalid;
            assign fp_axis_a_tready = acc_axis_a_tready;

            fp64_accum u_fp64_accum (
                .aclk(clk), .aresetn(rstn),
            
                .s_axis_a_tdata (acc_axis_a_tdata ),
                .s_axis_a_tvalid(acc_axis_a_tvalid),
                .s_axis_a_tready(acc_axis_a_tready),
                .s_axis_a_tlast (acc_axis_a_tlast ),
            
                .m_axis_result_tdata (acc_axis_result_tdata ),
                .m_axis_result_tvalid(acc_axis_result_tvalid),
                .m_axis_result_tready(acc_axis_result_tready),
                .m_axis_result_tlast (acc_axis_result_tlast )
            );

        end
    endgenerate
    
    // ========================================
    //             TLAST HANDLING
    // ========================================
    
    // Accumulator input tlast (per row).
    // Used to reset the accumulated value
    reg [$clog2(WORDS_PER_ROW)-1:0] word_count_in;
    
    wire handshake_in = acc_axis_a_tready && acc_axis_a_tvalid;
    wire last_in = (word_count_in == WORDS_PER_ROW - 1);
    
    always @(posedge clk) begin
        if (!rstn) begin
            word_count_in <= 0;
        end else begin
            if (handshake_in) begin
                if (last_in)
                    word_count_in <= 0;
                else
                    word_count_in <= word_count_in + 1;
            end
        end
    end
    
    assign acc_axis_a_tlast = (last_in && handshake_in);

    // Accumulator output tlast (after all rows)
    reg [$clog2(ROWS_PER_CHANNEL)-1:0] word_count_out;
    
    wire handshake_out = m_axis_tready && m_axis_tvalid;
    wire last_out = (word_count_out == ROWS_PER_CHANNEL-1);

    always @(posedge clk) begin
        if (!rstn) begin
            word_count_out <= 0;
        end else if (handshake_out) begin
            if (last_out)
                word_count_out <= 0;
            else
                word_count_out <= word_count_out + 1;
        end
    end
    
    // ========================================
    // Forward output
    
    always @(posedge clk) begin
        if (!rstn) begin
            m_axis_tdata  <= 64'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            if (acc_axis_result_tvalid && acc_axis_result_tready) begin
                if (acc_axis_result_tlast) begin
                    m_axis_tdata  <= acc_axis_result_tdata;
                    m_axis_tvalid <= 1'b1;
                    m_axis_tlast  <= last_out;
                end
            end
    
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end
        end
    end
    
    assign acc_axis_result_tready = !m_axis_tvalid || (m_axis_tvalid && m_axis_tready);

endmodule
