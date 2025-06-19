`timescale 1ns / 1ps


module weight_distributer(
    input wire clk,
    input wire resetn,
    input wire start,
    output wire done,

    // Source BRAM (conv1, conv2, fc weight memory) Interface (Read)
    // bitwidth = 8, depth = 24264
    output  wire                wmem_enb,     
    output  wire [14:0]         wmem_addrb,    
    input   wire signed [7:0]   wmem_doutb,   

    // Destination BRAMs Interface (Write) 
    // bitwidth = 2304, depth = 85
    output  wire [11:0]         omem_addra,  
    output  wire [71:0]         omem_dina,  // bitwidth = 72, depth = 2720
    output  wire                omem_wea,   // no Byte Write Enable 
    output  wire                omem_ena   
    );
    // ===============================================================
    // CONTENTS
    // 
    // 1. FSM
    // 2. main BRAM Read Access
    // 3. Destination BRAM Write Access
    // 4. 
    //
    // ===============================================================

    // ========== 1. FSM =============================================
    // states
    localparam IDLE = 0;
    localparam CONV1 = 1;
    localparam CONV2 = 2;
    localparam FC = 3;
    localparam DONE = 4;

    reg [2:0] state, n_state;

    // FSM control logic
    always @(*) begin
        case (state)
            IDLE: n_state = start ? CONV1 : IDLE;
            CONV1: n_state = (main_addr == 15'd71+2) ? CONV2 : CONV1;  // conv1 weights: 71 = 8*3*3 - 1
            CONV2: n_state = (main_addr == 15'd1223+2) ? FC : CONV2;  // conv2 weights: 1223 = 8*16*3*3 + 71
            FC: n_state = (main_addr == 15'd24263+2) ? DONE : FC;  // fc weights: 24263 = 2304*10 +1223
            DONE: n_state = DONE;
            default: n_state = IDLE;
        endcase
    end

    // FSM update
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
        end else begin
            state <= n_state;
        end
    end

    // delayed state
    reg [2:0] state_d;
    always @(posedge clk) begin
        state_d <= state;
    end

    // done_state signal: done_state edge detection
    reg real_done;
    reg pseudo_done;
    // real_done signal: Operation completion signal
    always @(posedge clk) begin
        real_done <= (state == DONE);
    end
    // real_done edge detection
    reg real_done_d;
    wire real_done_edge;
    always @(posedge clk) begin
        real_done_d <= real_done;
    end
    assign real_done_edge = real_done && !real_done_d;
    // pseudo_done signal: just pass start signal to fc_layer
    always @(posedge clk) begin
        pseudo_done <= (state == DONE) && start;
    end
    // output done signal
    assign done = real_done_edge | pseudo_done;
    // ===============================================================


    // ========== 2. main BRAM Read Access ===========================
    // read data enable
    // reg read_data_enb;
    // always @(posedge clk) begin
    //     if (state == IDLE || state == DONE) begin
    //         read_data_enb <= 0;
    //     end else if (start) begin
    //         read_data_enb <= 1; 
    //     end 
    // end
    assign wmem_enb = (state != IDLE && state != DONE) && !main_addr_max;

    // main_addr counter
    reg [14:0] main_addr;  // wmem access address. 0~24263. increase at each cycle.
    always @(posedge clk) begin
        if (state != IDLE && state != DONE) begin
            if (main_addr < 15'd24263+2 && main_addr_max == 0)
                main_addr <= main_addr + 1;  // 0~24263. increase at each cycle.
            else begin 
                main_addr <= 0;
            end
        end else begin
            main_addr <= 0;
        end
    end
    reg main_addr_max;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            main_addr_max <= 0;
        end else begin
            if (main_addr == 15'd24263+2)
                main_addr_max <= 1; // ?ú†Ïß?. -> resetn ?êòÎ©? Ï¥àÍ∏∞?ôî. 
        end
    end
    assign wmem_addrb = main_addr;
    
    // read data storing buffer, for write bitwidth = 72.
    reg [7:0] read_data_buffer [0:8];     // read data buffer size: 9Byte.
    reg [3:0] read_data_buffer_cnt;  // 0~8. 0~7: read data buffer. 8: read data buffer is full.

    always @(posedge clk) begin
        read_data_buffer_cnt <= (state_d == IDLE || state_d == DONE) ? 0 : (read_data_buffer_cnt == 4'd8) ? 0 : read_data_buffer_cnt + 1;  // 1cycle delay since read delay. increase at each cycle. 8: read data buffer is full.
        read_data_buffer[read_data_buffer_cnt] <= wmem_doutb;  // fill data at each cycle.
    end
    // ===============================================================


    // ========== 3. Destination BRAM Write Access ===================
    // write data enable
    reg write_data_enb;
    always @(posedge clk) begin
        write_data_enb <= (read_data_buffer_cnt == 4'd8);  // write data enable. 8: read data buffer is full.
    end
    assign omem_wea = write_data_enb;
    assign omem_ena = write_data_enb;

    // write cnt buffer
    reg [2:0] write_cnt_buffer;  // 0~7. since 576 = 8 * 72. 576 (=2304/4) is basic block for weight write.
    reg [3:0] cnt_wposition_conv2; // used at CONV2 state. 0~15. 
    reg [8:0] cnt_wposition_fc; // used at FC state. 0~319
    always @(posedge clk) begin
        write_cnt_buffer <= (state == IDLE) ? 0 : (write_data_enb) ? write_cnt_buffer + 1 : write_cnt_buffer;  // increase at each write enable.
        cnt_wposition_conv2 <= (state != CONV2) ? 0 : write_data_enb && (write_cnt_buffer == 3'd7) ? cnt_wposition_conv2 + 1 : cnt_wposition_conv2;  // used only at CONV2 state. increase at each write enable.
        cnt_wposition_fc <= (state != FC) ? 0 : write_data_enb && (write_cnt_buffer == 3'd7) ? cnt_wposition_fc + 1 : cnt_wposition_fc;  // used only at FC state. increase at each 8 write access.
    end

    // write address
    reg [11:0] write_address;  // 0~2719
    always @(*) begin
        case (state)
            IDLE: write_address = 0;
            CONV1: write_address = conv1_write_address_mapping(write_cnt_buffer);
            CONV2: write_address = conv2_write_address_mapping(write_cnt_buffer, cnt_wposition_conv2);
            FC: write_address = fc_write_address_mapping(write_cnt_buffer, cnt_wposition_fc);
            default: write_address = 0;
        endcase
    end
    assign omem_addra = write_address;
    
    // write datas
    wire [71:0] write_data;
    assign omem_dina = {read_data_buffer[8], read_data_buffer[7], read_data_buffer[6], read_data_buffer[5], read_data_buffer[4], read_data_buffer[3], read_data_buffer[2], read_data_buffer[1], read_data_buffer[0]};
//    assign omem_dina = {read_data_buffer[0], read_data_buffer[1], read_data_buffer[2], read_data_buffer[3], read_data_buffer[4], read_data_buffer[5], read_data_buffer[6], read_data_buffer[7], read_data_buffer[8]};


    // >>> write address mapping function <<<
    function [11:0] conv1_write_address_mapping;
        input [3:0] cnt;
        begin
            conv1_write_address_mapping = cnt;
        end
    endfunction

    function [11:0] conv2_write_address_mapping;
        input [3:0] cnt;
        input [8:0] pos;
        begin
            conv2_write_address_mapping = cnt + 8 * pos + 32;
        end
    endfunction

    function [11:0] fc_write_address_mapping;
        input [3:0] cnt;
        input [8:0] pos;
        begin
//            fc_write_address_mapping = 160 + cnt + 32 * pos [2:0] + 8 * pos [4:3] + 256 * pos [8:5];  // position: 32 * (pos % 8) + 8 * ((pos // 8) % 4) + 256 * (pos // 32)
              fc_write_address_mapping = 160 + cnt + 32 * pos[0] + 8 * pos[2:1] + 64 * pos[8:3];
        end
    endfunction
    // ===============================================================


endmodule