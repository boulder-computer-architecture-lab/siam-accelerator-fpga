`timescale 1ns / 1ps

module pow #(
    parameter DATA_WIDTH = 64
)(

    input  wire                  clk,
    input  wire                  rstn,

    // Input stream 1 (base)
    input  wire [DATA_WIDTH-1:0] s_axis_1_tdata,
    input  wire                  s_axis_1_tvalid,
    output wire                  s_axis_1_tready,
    input  wire                  s_axis_1_tlast,

    // Input stream 2 (exponent)
    input  wire [DATA_WIDTH-1:0] s_axis_2_tdata,
    input  wire                  s_axis_2_tvalid,
    output wire                  s_axis_2_tready,
    
    // Result stream
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast

);

    // Computes x^y for fp x and y
    // with Xilinx floating point IPs
    // using the property that 
    // x^y = e^(y*ln(x))

    wire [DATA_WIDTH-1:0] log_out_tdata;
    wire                  log_out_tvalid;
    wire                  log_out_tready;
    wire                  log_out_tlast;

    wire [DATA_WIDTH-1:0] mult_out_tdata;
    wire                  mult_out_tvalid;
    wire                  mult_out_tready;
    wire                  mult_out_tlast;

    generate
        if (DATA_WIDTH == 64) begin

            // input: x [s_axis_1]
            // out:   ln(x)
            fp64_log log(
                .aclk(clk), .aresetn(rstn),

                .s_axis_a_tvalid(s_axis_1_tvalid),
                .s_axis_a_tready(s_axis_1_tready),
                .s_axis_a_tdata (s_axis_1_tdata),
                .s_axis_a_tlast (s_axis_1_tlast),

                .m_axis_result_tdata (log_out_tdata),
                .m_axis_result_tvalid(log_out_tvalid),
                .m_axis_result_tready(log_out_tready),
                .m_axis_result_tlast (log_out_tlast)
            );

            // inputs: ln(x), y [s_axis_2]
            // out:    y*ln(x)
            fp64_mult mult(
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (log_out_tdata),
                .s_axis_a_tvalid(log_out_tvalid),
                .s_axis_a_tready(log_out_tready),
                .s_axis_a_tlast (log_out_tlast),

                .s_axis_b_tdata (s_axis_2_tdata),
                .s_axis_b_tvalid(s_axis_2_tvalid),
                .s_axis_b_tready(s_axis_2_tready),

                .m_axis_result_tdata (mult_out_tdata),
                .m_axis_result_tvalid(mult_out_tvalid),
                .m_axis_result_tready(mult_out_tready),
                .m_axis_result_tlast (mult_out_tlast)
            );

            // input: y*ln(x)
            // out:   e^(y*ln(x)) = x^y
            fp64_exp exp(
                .aclk(clk), .aresetn(rstn),

                .s_axis_a_tdata(mult_out_tdata),
                .s_axis_a_tvalid(mult_out_tvalid),
                .s_axis_a_tready(mult_out_tready),
                .s_axis_a_tlast(mult_out_tlast),

                .m_axis_result_tdata(m_axis_tdata),
                .m_axis_result_tvalid(m_axis_tvalid),
                .m_axis_result_tready(m_axis_tready),
                .m_axis_result_tlast(m_axis_tlast)
            );
        
        end else if (DATA_WIDTH == 32) begin

            // input: x [s_axis_1]
            // out:   ln(x)
            fp32_log log(
                .aclk(clk), .aresetn(rstn),

                .s_axis_a_tvalid(s_axis_1_tvalid),
                .s_axis_a_tready(s_axis_1_tready),
                .s_axis_a_tdata (s_axis_1_tdata),
                .s_axis_a_tlast (s_axis_1_tlast),

                .m_axis_result_tdata (log_out_tdata),
                .m_axis_result_tvalid(log_out_tvalid),
                .m_axis_result_tready(log_out_tready),
                .m_axis_result_tlast (log_out_tlast)
            );

            // inputs: ln(x), y [s_axis_2]
            // out:    y*ln(x)
            fp32_mult mult(
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (log_out_tdata),
                .s_axis_a_tvalid(log_out_tvalid),
                .s_axis_a_tready(log_out_tready),
                .s_axis_a_tlast (log_out_tlast),

                .s_axis_b_tdata (s_axis_2_tdata),
                .s_axis_b_tvalid(s_axis_2_tvalid),
                .s_axis_b_tready(s_axis_2_tready),

                .m_axis_result_tdata (mult_out_tdata),
                .m_axis_result_tvalid(mult_out_tvalid),
                .m_axis_result_tready(mult_out_tready),
                .m_axis_result_tlast (mult_out_tlast)
            );

            // input: y*ln(x)
            // out:   e^(y*ln(x)) = x^y
            fp32_exp exp(
                .aclk(clk), .aresetn(rstn),

                .s_axis_a_tdata(mult_out_tdata),
                .s_axis_a_tvalid(mult_out_tvalid),
                .s_axis_a_tready(mult_out_tready),
                .s_axis_a_tlast(mult_out_tlast),

                .m_axis_result_tdata(m_axis_tdata),
                .m_axis_result_tvalid(m_axis_tvalid),
                .m_axis_result_tready(m_axis_tready),
                .m_axis_result_tlast(m_axis_tlast)
            );

        end else if (DATA_WIDTH == 16) begin

            // input: x [s_axis_1]
            // out:   ln(x)
            fp16_log log(
                .aclk(clk), .aresetn(rstn),

                .s_axis_a_tvalid(s_axis_1_tvalid),
                .s_axis_a_tready(s_axis_1_tready),
                .s_axis_a_tdata (s_axis_1_tdata),
                .s_axis_a_tlast (s_axis_1_tlast),

                .m_axis_result_tdata (log_out_tdata),
                .m_axis_result_tvalid(log_out_tvalid),
                .m_axis_result_tready(log_out_tready),
                .m_axis_result_tlast (log_out_tlast)
            );

            // inputs: ln(x), y [s_axis_2]
            // out:    y*ln(x)
            fp16_mult mult(
                .aclk(clk), .aresetn(rstn),
                
                .s_axis_a_tdata (log_out_tdata),
                .s_axis_a_tvalid(log_out_tvalid),
                .s_axis_a_tready(log_out_tready),
                .s_axis_a_tlast (log_out_tlast),

                .s_axis_b_tdata (s_axis_2_tdata),
                .s_axis_b_tvalid(s_axis_2_tvalid),
                .s_axis_b_tready(s_axis_2_tready),

                .m_axis_result_tdata (mult_out_tdata),
                .m_axis_result_tvalid(mult_out_tvalid),
                .m_axis_result_tready(mult_out_tready),
                .m_axis_result_tlast (mult_out_tlast)
            );

            // input: y*ln(x)
            // out:   e^(y*ln(x)) = x^y
            fp16_exp exp(
                .aclk(clk), .aresetn(rstn),

                .s_axis_a_tdata(mult_out_tdata),
                .s_axis_a_tvalid(mult_out_tvalid),
                .s_axis_a_tready(mult_out_tready),
                .s_axis_a_tlast(mult_out_tlast),

                .m_axis_result_tdata(m_axis_tdata),
                .m_axis_result_tvalid(m_axis_tvalid),
                .m_axis_result_tready(m_axis_tready),
                .m_axis_result_tlast(m_axis_tlast)
            );

        end

    endgenerate

endmodule
