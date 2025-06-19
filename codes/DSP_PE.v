`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/07 07:28:41
// Design Name: 
// Module Name: DSP_PE
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


module DSP_PE(
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
//output wire [63:0]  dout2 // total 8 output
    );
    wire signed [7:0] activation [0:71];
    wire signed [7:0] filter1 [0:71];
    //wire [7:0] filter2 [0:71];

    genvar i;
    generate    // 0:7 filter[0][0]
        for (i = 0; i < 72; i = i + 1) begin : gen_activation_filter
            assign activation[i] = dina[i*8 +: 8];
            assign filter1[i] = dinb[i*8 +: 8];
            //assign filter2[i] = dinc[i*8 +: 8];
        end
    endgenerate

    wire [24:0] A [0:71]; // 7:0   // filter1   
    wire [24:0] D [0:71]; // 23:16 // filter2
    wire [17:0] B [0:71]; // activation
    wire [47:0] C [0:71]; // +1 for output 1 if filter 2 is neg
    wire [32:0] P [0:71];

    genvar j;
    generate
        for (j = 0; j < 72; j = j + 1) begin : gen_mul
            assign A[j] = {{17{filter1[j][7]}}, filter1[j]}; // 25 bits, sign-extended if activation is negative
            //assign D[j] = {filter2[j][7], filter2[j], {16{1'b0}}}; // 25 bits: sign, filter2[7:0], 16 zeros
            assign D[j] = {25'd0}; // 25 bits: sign, filter2[7:0], 16 zeros
            //assign C[j] = {1'b0, filter1[j][7], 16'b0}; // 18 bits
            assign C[j] = {48'd0}; // 18 bits
            assign B[j] = {10'd0, activation[j]}; // 18 bits
        end
    endgenerate
    // Instantiating 72 dsp_macro_0 modules without generate
    dsp_macro_0 dsp_inst0 (.CLK(clk), .A(A[0]), .B(B[0]), .C(C[0]), .D(D[0]), .P(P[0]));
    dsp_macro_0 dsp_inst1 (.CLK(clk), .A(A[1]), .B(B[1]), .C(C[1]), .D(D[1]), .P(P[1]));
    dsp_macro_0 dsp_inst2 (.CLK(clk), .A(A[2]), .B(B[2]), .C(C[2]), .D(D[2]), .P(P[2]));
    dsp_macro_0 dsp_inst3 (.CLK(clk), .A(A[3]), .B(B[3]), .C(C[3]), .D(D[3]), .P(P[3]));
    dsp_macro_0 dsp_inst4 (.CLK(clk), .A(A[4]), .B(B[4]), .C(C[4]), .D(D[4]), .P(P[4]));
    dsp_macro_0 dsp_inst5 (.CLK(clk), .A(A[5]), .B(B[5]), .C(C[5]), .D(D[5]), .P(P[5]));
    dsp_macro_0 dsp_inst6 (.CLK(clk), .A(A[6]), .B(B[6]), .C(C[6]), .D(D[6]), .P(P[6]));
    dsp_macro_0 dsp_inst7 (.CLK(clk), .A(A[7]), .B(B[7]), .C(C[7]), .D(D[7]), .P(P[7]));
    dsp_macro_0 dsp_inst8 (.CLK(clk), .A(A[8]), .B(B[8]), .C(C[8]), .D(D[8]), .P(P[8]));
    dsp_macro_0 dsp_inst9 (.CLK(clk), .A(A[9]), .B(B[9]), .C(C[9]), .D(D[9]), .P(P[9]));
    dsp_macro_0 dsp_inst10 (.CLK(clk), .A(A[10]), .B(B[10]), .C(C[10]), .D(D[10]), .P(P[10]));
    dsp_macro_0 dsp_inst11 (.CLK(clk), .A(A[11]), .B(B[11]), .C(C[11]), .D(D[11]), .P(P[11]));
    dsp_macro_0 dsp_inst12 (.CLK(clk), .A(A[12]), .B(B[12]), .C(C[12]), .D(D[12]), .P(P[12]));
    dsp_macro_0 dsp_inst13 (.CLK(clk), .A(A[13]), .B(B[13]), .C(C[13]), .D(D[13]), .P(P[13]));
    dsp_macro_0 dsp_inst14 (.CLK(clk), .A(A[14]), .B(B[14]), .C(C[14]), .D(D[14]), .P(P[14]));
    dsp_macro_0 dsp_inst15 (.CLK(clk), .A(A[15]), .B(B[15]), .C(C[15]), .D(D[15]), .P(P[15]));
    dsp_macro_0 dsp_inst16 (.CLK(clk), .A(A[16]), .B(B[16]), .C(C[16]), .D(D[16]), .P(P[16]));
    dsp_macro_0 dsp_inst17 (.CLK(clk), .A(A[17]), .B(B[17]), .C(C[17]), .D(D[17]), .P(P[17]));
    dsp_macro_0 dsp_inst18 (.CLK(clk), .A(A[18]), .B(B[18]), .C(C[18]), .D(D[18]), .P(P[18]));
    dsp_macro_0 dsp_inst19 (.CLK(clk), .A(A[19]), .B(B[19]), .C(C[19]), .D(D[19]), .P(P[19]));
    dsp_macro_0 dsp_inst20 (.CLK(clk), .A(A[20]), .B(B[20]), .C(C[20]), .D(D[20]), .P(P[20]));
    dsp_macro_0 dsp_inst21 (.CLK(clk), .A(A[21]), .B(B[21]), .C(C[21]), .D(D[21]), .P(P[21]));
    dsp_macro_0 dsp_inst22 (.CLK(clk), .A(A[22]), .B(B[22]), .C(C[22]), .D(D[22]), .P(P[22]));
    dsp_macro_0 dsp_inst23 (.CLK(clk), .A(A[23]), .B(B[23]), .C(C[23]), .D(D[23]), .P(P[23]));
    dsp_macro_0 dsp_inst24 (.CLK(clk), .A(A[24]), .B(B[24]), .C(C[24]), .D(D[24]), .P(P[24]));
    dsp_macro_0 dsp_inst25 (.CLK(clk), .A(A[25]), .B(B[25]), .C(C[25]), .D(D[25]), .P(P[25]));
    dsp_macro_0 dsp_inst26 (.CLK(clk), .A(A[26]), .B(B[26]), .C(C[26]), .D(D[26]), .P(P[26]));
    dsp_macro_0 dsp_inst27 (.CLK(clk), .A(A[27]), .B(B[27]), .C(C[27]), .D(D[27]), .P(P[27]));
    dsp_macro_0 dsp_inst28 (.CLK(clk), .A(A[28]), .B(B[28]), .C(C[28]), .D(D[28]), .P(P[28]));
    dsp_macro_0 dsp_inst29 (.CLK(clk), .A(A[29]), .B(B[29]), .C(C[29]), .D(D[29]), .P(P[29]));
    dsp_macro_0 dsp_inst30 (.CLK(clk), .A(A[30]), .B(B[30]), .C(C[30]), .D(D[30]), .P(P[30]));
    dsp_macro_0 dsp_inst31 (.CLK(clk), .A(A[31]), .B(B[31]), .C(C[31]), .D(D[31]), .P(P[31]));
    dsp_macro_0 dsp_inst32 (.CLK(clk), .A(A[32]), .B(B[32]), .C(C[32]), .D(D[32]), .P(P[32]));
    dsp_macro_0 dsp_inst33 (.CLK(clk), .A(A[33]), .B(B[33]), .C(C[33]), .D(D[33]), .P(P[33]));
    dsp_macro_0 dsp_inst34 (.CLK(clk), .A(A[34]), .B(B[34]), .C(C[34]), .D(D[34]), .P(P[34]));
    dsp_macro_0 dsp_inst35 (.CLK(clk), .A(A[35]), .B(B[35]), .C(C[35]), .D(D[35]), .P(P[35]));
    dsp_macro_0 dsp_inst36 (.CLK(clk), .A(A[36]), .B(B[36]), .C(C[36]), .D(D[36]), .P(P[36]));
    dsp_macro_0 dsp_inst37 (.CLK(clk), .A(A[37]), .B(B[37]), .C(C[37]), .D(D[37]), .P(P[37]));
    dsp_macro_0 dsp_inst38 (.CLK(clk), .A(A[38]), .B(B[38]), .C(C[38]), .D(D[38]), .P(P[38]));
    dsp_macro_0 dsp_inst39 (.CLK(clk), .A(A[39]), .B(B[39]), .C(C[39]), .D(D[39]), .P(P[39]));
    dsp_macro_0 dsp_inst40 (.CLK(clk), .A(A[40]), .B(B[40]), .C(C[40]), .D(D[40]), .P(P[40]));
    dsp_macro_0 dsp_inst41 (.CLK(clk), .A(A[41]), .B(B[41]), .C(C[41]), .D(D[41]), .P(P[41]));
    dsp_macro_0 dsp_inst42 (.CLK(clk), .A(A[42]), .B(B[42]), .C(C[42]), .D(D[42]), .P(P[42]));
    dsp_macro_0 dsp_inst43 (.CLK(clk), .A(A[43]), .B(B[43]), .C(C[43]), .D(D[43]), .P(P[43]));
    dsp_macro_0 dsp_inst44 (.CLK(clk), .A(A[44]), .B(B[44]), .C(C[44]), .D(D[44]), .P(P[44]));
    dsp_macro_0 dsp_inst45 (.CLK(clk), .A(A[45]), .B(B[45]), .C(C[45]), .D(D[45]), .P(P[45]));
    dsp_macro_0 dsp_inst46 (.CLK(clk), .A(A[46]), .B(B[46]), .C(C[46]), .D(D[46]), .P(P[46]));
    dsp_macro_0 dsp_inst47 (.CLK(clk), .A(A[47]), .B(B[47]), .C(C[47]), .D(D[47]), .P(P[47]));
    dsp_macro_0 dsp_inst48 (.CLK(clk), .A(A[48]), .B(B[48]), .C(C[48]), .D(D[48]), .P(P[48]));
    dsp_macro_0 dsp_inst49 (.CLK(clk), .A(A[49]), .B(B[49]), .C(C[49]), .D(D[49]), .P(P[49]));
    dsp_macro_0 dsp_inst50 (.CLK(clk), .A(A[50]), .B(B[50]), .C(C[50]), .D(D[50]), .P(P[50]));
    dsp_macro_0 dsp_inst51 (.CLK(clk), .A(A[51]), .B(B[51]), .C(C[51]), .D(D[51]), .P(P[51]));
    dsp_macro_0 dsp_inst52 (.CLK(clk), .A(A[52]), .B(B[52]), .C(C[52]), .D(D[52]), .P(P[52]));
    dsp_macro_0 dsp_inst53 (.CLK(clk), .A(A[53]), .B(B[53]), .C(C[53]), .D(D[53]), .P(P[53]));
    dsp_macro_0 dsp_inst54 (.CLK(clk), .A(A[54]), .B(B[54]), .C(C[54]), .D(D[54]), .P(P[54]));
    dsp_macro_0 dsp_inst55 (.CLK(clk), .A(A[55]), .B(B[55]), .C(C[55]), .D(D[55]), .P(P[55]));
    dsp_macro_0 dsp_inst56 (.CLK(clk), .A(A[56]), .B(B[56]), .C(C[56]), .D(D[56]), .P(P[56]));
    dsp_macro_0 dsp_inst57 (.CLK(clk), .A(A[57]), .B(B[57]), .C(C[57]), .D(D[57]), .P(P[57]));
    dsp_macro_0 dsp_inst58 (.CLK(clk), .A(A[58]), .B(B[58]), .C(C[58]), .D(D[58]), .P(P[58]));
    dsp_macro_0 dsp_inst59 (.CLK(clk), .A(A[59]), .B(B[59]), .C(C[59]), .D(D[59]), .P(P[59]));
    dsp_macro_0 dsp_inst60 (.CLK(clk), .A(A[60]), .B(B[60]), .C(C[60]), .D(D[60]), .P(P[60]));
    dsp_macro_0 dsp_inst61 (.CLK(clk), .A(A[61]), .B(B[61]), .C(C[61]), .D(D[61]), .P(P[61]));
    dsp_macro_0 dsp_inst62 (.CLK(clk), .A(A[62]), .B(B[62]), .C(C[62]), .D(D[62]), .P(P[62]));
    dsp_macro_0 dsp_inst63 (.CLK(clk), .A(A[63]), .B(B[63]), .C(C[63]), .D(D[63]), .P(P[63]));
    dsp_macro_0 dsp_inst64 (.CLK(clk), .A(A[64]), .B(B[64]), .C(C[64]), .D(D[64]), .P(P[64]));
    dsp_macro_0 dsp_inst65 (.CLK(clk), .A(A[65]), .B(B[65]), .C(C[65]), .D(D[65]), .P(P[65]));
    dsp_macro_0 dsp_inst66 (.CLK(clk), .A(A[66]), .B(B[66]), .C(C[66]), .D(D[66]), .P(P[66]));
    dsp_macro_0 dsp_inst67 (.CLK(clk), .A(A[67]), .B(B[67]), .C(C[67]), .D(D[67]), .P(P[67]));
    dsp_macro_0 dsp_inst68 (.CLK(clk), .A(A[68]), .B(B[68]), .C(C[68]), .D(D[68]), .P(P[68]));
    dsp_macro_0 dsp_inst69 (.CLK(clk), .A(A[69]), .B(B[69]), .C(C[69]), .D(D[69]), .P(P[69]));
    dsp_macro_0 dsp_inst70 (.CLK(clk), .A(A[70]), .B(B[70]), .C(C[70]), .D(D[70]), .P(P[70]));
    dsp_macro_0 dsp_inst71 (.CLK(clk), .A(A[71]), .B(B[71]), .C(C[71]), .D(D[71]), .P(P[71]));

    wire signed [14:0] mul1 [0:71];
    //wire signed [14:0] mul2 [0:71];
    generate
        for (j = 0; j < 72; j = j + 1) begin : gen_mul_output
            //assign mul2[j] = P[j][30:16]; // 16 bits
            assign mul1[j] = P[j][14:0];   // 9 bits
        end
    endgenerate

    reg shift1, shift2, shift3, shift4, shift5;
    always @(posedge clk) begin
        shift1 <= en;
        shift2 <= shift1;
        shift3 <= shift2;
        shift4 <= shift3;
        shift5 <= shift4;
    end
    assign valid1 = shift3;
    assign valid2 = shift4;
    assign valid3 = shift5;

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















    // wire signed [15:0] sum1_36 [0:35];
    // wire signed [15:0] sum2_36 [0:35];
    // wire signed [16:0] sum1_18 [0:17];
    // wire signed [16:0] sum2_18 [0:17];
    // reg  signed [17:0] sum1_9  [0:8];
    // reg  signed [17:0] sum2_9  [0:8];
    // wire signed [18:0] sum1_4  [0:3];
    // wire signed [18:0] sum2_4  [0:3];
    // wire signed [19:0] sum1_2  [0:1];
    // wire signed [19:0] sum2_2  [0:1];
    // wire signed [20:0] sum1_1;
    // wire signed [20:0] sum2_1;
    // reg  signed [21:0] sum1;
    // reg  signed [21:0] sum2;

    // genvar l;
    // generate
    //     for (l = 0; l < 36; l = l + 1) begin : gen_sum1_36
    //         assign sum1_36[l] = mul1[l*2] + mul1[l*2 + 1];
    //     end
    //     for (l = 0; l < 36; l = l + 1) begin : gen_sum2_36
    //         assign sum2_36[l] = mul2[l*2] + mul2[l*2 + 1];
    //     end
    //     for (l = 0; l < 18; l = l + 1) begin : gen_sum1_18
    //         assign sum1_18[l] = sum1_36[l*2] + sum1_36[l*2 + 1];
    //     end
    //     for (l = 0; l < 18; l = l + 1) begin : gen_sum2_18
    //         assign sum2_18[l] = sum2_36[l*2] + sum2_36[l*2 + 1];
    //     end
    // endgenerate
    
    // genvar m;
    // generate
    //     for (m = 0; m < 9; m = m + 1) begin : gen_sum1_9
    //         always @(posedge clk) begin
    //             sum1_9[m] <= sum1_18[m*2] + sum1_18[m*2 + 1];
    //             sum2_9[m] <= sum2_18[m*2] + sum2_18[m*2 + 1];
    //         end
    //     end
    // endgenerate

    // generate
    //     for (l = 0; l < 4; l = l + 1) begin : gen_sum1_4
    //         assign sum1_4[l] = sum1_9[l*2] + sum1_9[l*2 + 1];
    //     end
    //     for (l = 0; l < 4; l = l + 1) begin : gen_sum2_4
    //         assign sum2_4[l] = sum2_9[l*2] + sum2_9[l*2 + 1];
    //     end
    //     for (l = 0; l < 2; l = l + 1) begin : gen_sum1_2
    //         assign sum1_2[l] = sum1_4[l*2] + sum1_4[l*2 + 1];
    //     end
    //     for (l = 0; l < 2; l = l + 1) begin : gen_sum2_2
    //         assign sum2_2[l] = sum2_4[l*2] + sum2_4[l*2 + 1];
    //     end
    //     assign sum1_1 = sum1_2[0] + sum1_2[1];
    //     assign sum2_1 = sum2_2[0] + sum2_2[1];
    // endgenerate

    // always @(posedge clk) begin
    //     sum1 <= sum1_1 + sum1_9[8]; // 72nd mul
    //     sum2 <= sum2_1 + sum2_9[8]; // 72nd mul
    // end

    // assign dout1 = sum1; // 21 bits output
    // assign dout2 = sum2; // 21 bits output
endmodule