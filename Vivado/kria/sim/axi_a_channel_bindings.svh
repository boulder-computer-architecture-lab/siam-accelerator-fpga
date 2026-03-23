`define CHANNEL_0 \
    .s_axis_a_0_tdata(s_axis_a_tdata[0]), \
    .s_axis_a_0_tvalid(s_axis_a_tvalid[0]), \
    .s_axis_a_0_tready(s_axis_a_tready[0]), \
    .s_axis_a_0_tlast(s_axis_a_tlast[0]), \
    .m_axis_0_tdata(m_axis_tdata[0]), \
    .m_axis_0_tvalid(m_axis_tvalid[0]), \
    .m_axis_0_tready(m_axis_tready[0]), \
    .m_axis_0_tlast(m_axis_tlast[0]),

`define CHANNEL_1 \
    .s_axis_a_1_tdata(s_axis_a_tdata[1]), \
    .s_axis_a_1_tvalid(s_axis_a_tvalid[1]), \
    .s_axis_a_1_tready(s_axis_a_tready[1]), \
    .s_axis_a_1_tlast(s_axis_a_tlast[1]), \
    .m_axis_1_tdata(m_axis_tdata[1]), \
    .m_axis_1_tvalid(m_axis_tvalid[1]), \
    .m_axis_1_tready(m_axis_tready[1]), \
    .m_axis_1_tlast(m_axis_tlast[1]),

`define CHANNEL_2 \
    .s_axis_a_2_tdata(s_axis_a_tdata[2]), \
    .s_axis_a_2_tvalid(s_axis_a_tvalid[2]), \
    .s_axis_a_2_tready(s_axis_a_tready[2]), \
    .s_axis_a_2_tlast(s_axis_a_tlast[2]), \
    .m_axis_2_tdata(m_axis_tdata[2]), \
    .m_axis_2_tvalid(m_axis_tvalid[2]), \
    .m_axis_2_tready(m_axis_tready[2]), \
    .m_axis_2_tlast(m_axis_tlast[2]),

`define CHANNEL_3 \
    .s_axis_a_3_tdata(s_axis_a_tdata[3]), \
    .s_axis_a_3_tvalid(s_axis_a_tvalid[3]), \
    .s_axis_a_3_tready(s_axis_a_tready[3]), \
    .s_axis_a_3_tlast(s_axis_a_tlast[3]), \
    .m_axis_3_tdata(m_axis_tdata[3]), \
    .m_axis_3_tvalid(m_axis_tvalid[3]), \
    .m_axis_3_tready(m_axis_tready[3]), \
    .m_axis_3_tlast(m_axis_tlast[3]),

`define CHANNEL_4 \
    .s_axis_a_4_tdata(s_axis_a_tdata[4]), \
    .s_axis_a_4_tvalid(s_axis_a_tvalid[4]), \
    .s_axis_a_4_tready(s_axis_a_tready[4]), \
    .s_axis_a_4_tlast(s_axis_a_tlast[4]), \
    .m_axis_4_tdata(m_axis_tdata[4]), \
    .m_axis_4_tvalid(m_axis_tvalid[4]), \
    .m_axis_4_tready(m_axis_tready[4]), \
    .m_axis_4_tlast(m_axis_tlast[4]),

`define CHANNEL_5 \
    .s_axis_a_5_tdata(s_axis_a_tdata[5]), \
    .s_axis_a_5_tvalid(s_axis_a_tvalid[5]), \
    .s_axis_a_5_tready(s_axis_a_tready[5]), \
    .s_axis_a_5_tlast(s_axis_a_tlast[5]), \
    .m_axis_5_tdata(m_axis_tdata[5]), \
    .m_axis_5_tvalid(m_axis_tvalid[5]), \
    .m_axis_5_tready(m_axis_tready[5]), \
    .m_axis_5_tlast(m_axis_tlast[5]),

`define CHANNEL_6 \
    .s_axis_a_6_tdata(s_axis_a_tdata[6]), \
    .s_axis_a_6_tvalid(s_axis_a_tvalid[6]), \
    .s_axis_a_6_tready(s_axis_a_tready[6]), \
    .s_axis_a_6_tlast(s_axis_a_tlast[6]), \
    .m_axis_6_tdata(m_axis_tdata[6]), \
    .m_axis_6_tvalid(m_axis_tvalid[6]), \
    .m_axis_6_tready(m_axis_tready[6]), \
    .m_axis_6_tlast(m_axis_tlast[6]),

`define CHANNEL_7 \
    .s_axis_a_7_tdata(s_axis_a_tdata[7]), \
    .s_axis_a_7_tvalid(s_axis_a_tvalid[7]), \
    .s_axis_a_7_tready(s_axis_a_tready[7]), \
    .s_axis_a_7_tlast(s_axis_a_tlast[7]), \
    .m_axis_7_tdata(m_axis_tdata[7]), \
    .m_axis_7_tvalid(m_axis_tvalid[7]), \
    .m_axis_7_tready(m_axis_tready[7]), \
    .m_axis_7_tlast(m_axis_tlast[7]),

`define CHANNELS_1 `CHANNEL_0
`define CHANNELS_2 `CHANNEL_0 `CHANNEL_1
`define CHANNELS_3 `CHANNEL_0 `CHANNEL_1 `CHANNEL_2
`define CHANNELS_4 `CHANNEL_0 `CHANNEL_1 `CHANNEL_2 `CHANNEL_3
`define CHANNELS_5 `CHANNEL_0 `CHANNEL_1 `CHANNEL_2 `CHANNEL_3 `CHANNEL_4
`define CHANNELS_6 `CHANNEL_0 `CHANNEL_1 `CHANNEL_2 `CHANNEL_3 `CHANNEL_4 `CHANNEL_5
`define CHANNELS_7 `CHANNEL_0 `CHANNEL_1 `CHANNEL_2 `CHANNEL_3 `CHANNEL_4 `CHANNEL_5 `CHANNEL_6
`define CHANNELS_8 `CHANNEL_0 `CHANNEL_1 `CHANNEL_2 `CHANNEL_3 `CHANNEL_4 `CHANNEL_5 `CHANNEL_6 `CHANNEL_7