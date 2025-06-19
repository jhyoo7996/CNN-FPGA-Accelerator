    `timescale 1ns / 1ps
    //////////////////////////////////////////////////////////////////////////////////
    // Company: 
    // Engineer: 
    // 
    // Create Date: 2025/06/05 17:17:51
    // Design Name: 
    // Module Name: conv2
    // Project Name: 
    // Target Devices: 
    // Tool Versions: 
    // Description: 
    // 
    // Dependencies: 
    // 
    // Revision:
    // Revision 0.01 - File Created
    // Additional Comments:
    // 
    //////////////////////////////////////////////////////////////////////////////////
    
    
    module conv2 (
        input wire clk,
        input wire resetn,
        input wire start,
        output wire done,
        
        // IMEM port B (read)
        output wire img_en,
        output wire [9:0] img_addr, // 676 of them -> 10 bit
        input wire [63:0] img_dout, // 64 bit input
        
        // WMEM port B (read) 
        // control data of BRAM outside of this module. the data from BRAM goes to PE Module
        output wire weight_en,
        output wire [6:0] weight_addr, // 7bit??? 85 ?????? ?????????
        input wire [2303:0] wmem_doutb,
    
        // Operand of PE Module
        output wire [575:0] buffer_data_out, // 576 = 64 x 9
        output wire buffer_data_valid,
        output wire [2303:0] pe_weight,
        output wire [2303:0] pe_input,
    
        // PE Module
        input wire result_valid,
        input wire [31:0] pe_dout,  // 4 PE 8bit output
        // input wire [21:0] result_in1, // 22bit
        // input wire [21:0] result_in2, // 22bit
        // input wire [21:0] result_in3, // 22bit
        // input wire [21:0] result_in4, // 22bit
        //    input wire [7:0] result_in1, // 8bit
        //    input wire [7:0] result_in2, // 8bit
        //    input wire [7:0] result_in3, // 8bit
        //    input wire [7:0] result_in4, // 8bit
    
        // OMEM port A (write)  
        // !!! slack ����?????? register ��?? ?????? ???????????? ¥��
        output reg out_en, // output 72 BW
        output wire [5:0] out_addr, // 256 depth
        output wire [71:0] out_din1,
        output wire [71:0] out_din2,
        output wire [71:0] out_din3,
        output wire [71:0] out_din4 
    );
        assign pe_input = {4{buffer_data_out}};
        
    
        assign pe_weight = wmem_doutb;
    
        wire result_valid_conv2 = result_valid && (state == CONV);
        wire [7:0] result_in1, result_in2, result_in3, result_in4;
        assign result_in1 = pe_dout[7:0];
        assign result_in2 = pe_dout[15:8];
        assign result_in3 = pe_dout[23:16];
        assign result_in4 = pe_dout[31:24];
    
    
        // FSM states ++
        localparam IDLE = 2'd0;
        localparam CONV = 2'd1;
        localparam TEMP_DONE = 2'd2; // 4ä�� ?????? ????????? ?????? 
        localparam DONE = 2'd3;
    
        reg [1:0] state, n_state;
    
        // Counters
        reg [9:0] img_cnt; // 26*26 = 676
        //reg [9:0] out_cnt; // 
        reg [4:0] stride_cnt; // 28??? ??????.  
        reg [1:0] filter_cnt; // 4���� ???���?. 
    
        // Status signals
        reg img_load_done_reg;
        wire remaining_conv_done, filter_conv_done;
    
        // Data storing regs ++
        reg [71:0] pe1_output;  // 8*9 = 72. 9 ?? of 8bit data
        reg [71:0] pe2_output;
        reg [71:0] pe3_output;
        reg [71:0] pe4_output;
    
    
        // Pipeline registers ++
        reg [63:0] data_out0_pipe [0:2];
        reg [63:0] data_out1_pipe [0:2];
        reg [63:0] data_out2_pipe [0:2];
        reg [2:0] data_rdy_pipe;
    
        // FSM ++
        always @(posedge clk or negedge resetn) begin
            if(~resetn) state <= IDLE;
            else state <= n_state;
        end
        
        // FSM logic ++
        always @(*) begin
            case(state)
                IDLE: n_state = start ? CONV : IDLE;
                CONV: begin
                    if(remaining_conv_done) n_state = TEMP_DONE;
                    else if(filter_conv_done) n_state = DONE;
                    else n_state = CONV;
                end
                TEMP_DONE: n_state = CONV;
                DONE: n_state = IDLE;
                default: n_state = IDLE;
            endcase
        end
    
        // Counter controls ++
    
        // img_cnt ++
        always @(posedge clk) begin
            if (state == CONV) begin
                if(img_cnt < 675 && img_load_done_reg == 0) begin
                    img_cnt <= img_cnt + 1;
                end else begin
                    img_cnt <= 0;
                end
            end else begin
                img_cnt <= 0;
            end
        end
    
        always @(posedge clk) begin
            if(state == CONV) begin
                if(img_cnt == 675) img_load_done_reg <= 1;
            end else begin
                img_load_done_reg <= 0;
            end
        end
    
        assign img_en  = (state == CONV) && (img_load_done_reg == 0);
        assign img_addr = img_cnt;
    
        // img_valid_pipe ++
        reg [1:0] img_valid_pipe; // 2 clk delay of image read
        always @(posedge clk) begin
            if(state == CONV) begin
                img_valid_pipe <= {img_valid_pipe[0], img_en};
            end else begin
                img_valid_pipe <= 0;
            end
        end
    
    
        // weight_addr ++  
        wire [2:0] weigt_compendsation = {1'd0,filter_cnt} + 1;
        assign weight_addr = {4'd0,weigt_compendsation}; // filter cnt = 2bit , weight addr = 7bit
        assign weight_en = data_rdy_pipe[1];
    
         // Control signals ++
        wire data_push = img_valid_pipe[1];
    
        // buffer_data_out ++
        always @(posedge clk) begin
            if(state == CONV) begin
                if(data_rdy_pipe[2] == 1) begin
                    if(stride_cnt < 25) stride_cnt <= stride_cnt + 1; // 0 ~ 25 circular
                    else stride_cnt <= 0;
                end // ?????? 
            end else begin // else stage
                stride_cnt <= 0;
            end
        end
    
        assign buffer_data_valid = (state == CONV) && (stride_cnt != 24) && (stride_cnt != 25) && (data_rdy_pipe[2]); // 3 clk delay of data_rdy
        assign buffer_data_out = {data_out2_pipe[0][63:56], data_out2_pipe[1][63:56], data_out2_pipe[2][63:56], 
                                        data_out1_pipe[0][63:56], data_out1_pipe[1][63:56], data_out1_pipe[2][63:56], 
                                        data_out0_pipe[0][63:56], data_out0_pipe[1][63:56], data_out0_pipe[2][63:56],
                                        data_out2_pipe[0][55:48], data_out2_pipe[1][55:48], data_out2_pipe[2][55:48], 
                                        data_out1_pipe[0][55:48], data_out1_pipe[1][55:48], data_out1_pipe[2][55:48], 
                                        data_out0_pipe[0][55:48], data_out0_pipe[1][55:48], data_out0_pipe[2][55:48],
                                        data_out2_pipe[0][47:40], data_out2_pipe[1][47:40], data_out2_pipe[2][47:40], 
                                        data_out1_pipe[0][47:40], data_out1_pipe[1][47:40], data_out1_pipe[2][47:40], 
                                        data_out0_pipe[0][47:40], data_out0_pipe[1][47:40], data_out0_pipe[2][47:40],
                                        data_out2_pipe[0][39:32], data_out2_pipe[1][39:32], data_out2_pipe[2][39:32], 
                                        data_out1_pipe[0][39:32], data_out1_pipe[1][39:32], data_out1_pipe[2][39:32], 
                                        data_out0_pipe[0][39:32], data_out0_pipe[1][39:32], data_out0_pipe[2][39:32],
                                        data_out2_pipe[0][31:24], data_out2_pipe[1][31:24], data_out2_pipe[2][31:24], 
                                        data_out1_pipe[0][31:24], data_out1_pipe[1][31:24], data_out1_pipe[2][31:24], 
                                        data_out0_pipe[0][31:24], data_out0_pipe[1][31:24], data_out0_pipe[2][31:24],
                                        data_out2_pipe[0][23:16], data_out2_pipe[1][23:16], data_out2_pipe[2][23:16],
                                        data_out1_pipe[0][23:16], data_out1_pipe[1][23:16], data_out1_pipe[2][23:16],
                                        data_out0_pipe[0][23:16], data_out0_pipe[1][23:16], data_out0_pipe[2][23:16],
                                        data_out2_pipe[0][15:8], data_out2_pipe[1][15:8], data_out2_pipe[2][15:8],
                                        data_out1_pipe[0][15:8], data_out1_pipe[1][15:8], data_out1_pipe[2][15:8],
                                        data_out0_pipe[0][15:8], data_out0_pipe[1][15:8], data_out0_pipe[2][15:8],
                                        data_out2_pipe[0][7:0], data_out2_pipe[1][7:0], data_out2_pipe[2][7:0],
                                        data_out1_pipe[0][7:0], data_out1_pipe[1][7:0], data_out1_pipe[2][7:0],
                                        data_out0_pipe[0][7:0], data_out0_pipe[1][7:0], data_out0_pipe[2][7:0]};
    
        // result_in?? result_valid_conv2 ?? ???????????? line_buffer ?? ?????? maxpool??? ?????? ??????.
        // maxpool line buffer instance
        wire maxpool_valid1, maxpool_valid2, maxpool_valid3, maxpool_valid4;
        wire [7:0] maxpool_out1, maxpool_out2, maxpool_out3, maxpool_out4;
    
        // maxpool line buffer instance
        conv2_maxpool_line_buffer maxpool1 (
            .new_filter((state == TEMP_DONE) || (state == DONE)),
            .clk(clk),
            .resetn(resetn),
            .data_valid(result_valid_conv2),
            .data_in(result_in1),
            .maxpool_valid(maxpool_valid1),
            .maxpool_out(maxpool_out1)
        );
    
        conv2_maxpool_line_buffer maxpool2 (
            .new_filter((state == TEMP_DONE) || (state == DONE)),
            .clk(clk),
            .resetn(resetn),
            .data_valid(result_valid_conv2),
            .data_in(result_in2),
            .maxpool_valid(maxpool_valid2),
            .maxpool_out(maxpool_out2)
        );
    
        conv2_maxpool_line_buffer maxpool3 (
            .new_filter((state == TEMP_DONE) || (state == DONE)),
            .clk(clk),
            .resetn(resetn),
            .data_valid(result_valid_conv2),
            .data_in(result_in3),
            .maxpool_valid(maxpool_valid3),
            .maxpool_out(maxpool_out3)
        );
    
        conv2_maxpool_line_buffer maxpool4 (
            .new_filter((state == TEMP_DONE) || (state == DONE)),
            .clk(clk),
            .resetn(resetn),
            .data_valid(result_valid_conv2),
            .data_in(result_in4),
            .maxpool_valid(maxpool_valid4),
            .maxpool_out(maxpool_out4)
        );
    
    
    
        // PE ���? ī��???
        reg [3:0]pe_output_cnt; // 9??
        wire maxpool_valid_all = maxpool_valid1 && maxpool_valid2 && maxpool_valid3 && maxpool_valid4;
       
        always @(posedge clk) begin
            if(state == CONV) begin 
                if (maxpool_valid_all) begin
                    if(pe_output_cnt < 8) pe_output_cnt <= pe_output_cnt + 1;
                    else pe_output_cnt <= 0; // if 8+
                    pe1_output <= {maxpool_out1, pe1_output[71:8]}; // 9 data. 
                    pe2_output <= {maxpool_out2, pe2_output[71:8]};
                    pe3_output <= {maxpool_out3, pe3_output[71:8]};
                    pe4_output <= {maxpool_out4, pe4_output[71:8]};
                end
            end else begin 
                pe_output_cnt <= 0;
                pe1_output <= 0;
                pe2_output <= 0;
                pe3_output <= 0;
                pe4_output <= 0;
            end
        end
    
        always @(posedge clk) begin
            if(state == CONV) begin
                if(pe_output_cnt == 8 && maxpool_valid_all == 1) out_en <= 1;
                else out_en <= 0;
            end else begin
                out_en <= 0;
            end
        end
    
        reg [5:0] out_cnt; // 64??. 4ä�� ?? 256����??? ����?????????? 64?? ?????
        always @(posedge clk) begin
            if(state == CONV) begin
                if(out_en == 1) begin
                    if(out_cnt < 15) out_cnt <= out_cnt + 1;
                    else out_cnt <= 0; // 15. 
                end 
            end else begin
                out_cnt <= 0;
            end
        end
    
        assign out_addr = out_cnt + filter_cnt * 16;
        assign out_din1 = pe1_output;
        assign out_din2 = pe2_output;
        assign out_din3 = pe3_output;
        assign out_din4 = pe4_output;
    
        // add filter_cnt
        always @(posedge clk) begin
            if (state == TEMP_DONE) begin
                filter_cnt <= filter_cnt + 1;
            end else if (state == DONE || state == IDLE) begin
                filter_cnt <= 0;
            end // else remain in CONV state
        end
    
        assign remaining_conv_done = (filter_cnt < 3) &&(out_cnt == 15) && (out_en == 1);
        assign filter_conv_done = (filter_cnt == 3) && (out_cnt == 15) && (out_en == 1);
        assign done = (state == DONE);
    
        /// Convserve this part ---------------------------------------------
        // Line buffer signals ++
        wire [63:0] data_out0, data_out1, data_out2;
        wire data_rdy;
    
        // Line buffer instance
        conv2_line_buffer line_buffer (
            .new_filter((state == TEMP_DONE) || (state == DONE)),
            .clk(clk),
            .resetn(resetn),
            .data_push(data_push),
            .data_in(img_dout),
            .data_rdy(data_rdy),
            .data_out0(data_out0),
            .data_out1(data_out1),
            .data_out2(data_out2)
        );
    
        // Pipeline registers
        always @(posedge clk) begin
            if (state == CONV) begin
                data_out0_pipe[2] <= data_out0_pipe[1];
                data_out0_pipe[1] <= data_out0_pipe[0];
                data_out0_pipe[0] <= data_out0;
                data_out1_pipe[2] <= data_out1_pipe[1];
                data_out1_pipe[1] <= data_out1_pipe[0];
                data_out1_pipe[0] <= data_out1;
                data_out2_pipe[2] <= data_out2_pipe[1];
                data_out2_pipe[1] <= data_out2_pipe[0];
                data_out2_pipe[0] <= data_out2;
                data_rdy_pipe[2] <= data_rdy_pipe[1];
                data_rdy_pipe[1] <= data_rdy_pipe[0];
                data_rdy_pipe[0] <= data_rdy;
            end else begin
                data_out0_pipe[0] <= 0; data_out0_pipe[1] <= 0; data_out0_pipe[2] <= 0;
                data_out1_pipe[0] <= 0; data_out1_pipe[1] <= 0; data_out1_pipe[2] <= 0;
                data_out2_pipe[0] <= 0; data_out2_pipe[1] <= 0; data_out2_pipe[2] <= 0;
                data_rdy_pipe <= 0;
                data_rdy_pipe <= 3'b000;
            end
        end
    
        ////////////////////////////////////// ---------------------------------------------
    
    endmodule
