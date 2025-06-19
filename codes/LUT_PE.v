`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/08 00:04:49
// Design Name: 
// Module Name: LUT_PE
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


module LUT_PE(
input  wire         clk,
input  wire         en,
//output wire         valid1,
output wire         valid1, // conv1 out
output wire         valid2, // conv2 out
output wire         valid3, // fc out
input  wire  [575:0] dina, // ifmap activation
input  wire  [575:0] dinb, // filter 1
//input  wire  [575:0] dinc, // filter 2
output wire        [63:0]  dout1, // sum of 72 mul
output wire        [7:0]   dout2, // sum of 72 mul
output wire signed [21:0]  dout3 // fc out
    );
    wire signed [7:0] activation [0:71];
    wire signed [7:0] filter1 [0:71];
    
    reg  [575:0] dina_reg;
    reg  [575:0] dinb_reg;
    always @(posedge clk) begin
      dina_reg <= dina;
      dinb_reg <= dinb;
    end
    
    
    genvar i;
    generate    // 0:7 filter[0][0]
        for (i = 0; i < 72; i = i + 1) begin : gen_activation_filter
            assign activation[i] = dina_reg[i*8 +: 8];
            assign filter1[i] = dinb_reg[i*8 +: 8];
            //assign filter2[i] = dinc[i*8 +: 8];
        end
    endgenerate

    reg  signed [14:0] mul1 [0:71]; // 15 bits, sign-extended if activation is negative

    integer o;
    always @(posedge clk) begin
            for (o = 0; o < 72; o = o + 1) begin
                mul1[o] <= activation[o] * filter1[o];
            end
    end
    
    reg shift1, shift2, shift3, shift4, shift5;
    always @(posedge clk) begin
        shift1 <= en;
        shift2 <= shift1;
        shift3 <= shift2;
        shift4 <= shift3;
        shift5 <= shift4;
    end
    assign valid1 = shift3;
    assign valid3 = shift4;
    assign valid2 = shift5;


    wire signed [15:0] sum2 [0:31];
    wire signed [16:0] sum4 [0:15];
    wire signed [17:0] sum8 [0:7];
    reg  signed [18:0] sum9 [0:7];

    assign sum2[0] = mul1[0] + mul1[1]; // 16 bits
    assign sum2[1] = mul1[2] + mul1[3]; // 16 bits
    assign sum2[2] = mul1[4] + mul1[5]; // 16 bits
    assign sum2[3] = mul1[6] + mul1[7]; // 16 bits

    assign sum2[4] = mul1[9] + mul1[10]; // 16 bits
    assign sum2[5] = mul1[11] + mul1[12]; // 16 bits
    assign sum2[6] = mul1[13] + mul1[14]; // 16 bits
    assign sum2[7] = mul1[15] + mul1[16]; // 16 bits

    assign sum2[8] = mul1[18] + mul1[19]; // 16 bits
    assign sum2[9] = mul1[20] + mul1[21]; // 16 bits
    assign sum2[10] = mul1[22] + mul1[23]; // 16 bits
    assign sum2[11] = mul1[24] + mul1[25]; // 16 bits

    assign sum2[12] = mul1[27] + mul1[28]; // 16 bits
    assign sum2[13] = mul1[29] + mul1[30]; // 16 bits
    assign sum2[14] = mul1[31] + mul1[32]; // 16 bits
    assign sum2[15] = mul1[33] + mul1[34]; // 16 bits

    assign sum2[16] = mul1[36] + mul1[37]; // 16 bits
    assign sum2[17] = mul1[38] + mul1[39]; // 16 bits
    assign sum2[18] = mul1[40] + mul1[41]; // 16 bits
    assign sum2[19] = mul1[42] + mul1[43]; // 16 bits

    assign sum2[20] = mul1[45] + mul1[46]; // 16 bits
    assign sum2[21] = mul1[47] + mul1[48]; // 16 bits
    assign sum2[22] = mul1[49] + mul1[50]; // 16 bits
    assign sum2[23] = mul1[51] + mul1[52]; // 16 bits

    assign sum2[24] = mul1[54] + mul1[55]; // 16 bits
    assign sum2[25] = mul1[56] + mul1[57]; // 16 bits
    assign sum2[26] = mul1[58] + mul1[59]; // 16 bits
    assign sum2[27] = mul1[60] + mul1[61]; // 16 bits

    assign sum2[28] = mul1[63] + mul1[64]; // 16 bits
    assign sum2[29] = mul1[65] + mul1[66]; // 16 bits
    assign sum2[30] = mul1[67] + mul1[68]; // 16 bits
    assign sum2[31] = mul1[69] + mul1[70]; // 16 bits

    genvar m;
    
    generate 
        for (m = 0; m < 16; m = m + 1) begin : gen_sum4
            assign sum4[m] = sum2[m*2] + sum2[m*2 + 1]; // 17 bits
        end
        for (m = 0; m < 8; m = m + 1) begin : gen_sum8
            assign sum8[m] = sum4[m*2] + sum4[m*2 + 1]; // 18 bits
        end
    endgenerate

    always @(posedge clk) begin
        sum9[0] <= sum8[0] + mul1[8]; // 19 bits
        sum9[1] <= sum8[1] + mul1[17]; // 19 bits
        sum9[2] <= sum8[2] + mul1[26]; // 19 bits
        sum9[3] <= sum8[3] + mul1[35]; // 19 bits
        sum9[4] <= sum8[4] + mul1[44]; // 19 bits
        sum9[5] <= sum8[5] + mul1[53]; // 19 bits
        sum9[6] <= sum8[6] + mul1[62]; // 19 bits
        sum9[7] <= sum8[7] + mul1[71]; // 19 bits
    end
    genvar j;
    wire [7:0] clipped_conv1 [0:7];
    generate
        for (j = 0; j < 8; j = j + 1) begin : gen_clipped_conv1
            assign clipped_conv1[j] = (sum9[j][18]) ? 8'd0 : 
                                      (sum9[j][17:10] > 8'd127) ? 8'd127 : sum9[j][17:10]; // clip to 8 bits
        end
    endgenerate

    assign dout1 = {clipped_conv1[7], clipped_conv1[6], clipped_conv1[5], clipped_conv1[4],
                    clipped_conv1[3], clipped_conv1[2], clipped_conv1[1], clipped_conv1[0]}; // 64 bits output

    wire signed [19:0] sum18 [0:3];
    wire signed [20:0] sum36 [0:1];
    reg  signed [21:0] sum72;
    reg         [7:0]  clipped_conv2;

    assign sum18[0] = sum9[0] + sum9[1]; // 20 bits
    assign sum18[1] = sum9[2] + sum9[3]; // 20 bits
    assign sum18[2] = sum9[4] + sum9[5]; // 20 bits
    assign sum18[3] = sum9[6] + sum9[7]; // 20 bits
    assign sum36[0] = sum18[0] + sum18[1]; // 21 bits
    assign sum36[1] = sum18[2] + sum18[3]; // 21 bits
    always @(posedge clk) begin
        sum72 <= sum36[0] + sum36[1]; // 22 bits
        clipped_conv2 <= (sum72[21]) ? 8'd0 : 
                         (sum72[20:10] > 11'd127) ? 8'd127 : sum72[17:10]; // clip to 8 bits
    end

    assign dout2 = clipped_conv2; // 8 bits output
    assign dout3 = sum72; // 21 bits output


    
    
    
endmodule