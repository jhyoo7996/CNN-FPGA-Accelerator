`timescale 1ns / 1ps


module top_layer(
    input wire clk,
    input wire resetn,
    input wire start,
    output wire done,
    
     // Initial input BRAM *write* port 
     // write bitwidth = 8, depth = 784
     input wire imem_ena,
     input wire imem_wea,
     input wire [9:0] imem_addra,
     input wire [7:0] imem_dina,

//    /////////////////////////////////////////////////////////////////////////////////////////////////////////
//    // Conv2 output BRAM *write* port  <<-- this is for test (delete & use "Initial input BRAM" ports later.)
//    input wire c2_omem_ena,
//    input wire c2_omem_wea,
//    input wire [9:0] c2_omem_addra,
//    input wire [4*72-1:0] c2_omem_dina, // 72**************************************************************************************
//    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Initial weight BRAM *write* port 
    // write bitwidth = 8, depth = 24264
    input wire wmem_ena,
    input wire wmem_wea,
    input wire [14:0] wmem_addra,
    input wire [7:0] wmem_dina,
    
    // Final output BRAM *read* port 
    // read bitwidth = 8, depth = 10
    input wire omem_enb,
    input wire [3:0] omem_addrb,
    output wire [7:0] omem_doutb
);
    genvar i;
    // ===================================================================
    // CONTENTS                                                         //
    //                                                                  //
    // 1. Intermediate Start & Done (Done Edge = Next Start)            //
    // 2. Layer Control FSM                                             //
    // 3. Intermediate BRAM Ports                                       //
    // 4. Instantiate BRAMs                                             //
    // 5. BRAM Ports Control                                            //
    // 6. Instantiate Layers                                            //
    // 7. Instantiate PE Modules                                        //
    //                                                                  //
    // ===================================================================
    
    // ========== 0. Image Counter ======================================= //
    // define image counter: 250 images!!!
    reg [7:0] image_counter;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            image_counter <= 8'd0;
        end else if (start) begin
            image_counter <= 0;
        end else if (done_fc && (image_counter != 8'd249)) begin
            image_counter <= image_counter + 1;
        end
    end

    // define image counter reset signal
    wire [17:0] imem_base;  // ~196000
    wire [11:0] omem_base;  // ~2500

    assign imem_base = image_counter * 10'd784;
    assign omem_base = image_counter * 4'd10;

    wire done_img;
    assign done_img = done_reg;
    assign done = done_img && (image_counter == 8'd249);

    reg inner_start;
    always @(posedge clk) begin
        if (image_counter != 8'd249) begin
            inner_start <= done_fc;
        end else begin
            inner_start <= 0;
        end
    end
    // =================================================================== //


    // ========== 1. Start & Done ========================================
    // intermediate start & done signal.
    wire done_wd;
     wire done_conv1;
     wire done_conv2;
    wire done_fc;
    
    wire start_wd;
     wire start_conv1;
     wire start_conv2;
    wire start_fc;

    // connect start & done signal.
    assign start_wd = start || inner_start;
     assign start_conv1 = done_wd;
     assign start_conv2 = done_conv1;
     assign start_fc = done_conv2;

    // final done signal. 
    reg done_reg;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            done_reg <= 0;
        end else begin
            done_reg <= done_fc ? 1 : (start || inner_start) ? 0 : done_reg;
        end
    end

    // assign done = done_reg;
    // ===================================================================
    

    // ========== 2. Layer Control FSM ===================================
    // define layer FSM states
    localparam IDLE = 0;
    localparam WD = 1;
     localparam CONV1 = 2; //  <<-- this is for test (uncomment this code later.)
     localparam CONV2 = 3; // <<-- this is for test (uncomment this code later.)
    localparam FC = 4;

    // define layer FSM signals
    reg [2:0] state;
    reg [2:0] next_state;

    // FSM logic
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start_wd ? WD : IDLE;
            WD: next_state = done_wd ? CONV1 : WD;
             CONV1: next_state = done_conv1 ? CONV2 : CONV1;
             CONV2: next_state = done_conv2 ? FC : CONV2;
            FC: next_state = done_fc ? IDLE : FC;
            default: next_state = IDLE;
        endcase
    end
    // ===================================================================


    // ========== 3. Intermediate BRAM Ports =============================
    //// >>>> Weight Distributer >>>>
    // Weight Distributer Input BRAM *read* port
    // read bitwidth = 8, depth = 24264
    wire wd_imem_enb;
    wire [14:0] wd_imem_addrb;
    wire [7:0] wd_imem_doutb;

    // Weight Distributer Output BRAM *write* port
    // write bitwidth = 72, depth = 2720
    wire wd_omem_ena;
    wire wd_omem_wea;
    wire [11:0] wd_omem_addra;
    wire [71:0] wd_omem_dina;
    

    // //// >>>> Conv1 >>>>
     // Conv1 input BRAM *read* port
     // read bitwidth = 8, depth = 784
     wire c1_imem_enb;
     wire [9:0] c1_imem_addrb;
     wire [7:0] c1_imem_doutb;

     // Conv1 weight BRAM *read* port
     // read bitwidth = 2304, depth = 85
     wire c1_wmem_enb;
     wire [6:0] c1_wmem_addrb;
     wire [2303:0] c1_wmem_doutb;

     // Conv1 output BRAM *write* port
     // write bitwidth = 64, depth = 676
//     wire c1_omem_ena;
     wire c1_omem_wea;
     wire [9:0] c1_omem_addra;
     wire [63:0] c1_omem_dina;


     //// >>>> Conv2 >>>>
     // Conv2 input BRAM *read* port
     // read bitwidth = 64, depth = 676
     wire c2_imem_enb;
     wire [9:0] c2_imem_addrb;
     wire [63:0] c2_imem_doutb;

     // Conv2 weight BRAM *read* port
     // read bitwidth = 2304, depth = 85
     wire c2_wmem_enb;
     wire [6:0] c2_wmem_addrb;
     wire [2303:0] c2_wmem_doutb;

     // Conv2 output BRAM *write* port
     // write bitwidth = 72, depth = 64, parallel = 4
//     wire c2_omem_ena;               // 4 parallel BRAMs are enabled at the same time.
     wire c2_omem_wea;               // 4 parallel BRAMs are written at the same time.
     wire [5:0] c2_omem_addra;       // 4 parallel BRAMs are written at the same address.
     wire [71:0] c2_omem_dina [0:3]; // write data is individual for each BRAM.

    //// >>>> FC >>>>
    // FC input BRAM *read* port
    // read bitwidth = 576, depth = 8, parallel = 4
    wire fc_imem_enb;
    wire [2:0] fc_imem_addrb;
    wire [2303:0] fc_imem_doutb;
    wire [575:0] fc_imem_doutb_array [3:0];
    assign fc_imem_doutb = {fc_imem_doutb_array[3], fc_imem_doutb_array[2], fc_imem_doutb_array[1], fc_imem_doutb_array[0]};
    
    // FC weight BRAM *read* port
    // read bitwidth = 2304, depth = 85
    wire fc_wmem_enb;
    wire [6:0] fc_wmem_addrb;
    wire [2303:0] fc_wmem_doutb;

    // FC output BRAM *write* port
    // write bitwidth = 8, depth = 10
    wire fc_omem_ena;              
    wire fc_omem_wea;             
    wire [3:0] fc_omem_addra;      
    wire [7:0] fc_omem_dina;
    // ===================================================================


    // ========== 4. Instantiate BRAMs ===================================
    //// >>>> Weight Distributer >>>>
    // Initial weight BRAM || Weight Distributer Input BRAM
    wd_imem Uwd_imem (
        .clka(clk),
        .ena(wmem_ena),
        .wea(wmem_wea),
        .addra(wmem_addra),
        .dina(wmem_dina),
        .clkb(clk),
        .enb(wd_imem_enb),
        .addrb(wd_imem_addrb),
        .doutb(wd_imem_doutb)
    );

    // Weight Distributer Output BRAM || Conv1, Conv2, FC weight input BRAM
    wmem Uwmem (
        .clka(clk),
        .ena(wd_omem_ena),
        .wea(wd_omem_wea),
        .addra(wd_omem_addra),
        .dina(wd_omem_dina),
        .clkb(clk),
        .enb(wd_omem_enb),
        .addrb(wd_omem_addrb),
        .doutb(wd_omem_doutb)
    );    


     //// >>>> Conv1 >>>>
     // Initial input BRAM || Conv1 input BRAM
     c1_imem Uc1_imem (
         .clka(clk),
         .ena(imem_ena),
         .wea(imem_wea),
         .addra(imem_addra + imem_base),
         .dina(imem_dina),
         .clkb(clk),
         .enb(c1_imem_enb),
         .addrb(c1_imem_addrb + imem_base),
         .doutb(c1_imem_doutb)
     );

     // Conv1 output BRAM || Conv2 input BRAM
     c1_omem Uc1_omem (
         .clka(clk),
         .ena(c1_omem_wea),
         .wea(c1_omem_wea),
         .addra(c1_omem_addra),
         .dina(c1_omem_dina),
         .clkb(clk),
         .enb(c2_imem_enb),
         .addrb(c2_imem_addrb),
         .doutb(c2_imem_doutb)
     );


    //// >>>> Conv2 >>>>
    // Conv2 output BRAM || FC input BRAM
    generate
        for (i = 0; i < 4; i = i + 1) begin : c2_omem_gen
            c2_omem Uc2_omem (
                .clka(clk),
                .ena(c2_omem_wea),
                .wea(c2_omem_wea),
                .addra(c2_omem_addra),
                .dina(c2_omem_dina[i]),
                .clkb(clk),
                .enb(fc_imem_enb),
                .addrb(fc_imem_addrb),
                .doutb(fc_imem_doutb_array[i])
            );
        end
    endgenerate


    //// >>>> FC >>>>   
    // FC output BRAM || Final output BRAM
    fc_omem Ufc_omem (
        .clka(clk),
        .ena(fc_omem_ena),
        .wea(fc_omem_wea),
        .addra(fc_omem_addra + omem_base),
        .dina(fc_omem_dina),
        .clkb(clk),
        .enb(omem_enb),
        .addrb(omem_addrb + omem_base),
        .doutb(omem_doutb)
    );
    // ===================================================================


    // ========== 5. BRAM Ports Control ==================================
    // // Weight Distributer Output BRAM *read* port
    // // read bitwidth = 2304, depth = 85
     wire wd_omem_enb;
     wire [6:0] wd_omem_addrb;
     wire [2303:0] wd_omem_doutb;

     // Multiplexing BRAM ports for Weight Distributer Output BRAM
     assign wd_omem_enb = c1_wmem_enb || c2_wmem_enb || fc_wmem_enb;
     assign wd_omem_addrb = (state == CONV1) ? c1_wmem_addrb 
                          : (state == CONV2) ? c2_wmem_addrb 
                          : (state == FC) ? fc_wmem_addrb
                          : 0;
     assign c1_wmem_doutb = wd_omem_doutb;
     assign c2_wmem_doutb = wd_omem_doutb;
     assign fc_wmem_doutb = wd_omem_doutb;

    // ===================================================================


    // ========== 6. Instantiate Layers ==================================
    // instantiate weight distributer
    weight_distributer Uweight_distributer(
        .clk(clk),
        .resetn(resetn),
        .start(start_wd),
        .done(done_wd),
        // Initial weight BRAM *read* port
        .wmem_enb(wd_imem_enb),
        .wmem_addrb(wd_imem_addrb),
        .wmem_doutb(wd_imem_doutb),
        // Weight Distributer Output BRAM *write* port
        .omem_addra(wd_omem_addra),
        .omem_dina(wd_omem_dina),
        .omem_wea(wd_omem_wea),
        .omem_ena(wd_omem_ena)
    );

    conv1 Uconv1_layer(
        .clk(clk),
        .resetn(resetn),
        .start(start_conv1),
        .done(done_conv1),

        .img_en(c1_imem_enb),
        .img_addr(c1_imem_addrb),
        .img_dout(c1_imem_doutb),

        .weight_en(c1_wmem_enb),
        .weight_addr(c1_wmem_addrb),
        .wmem_doutb(c1_wmem_doutb),

        //.///////////////////////////////////////
        .pe_weight(c1_pe_weight), // 576 bit
        .buffer_data_valid(c1_pe_ena),
        .pe_input(c1_pe_input), // 576 bit  connected to one PE
        ////////////////////////////////////////////////////
        .result_valid(c1_pe_valid),
        .result_in(c1_pe_dout),
        .out_en(c1_omem_wea), // assign ena = wea
        .out_addr(c1_omem_addra),
        .out_din(c1_omem_dina)
    );
    
    conv2 Uconv2_layer(
        .clk(clk),
        .resetn(resetn),
        .start(start_conv2),
        .done(done_conv2),
        .img_en(c2_imem_enb),
        .img_addr(c2_imem_addrb),
        .img_dout(c2_imem_doutb),
        .weight_en(c2_wmem_enb),
        .weight_addr(c2_wmem_addrb),    // wmem_dout -> direct multiplexing conv2_pe_weight ???
        .wmem_doutb(c2_wmem_doutb),
        //.buffer_data_out(c2_pe_input), // ifmap 576 * 8   , pe ifmap input, 4pe use same activation map
        .buffer_data_valid(c2_pe_ena), // maybe pe en?
        .pe_weight(c2_pe_weight),
        .pe_input(c2_pe_input),
        .result_valid(c2_pe_valid), // maybe pe valid conv2
        .pe_dout(c2_pe_dout_concat),
        
//        .result_in1(c2_pe_dout[0]), // 4 pe clipped result
//        .result_in2(c2_pe_dout[1]),
//        .result_in3(c2_pe_dout[2]),
//        .result_in4(c2_pe_dout[3]),
        .out_en(c2_omem_wea),   // omem write enable
        .out_addr(c2_omem_addra),
        .out_din1(c2_omem_dina[0]),
        .out_din2(c2_omem_dina[1]),
        .out_din3(c2_omem_dina[2]),
        .out_din4(c2_omem_dina[3])               
    );
    

    // instantiate fc_module
    fc_module Ufc_module(
        .clk(clk),
        .resetn(resetn),
        .start(start_fc),
        .done(done_fc),
        // FC input BRAM *read* port
        .imem_enb(fc_imem_enb),
        .imem_addrb(fc_imem_addrb),
        .imem_doutb(fc_imem_doutb),
        // FC weight BRAM *read* port
        .wmem_enb(fc_wmem_enb),
        .wmem_addrb(fc_wmem_addrb),
        .wmem_doutb(fc_wmem_doutb),
        // FC output BRAM *write* port
        .omem_ena(fc_omem_ena),
        .omem_wea(fc_omem_wea),
        .omem_addra(fc_omem_addra),
        .omem_dina(fc_omem_dina),
        // PE port (read, write) - 4 parallel PE. 4 PEs are concatenated in top_module.
        .pe_ena(fc_pe_ena),
        .pe_input(fc_pe_input),
        .pe_weight(fc_pe_weight),
        .pe_dout(fc_pe_dout_concat),
        .pe_valid(fc_pe_valid)
    );

    // ===================================================================


    // ========== 7. Instantiate PE Modules ==============================
    // define PE ports
    wire pe_ena [3:0];  
    wire [575:0] pe_input [3:0];
    wire [575:0] pe_weight [3:0];

    // define layer PE ports
    wire fc_pe_ena;
    wire [2303:0] fc_pe_input;
    wire [2303:0] fc_pe_weight;
    wire [87:0] fc_pe_dout_concat;
    wire [21:0] fc_pe_dout [0:3];
    wire fc_pe_valid;
    
    // define conv2 layer PE ports
    wire c2_pe_ena;
    wire [2303:0] c2_pe_input;
    wire [2303:0] c2_pe_weight;
    wire [31:0] c2_pe_dout_concat;
    wire [7:0] c2_pe_dout [0:3];
    
    // define conv1 layer PE ports
    wire c1_pe_ena;
    wire [575:0] c1_pe_input;
    wire [575:0] c1_pe_weight;   // dsp pe 1
    //wire [31:0] c2_pe_dout_concat;
    wire [63:0] c1_pe_dout;
    

    // assign & multiplexing PE ports  <<-- Multiplexing needed!!!!!!!!!!!!!!!!
    assign fc_pe_dout_concat = {fc_pe_dout[3], fc_pe_dout[2], fc_pe_dout[1], fc_pe_dout[0]};
    assign c2_pe_dout_concat = {c2_pe_dout[3], c2_pe_dout[2], c2_pe_dout[1], c2_pe_dout[0]};

    generate
        for (i = 0; i < 4; i = i + 1) begin : pe_gen
            assign pe_ena[i] = (state == CONV1) ? c1_pe_ena 
                          : (state == CONV2) ? c2_pe_ena 
                          : (state == FC) ? fc_pe_ena
                          : 0;
            assign pe_input[i] = (state == CONV1) ? c1_pe_input 
                          : (state == CONV2) ? c2_pe_input[575:0] 
                          : (state == FC) ? fc_pe_input[i*576 +: 576]
                          : 0;
            assign pe_weight[i] = (state == CONV1) ? c1_pe_weight 
                          : (state == CONV2) ? c2_pe_weight[i*576 +: 576] 
                          : (state == FC) ? fc_pe_weight[i*576 +: 576]
                          : 0;
        end
    endgenerate
    
    // valid
    wire c1_pe_valid;
    wire c2_pe_valid;
    wire fc_pe_valid;
    
    assign c2_pe_valid = c2_pe_valid_array[0] && c2_pe_valid_array[1] && c2_pe_valid_array[2] && c2_pe_valid_array[3];
    assign fc_pe_valid = fc_pe_valid_array[0] && fc_pe_valid_array[1] && fc_pe_valid_array[2] && fc_pe_valid_array[3];
    
    wire c2_pe_valid_array [0:3];
    wire fc_pe_valid_array [0:3];
    
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Please fill in this code with other layers.
    // -> Conv1 is needed
    // -> Conv2 is needed
    // note: PE connection has to be updated, if you instantiate new layers.
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    // instantiate processing element
    LUT_PE Upe1(
        .clk(clk),
        .en(pe_ena[0]),
        // valid signal
         .valid1(c1_pe_valid), /////////////////// <<-- this is for test (uncomment this port later.)
         .valid2(c2_pe_valid_array[0]), /////////////////// <<-- this is for test (uncomment this port later.)
        .valid3(fc_pe_valid_array[0]),
        // input data
        .dina(pe_input[0]),
        .dinb(pe_weight[0]),
        // output data
         .dout1(c1_pe_dout), /////////////////// <<-- this is for test (uncomment this port later.)
         .dout2(c2_pe_dout[0]), /////////////////// <<-- this is for test (uncomment this port later.)
        .dout3(fc_pe_dout[0])
    );
    LUT_PE Upe2(
        .clk(clk),
        .en(pe_ena[1]),
        // valid signal
        // .valid1(c1_pe_valid), /////////////////// <<-- this is for test (uncomment this port later.)
         .valid2(c2_pe_valid_array[1]), /////////////////// <<-- this is for test (uncomment this port later.)
        .valid3(fc_pe_valid_array[1]),
        // input data
        .dina(pe_input[1]),
        .dinb(pe_weight[1]),
        // output data
        // .dout1(c1_pe_dout), /////////////////// <<-- this is for test (uncomment this port later.)
         .dout2(c2_pe_dout[1]), /////////////////// <<-- this is for test (uncomment this port later.)
        .dout3(fc_pe_dout[1])
    );
    LUT_PE Upe3(
        .clk(clk),
        .en(pe_ena[2]),
        // valid signal
        // .valid1(c1_pe_valid), /////////////////// <<-- this is for test (uncomment this port later.)
         .valid2(c2_pe_valid_array[2]), /////////////////// <<-- this is for test (uncomment this port later.)
        .valid3(fc_pe_valid_array[2]),
        // input data
        .dina(pe_input[2]),
        .dinb(pe_weight[2]),
        // output data
        // .dout1(c1_pe_dout), /////////////////// <<-- this is for test (uncomment this port later.)
         .dout2(c2_pe_dout[2]), /////////////////// <<-- this is for test (uncomment this port later.)
        .dout3(fc_pe_dout[2])
    );
    // one LUT PE used !!!
    LUT_PE Upe4(
        .clk(clk),
        .en(pe_ena[3]),
        // valid signal
//         .valid1(c1_pe_valid), /////////////////// <<-- this is for test (uncomment this port later.)
         .valid2(c2_pe_valid_array[3]), /////////////////// <<-- this is for test (uncomment this port later.)
        .valid3(fc_pe_valid_array[3]),
        // input data
        .dina(pe_input[3]),
        .dinb(pe_weight[3]),
        // output data
        // .dout1(c1_pe_dout), /////////////////// <<-- this is for test (uncomment this port later.)
         .dout2(c2_pe_dout[3]), /////////////////// <<-- this is for test (uncomment this port later.)
        .dout3(fc_pe_dout[3])
    );

    // ===================================================================

endmodule