`timescale 1ns / 1ps

module fc_module (
    // Control signals
    input wire clk,
    input wire resetn,
    input wire start,
    output wire done,
    
    // IMEM port B (read) - conv2_omem. 4 parallel BRAMs. input/output of 4 BRAMs are concatenated in top_module.
    output reg imem_enb,
    output wire [2:0] imem_addrb,       // conv_mem depth = 8.
    input wire [4*576-1:0] imem_doutb,  // 4*576 = 4*(72x8). 4 parallel BRAMs, read width: 576 = 72x8.
    
    // WMEM port B (read) - wmem -> width: 2304, depth: 85. weight of fc layer is in 5~84
    output reg wmem_enb,
    output wire [6:0] wmem_addrb,       // address of wmem. 5~84.
    input wire [4*576-1:0] wmem_doutb,  // read width: 2304 bits. not bytes.
    
    // OMEM port A (write)
    output wire omem_ena,
    output wire omem_wea,
    output wire [3:0] omem_addra,       // output of fc layer. 0~9.
    output wire [7:0] omem_dina,         // output of fc layer. cliped to 8bit.

    // PE port (read, write) - 4 parallel PE. 4 PEs are concatenated in top_module.
    output wire pe_ena,
    output wire [4*576-1:0] pe_input,   // input of 4 PE: 4*576 bits. 
    output wire [4*576-1:0] pe_weight,
    input wire [4*22-1:0] pe_dout,      // mac result of PE. 4*22bit. (for 228 = 4*72 inputs. need to get 8 outputs to calcualte one logit)
    input wire pe_valid                 // processing element output is valid.
);
    // ===============================================================
    // CONTENTS
    // 
    // 1. FSM
    // 2. imem, wmem Read Access
    // 3. PE Operation
    // 4. Mac Operation and Save Mac Result
    // 
    // ===============================================================


    // ---------- 1. FSM ---------------------------------------------
    // states
    localparam IDLE = 0;
    localparam RUN = 1;
    localparam DONE = 2;
    reg [1:0] state;
    reg [1:0] next_state;

    // FSM control logic
    always @(*) begin
        if (!resetn) begin
            next_state = IDLE;
        end else begin
            case (state)    
                IDLE:       next_state = start ? RUN : IDLE;
                RUN:        next_state = (mac_write_addr == 10) ? DONE : RUN;
                DONE:       next_state = start ? RUN : DONE;
                default:    next_state = IDLE;
            endcase
        end
    end
    // FSM state transition
    always @(posedge clk) begin
        state <= next_state;
    end

    // done_state signal: done_state edge detection
    reg done_state, done_d;
    always @(posedge clk) begin
        done_state <= (state == DONE);
        done_d <= done_state;
    end
    assign done = done_state && !done_d;
    // ---------------------------------------------------------------


    // ---------- 2. imem, wmem Read Access --------------------------
    // Run counter. IDLE:0, RUN: 0~80
    reg [6:0] run_cnt; 
    // read address for imem and wmem. run_cnt / run_cnt + 5.
    assign imem_addrb = run_cnt[2:0];  // imem address is 0~7.
    assign wmem_addrb = run_cnt + 5;

    // run counter increase only at RUN state
    always @(posedge clk) begin 
        run_cnt <= (state == RUN) ? run_cnt + 1 : 0;
    end

    // start reading when start is asserted
    always @(posedge clk) begin
        if (start) begin
            imem_enb <= 1;
            wmem_enb <= 1;
        end else if (state != RUN) begin  // if not RUN, disable read access.
            imem_enb <= 0;
            wmem_enb <= 0;
        end
    end

    // read data from imem and wmem -> save to reg.
    reg [2303:0] imem_doutb_reg;
    reg [2303:0] wmem_doutb_reg;
    reg doutb_valid [1:0];

    always @(posedge clk) begin
        if (state == RUN) begin
            imem_doutb_reg <= imem_doutb;
            wmem_doutb_reg <= wmem_doutb;
        end 
    end

    always @(posedge clk) begin
        if (state == RUN) begin
            doutb_valid[0] <= 1;
            doutb_valid[1] <= doutb_valid[0];
        end else if (state != RUN) begin
            doutb_valid[0] <= 0;
            doutb_valid[1] <= 0;
        end
    end
    // ---------------------------------------------------------------


    // ---------- 3. PE Operation -----------------------------------
    // PE input and weight. 2304 = 4*576 bits.
    assign pe_ena = doutb_valid[1];
    assign pe_input = imem_doutb_reg;
    assign pe_weight = wmem_doutb_reg;

    // valid signal of PE. used resigter to ensure distance between PE and this module.
    reg pe_valid_reg;
    always @(posedge clk) begin
        pe_valid_reg <= pe_valid;
    end
    
    // same as pe_valid, use register for PE output.
    reg [87:0] pe_dout_reg;  
    always @(posedge clk) begin
        pe_dout_reg <= pe_dout;
    end

    // do add tree operation. after pe operation
    // add tree operation is done by 2 adders.
    // add tree 1: 22 bits + 22 bits -> 23 bits.
    // add tree 2: 23 bits + 23 bits -> 24 bits.
    reg signed [22:0] add_tree_1 [0:1];
    reg signed [23:0] add_tree_2;
    reg tree_valid [1:0];

    always @(posedge clk) begin
        add_tree_1[0] <= $signed(pe_dout_reg[21:0]) + $signed(pe_dout_reg[43:22]);
        add_tree_1[1] <= $signed(pe_dout_reg[65:44]) + $signed(pe_dout_reg[87:66]);
        add_tree_2 <= add_tree_1[0] + add_tree_1[1];
    end

    always @(posedge clk) begin
        if (!resetn) begin
            tree_valid[0] <= 0;
            tree_valid[1] <= 0;
        end else begin
            tree_valid[0] <= pe_valid_reg;
            tree_valid[1] <= tree_valid[0];
        end
    end
    // ---------------------------------------------------------------


    // ---------- 4. Mac Operation and Save Mac Result ----------------
    reg [2:0] cnt_psum;  // 0~7. if 8 psum is accumulated, write data to omem.
    reg signed [26:0] mac_result;
    reg mac_valid;  // mac result is valid.

    // psum counter is increased only when mac_valid is asserted.
    always @(posedge clk) begin
        if (state == IDLE || state == DONE) begin
            cnt_psum <= 0;
        end else if (tree_valid[1]) begin
            cnt_psum <= cnt_psum + 1;
        end
    end

    // do mac operation when pe_valid is asserted. mac valid is pulse signal, which is asserted when mac operation is done.
    always @(posedge clk) begin
        if (state == IDLE || state == DONE) begin
            mac_result <= 0;
        end else if (tree_valid[1]) begin
            mac_result <= (cnt_psum == 0 && mac_valid) ? add_tree_2 : mac_result + add_tree_2;
        end 
    end

    always @(posedge clk) begin
        if (state == IDLE || state == DONE) begin
            mac_valid <= 0;
        end else if (tree_valid[1]) begin
            mac_valid <= 1;
        end else begin
            mac_valid <= 0;
        end
    end

    // save mac result when psum_counter is 7.
    reg mac_write_flag;
    always @(posedge clk) begin
        mac_write_flag <= (cnt_psum == 7 && mac_valid);
    end
    assign omem_ena = mac_write_flag;
    assign omem_wea = mac_write_flag;

    // mac write address increase after mac_write_flag.
    reg [3:0] mac_write_addr;  // 0~9.
    always @(posedge clk) begin
        if (state == IDLE || state == DONE) begin
            mac_write_addr <= 0;
        end else if (mac_write_flag) begin
            mac_write_addr <= mac_write_addr + 1;
        end
    end

    assign omem_addra = mac_write_addr;
    assign omem_dina = clip_value(mac_result[26:10]);

    // Clip function to slice LSB and clip value between -128 and 127
    function signed [7:0] clip_value;
        input signed [16:0] value;
        begin
            if (value > 127)
                clip_value = 127;
            else if (value < -128)
                clip_value = -128;
            else
                clip_value = value[7:0];
        end
    endfunction
    // ---------------------------------------------------------------

endmodule
