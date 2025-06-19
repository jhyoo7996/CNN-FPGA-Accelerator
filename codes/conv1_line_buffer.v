`timescale 1ns / 1ps

module conv1_line_buffer #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 28,
    parameter FIFO_DEPTH_LG2 = $clog2(FIFO_DEPTH)
)(
    input wire new_filter,
    input wire clk,
    input wire resetn,
    input wire data_push,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg data_rdy,
    output reg [DATA_WIDTH-1:0] data_out0, // oldest line (buf1)
    output reg [DATA_WIDTH-1:0] data_out1, // middle line (buf0)
    output reg [DATA_WIDTH-1:0] data_out2  // newest line (data_in)
);

    // Counters for each buffer
    reg [FIFO_DEPTH_LG2:0] buf0_cnt, buf1_cnt;

    // Write and Read Pointers
    reg [FIFO_DEPTH_LG2-1:0] wr_ptr, rd_ptr;

    // FIFO buffer outputs
    wire [DATA_WIDTH-1:0] buf0_data_out;
    wire [DATA_WIDTH-1:0] buf1_data_out;

    // FIFO buffer write enables
    wire buf0_write_en = data_push;
    wire buf1_write_en = (buf0_cnt >= FIFO_DEPTH) && data_push;

    // FIFO buffer read enables
    wire buf0_read_en = (buf0_cnt >= FIFO_DEPTH - 2) && data_push;
    wire buf1_read_en = (buf1_cnt >= FIFO_DEPTH - 2) && data_push; // have 2 cycle delay. 

    // FIFO buffer instantiations
    // This fifo uses core output register -> have 2 cycle delay
    FIFO28 buf0 (
        .clka(clk), .ena(buf0_write_en), .wea(buf0_write_en), .addra(wr_ptr), .dina(data_in),
        .clkb(clk), .enb(buf0_read_en), .addrb(rd_ptr), .doutb(buf0_data_out)
    );
    FIFO28 buf1 (
        .clka(clk), .ena(buf1_write_en), .wea(buf1_write_en), .addra(wr_ptr), .dina(buf0_data_out),
        .clkb(clk), .enb(buf1_read_en), .addrb(rd_ptr), .doutb(buf1_data_out)
    );

    // Buffer counters
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            buf0_cnt <= 0;
            buf1_cnt <= 0;
        end else if (new_filter) begin
            buf0_cnt <= 0;
            buf1_cnt <= 0;
        end else if (data_push) begin
            if (buf0_cnt < FIFO_DEPTH)
                buf0_cnt <= buf0_cnt + 1;
            if (buf1_write_en && buf1_cnt < FIFO_DEPTH)
                buf1_cnt <= buf1_cnt + 1;
        end 
    end

    // Write pointer logic
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            wr_ptr <= 0;
        else if (new_filter) begin
            wr_ptr <= 0;
        end else if (buf0_write_en|| buf1_write_en)
            // Increment write pointer, wrap around if it reaches FIFO_DEPTH
            wr_ptr <= (wr_ptr == FIFO_DEPTH-1) ? 0 : wr_ptr + 1;
    end

    // Read pointer logic
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            rd_ptr <= 0;
        else if (new_filter) begin
            rd_ptr <= 0;
        end else if (buf0_read_en|| buf1_read_en)
            rd_ptr <= (rd_ptr == FIFO_DEPTH-1) ? 0 : rd_ptr + 1;
    end

    // Output logic
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            data_rdy  <= 0;
            data_out0 <= 0;
            data_out1 <= 0;
            data_out2 <= 0;
        end else if (buf0_cnt >= FIFO_DEPTH && buf1_cnt >= FIFO_DEPTH && data_push) begin
            data_rdy  <= 1;
            data_out0 <= buf1_data_out;
            data_out1 <= buf0_data_out;
            data_out2 <= data_in;
        end else begin
            data_rdy  <= 0;
            data_out0 <= 0;
            data_out1 <= 0;
            data_out2 <= 0;
        end
    end

endmodule
