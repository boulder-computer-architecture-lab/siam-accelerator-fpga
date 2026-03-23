`timescale 1ns / 1ps

module err #(
    parameter DATA_WIDTH = 64
)(

    input  wire                  clk,
    input  wire                  rstn,

    // Input stream 1 
    input  wire [DATA_WIDTH-1:0] s_axis_1_tdata,
    input  wire                  s_axis_1_tvalid,
    output wire                  s_axis_1_tready,
    input  wire                  s_axis_1_tlast,

    // Input stream 2
    input  wire [DATA_WIDTH-1:0] s_axis_2_tdata,
    input  wire                  s_axis_2_tvalid,
    output wire                  s_axis_2_tready,
    
    // Result stream
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready

);

    // Computes squared error:
    // for fp input vectors x and y,
    // returns sum((x_i-y_i)^2)

    wire [DATA_WIDTH-1:0] sub_out_tdata;
    wire                  sub_out_tvalid;
    wire                  sub_out_tready;
    wire                  sub_out_tlast;

    wire [DATA_WIDTH-1:0] mult_out_tdata;
    wire                  mult_out_tvalid;
    wire                  mult_out_tready;
    wire                  mult_out_tlast;

    generate
        if (DATA_WIDTH == 64) begin
            fp64_sub sub (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (s_axis_1_tdata),
                .s_axis_a_tvalid(s_axis_1_tvalid),
                .s_axis_a_tready(s_axis_1_tready),
                .s_axis_a_tlast (s_axis_1_tlast),

                .s_axis_b_tdata (s_axis_2_tdata),
                .s_axis_b_tvalid(s_axis_2_tvalid),
                .s_axis_b_tready(s_axis_2_tready),

                .m_axis_result_tdata (sub_out_tdata),
                .m_axis_result_tvalid(sub_out_tvalid),
                .m_axis_result_tready(sub_out_tready),
                .m_axis_result_tlast (sub_out_tlast)
            );

            fp64_mult sq (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (sub_out_tdata),
                .s_axis_a_tvalid(sub_out_tvalid),
                .s_axis_a_tready(sub_out_tready),
                .s_axis_a_tlast (sub_out_tlast),

                .s_axis_b_tdata (sub_out_tdata),
                .s_axis_b_tvalid(sub_out_tvalid),
                .s_axis_b_tready(sub_out_tready),

                .m_axis_result_tdata (mult_out_tdata),
                .m_axis_result_tvalid(mult_out_tvalid),
                .m_axis_result_tready(mult_out_tready),
                .m_axis_result_tlast (mult_out_tlast)
            );

            fp64_accum acc (
                .aclk(clk), .aresetn(rstn),
            
                .s_axis_a_tdata (mult_out_tdata),
                .s_axis_a_tvalid(mult_out_tvalid),
                .s_axis_a_tready(mult_out_tready),
                .s_axis_a_tlast (mult_out_tlast),
            
                .m_axis_result_tdata (m_axis_tdata),
                .m_axis_result_tvalid(m_axis_tvalid),
                .m_axis_result_tready(m_axis_tready),
                .m_axis_result_tlast ()
            );
        
        end else if (DATA_WIDTH == 32) begin
            fp32_sub sub (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (s_axis_1_tdata),
                .s_axis_a_tvalid(s_axis_1_tvalid),
                .s_axis_a_tready(s_axis_1_tready),
                .s_axis_a_tlast (s_axis_1_tlast),

                .s_axis_b_tdata (s_axis_2_tdata),
                .s_axis_b_tvalid(s_axis_2_tvalid),
                .s_axis_b_tready(s_axis_2_tready),

                .m_axis_result_tdata (sub_out_tdata),
                .m_axis_result_tvalid(sub_out_tvalid),
                .m_axis_result_tready(sub_out_tready),
                .m_axis_result_tlast (sub_out_tlast)
            );

            fp32_mult sq (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (sub_out_tdata),
                .s_axis_a_tvalid(sub_out_tvalid),
                .s_axis_a_tready(sub_out_tready),
                .s_axis_a_tlast (sub_out_tlast),

                .s_axis_b_tdata (sub_out_tdata),
                .s_axis_b_tvalid(sub_out_tvalid),
                .s_axis_b_tready(sub_out_tready),

                .m_axis_result_tdata (mult_out_tdata),
                .m_axis_result_tvalid(mult_out_tvalid),
                .m_axis_result_tready(mult_out_tready),
                .m_axis_result_tlast (mult_out_tlast)
            );

            fp32_accum acc (
                .aclk(clk), .aresetn(rstn),
            
                .s_axis_a_tdata (mult_out_tdata),
                .s_axis_a_tvalid(mult_out_tvalid),
                .s_axis_a_tready(mult_out_tready),
                .s_axis_a_tlast (mult_out_tlast),
            
                .m_axis_result_tdata (m_axis_tdata),
                .m_axis_result_tvalid(m_axis_tvalid),
                .m_axis_result_tready(m_axis_tready),
                .m_axis_result_tlast ()
            );

        end else if (DATA_WIDTH == 16) begin
            fp16_sub sub (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (s_axis_1_tdata),
                .s_axis_a_tvalid(s_axis_1_tvalid),
                .s_axis_a_tready(s_axis_1_tready),
                .s_axis_a_tlast (),

                .s_axis_b_tdata (s_axis_2_tdata),
                .s_axis_b_tvalid(s_axis_2_tvalid),
                .s_axis_b_tready(s_axis_2_tready),

                .m_axis_result_tdata (sub_out_tdata),
                .m_axis_result_tvalid(sub_out_tvalid),
                .m_axis_result_tready(sub_out_tready),
                .m_axis_result_tlast ()
            );

            fp16_mult sq (
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (sub_out_tdata),
                .s_axis_a_tvalid(sub_out_tvalid),
                .s_axis_a_tready(sub_out_tready),
                .s_axis_a_tlast (),

                .s_axis_b_tdata (sub_out_tdata),
                .s_axis_b_tvalid(sub_out_tvalid),
                .s_axis_b_tready(sub_out_tready),

                .m_axis_result_tdata (mult_out_tdata),
                .m_axis_result_tvalid(mult_out_tvalid),
                .m_axis_result_tready(mult_out_tready),
                .m_axis_result_tlast ()
            );

            fp16_accum acc (
                .aclk(clk), .aresetn(rstn),
            
                .s_axis_a_tdata (mult_out_tdata),
                .s_axis_a_tvalid(mult_out_tvalid),
                .s_axis_a_tready(mult_out_tready),
                .s_axis_a_tlast (mult_out_tlast),
            
                .m_axis_result_tdata (m_axis_tdata),
                .m_axis_result_tvalid(m_axis_tvalid),
                .m_axis_result_tready(m_axis_tready),
                .m_axis_result_tlast ()
            );

        end
    endgenerate
endmodule
