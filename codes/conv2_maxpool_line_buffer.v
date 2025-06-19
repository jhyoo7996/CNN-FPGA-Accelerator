`timescale 1ns / 1ps

module conv2_maxpool_line_buffer #(
    parameter DATA_WIDTH = 8,    // 8��Ʈ ������
    parameter FIFO_DEPTH = 12    // 12�� ������ ����
)(
    input wire new_filter,
    input wire clk,
    input wire resetn,
    input wire data_valid,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg maxpool_valid,
    output wire [DATA_WIDTH-1:0] maxpool_out
);

    reg [DATA_WIDTH-1:0] comparing_reg;
    reg [DATA_WIDTH-1:0] max_value;
    reg max_valid;
    reg window_cnt;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            comparing_reg <= 0;
            window_cnt <= 0;
            max_value <= 0;
            max_valid <= 0;
        end else if (new_filter) begin
            comparing_reg <= 0;
            window_cnt <= 0;
            max_value <= 0;
            max_valid <= 0;
        end else begin 
            if (data_valid) begin
                if (window_cnt == 0) begin
                    comparing_reg <= data_in;
                    window_cnt <= 1;
                    max_valid <= 0;
                end else if (window_cnt == 1) begin
                    window_cnt <= 0;
                    max_value <= (comparing_reg > data_in) ? comparing_reg : data_in;
                    max_valid <= 1;
                end
            end else begin
                max_valid <= 0;
                window_cnt <= 0;
                 
            end
        end
    end 
    
    

    /// larger value instanced upward ---------------------------------------------------
    /// actual line_buffer to do maxpooling downward ------------------------------------

    // FIFO ��� ���� �����Ϳ� ī����
    reg [3:0] wr_ptr, rd_ptr;  // 12�� �����͸� ���� 4��Ʈ ������
    reg [4:0] buf_cnt;         // FIFO �� ������ ���� ī��Ʈ

    // FIFO ���� ��ȣ
    wire buf_write_en = (buf_cnt < FIFO_DEPTH) && max_valid;
    wire buf_read_en = (buf_cnt < 2*FIFO_DEPTH - 1) && (buf_cnt >= FIFO_DEPTH-1) && max_valid; // 11 ���� ���� ���ķ� read en + 2clk delay

    // FIFO ���?
    wire [DATA_WIDTH-1:0] buf_data_out;
    reg [DATA_WIDTH-1:0] buf_data_out_reg;

    // FIFO �ν��Ͻ�ȭ 
    FIFO12 buf0 (
        .clka(clk), .ena(buf_write_en), .wea(buf_write_en), .addra(wr_ptr), .dina(max_value),
        .clkb(clk), .enb(buf_read_en), .addrb(rd_ptr), .doutb(buf_data_out)
    );
    
    always @(posedge clk or negedge resetn) begin 
        if(!resetn) begin 
            buf_data_out_reg <= 0;
        end else begin 
            buf_data_out_reg <= buf_data_out;
        end
    end

    // FIFO ī���� ����
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            buf_cnt <= 0;
        end else if (new_filter) begin
            buf_cnt <= 0; // new filter���� �ʱ�ȭȭ
        end else if (max_valid) begin
            if (buf_cnt < 2*FIFO_DEPTH-1) // 11 -> 12*2 = 24 therefore 23
                buf_cnt <= buf_cnt + 1; // ���� �ϴٰ� FIFO_DEPTH -1 �� ����
            else 
                buf_cnt <= 0;
        end
    end

    // ���� ������ ����
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            wr_ptr <= 0;
        else if (new_filter)
            wr_ptr <= 0;
        else if (buf_write_en)
            wr_ptr <= (wr_ptr == FIFO_DEPTH-1) ? 0 : wr_ptr + 1;
    end

    // �б� ������ ���� 
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            rd_ptr <= 0;
        else if (new_filter)
            rd_ptr <= 0;
        else if (buf_read_en)
            rd_ptr <= (rd_ptr == FIFO_DEPTH-1) ? 0 : rd_ptr + 1;
    end

    assign maxpool_out = (buf_data_out_reg > max_value) ? buf_data_out_reg : max_value;
        
    // ���? ����
    always@(posedge clk or negedge resetn) begin
        if (!resetn) begin
            maxpool_valid <= 0;
        end else if (new_filter) begin
            maxpool_valid <= 0;
        end else if (max_valid && (buf_cnt > FIFO_DEPTH-1) ) begin // every time new max_data is here with valid signal
            maxpool_valid <= 1;
        end else begin
            maxpool_valid <= 0;
        end
    end

endmodule