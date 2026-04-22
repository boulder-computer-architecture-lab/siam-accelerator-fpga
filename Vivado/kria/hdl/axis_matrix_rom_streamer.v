`timescale 1ns / 1ps

module axis_matrix_rom_streamer #(
    parameter DATA_WIDTH    = 128,
    parameter DEPTH_WORDS   = 1024,
    parameter WORDS_PER_ROW = 24,
    parameter MEMFILE       = ""
)(
    input  wire                  clk,
    input  wire                  rstn,
    input  wire                  start,

    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast
);

    localparam ADDR_WIDTH        = (DEPTH_WORDS <= 1) ? 1 : $clog2(DEPTH_WORDS);
    localparam WORD_IN_ROW_WIDTH = (WORDS_PER_ROW <= 1) ? 1 : $clog2(WORDS_PER_ROW);

    (* rom_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH_WORDS-1];

    reg [ADDR_WIDTH-1:0]        rd_addr;
    reg [WORD_IN_ROW_WIDTH-1:0] word_in_row;
    reg                         active;

    initial begin
        if (MEMFILE != "") begin
            $readmemh(MEMFILE, mem);
        end
    end

    assign m_axis_tdata  = mem[rd_addr];
    assign m_axis_tvalid = active;
    assign m_axis_tlast  = active && (word_in_row == WORDS_PER_ROW-1);

    always @(posedge clk) begin
        if (!rstn) begin
            rd_addr      <= {ADDR_WIDTH{1'b0}};
            word_in_row  <= {WORD_IN_ROW_WIDTH{1'b0}};
            active       <= 1'b0;
        end else begin
            // Restart from the beginning on each start pulse.
            if (start) begin
                rd_addr     <= {ADDR_WIDTH{1'b0}};
                word_in_row <= {WORD_IN_ROW_WIDTH{1'b0}};
                active      <= 1'b1;
            end else if (active && m_axis_tvalid && m_axis_tready) begin
                if (rd_addr == DEPTH_WORDS-1) begin
                    rd_addr     <= {ADDR_WIDTH{1'b0}};
                    word_in_row <= {WORD_IN_ROW_WIDTH{1'b0}};
                    active      <= 1'b0;
                end else begin
                    rd_addr <= rd_addr + 1'b1;

                    if (word_in_row == WORDS_PER_ROW-1)
                        word_in_row <= {WORD_IN_ROW_WIDTH{1'b0}};
                    else
                        word_in_row <= word_in_row + 1'b1;
                end
            end
        end
    end

endmodule
