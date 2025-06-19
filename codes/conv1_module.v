module conv1 (
    input wire clk,
    input wire resetn,
    input wire start,
    output wire done,
    
    // IMEM port B (read)
    output wire img_en,
    output wire [9:0] img_addr, // 784 = 28*28 of them -> 10 bit
    input wire [7:0] img_dout, // 8 bit input
    
    // WMEM port B (read) 
    // control data of BRAM outside of this module. the data from BRAM goes to PE Module
    output wire weight_en,
    output wire [6:0] weight_addr, // 7bit 85 of them
    input wire [2303:0] wmem_doutb,
    output wire [575:0] pe_weight, // 576 = 8bit * 9kernel * 8depth (9kernel mean 3x3kernel)
    output wire [575:0] pe_input,

    // Operand of PE Module
    output wire [575:0] buffer_data_out, // 576 = 8bit * 9kernel * 8depth (9kernel mean 3x3kernel)
    output wire buffer_data_valid,

    // PE Module
    input wire result_valid,
    input wire [63:0] result_in, // 64bit

    // OMEM port A (write)  
    // !!! slack 占쏙옙占쏙옙? register 占쌩곤옙 ? 짜占쏙옙
    output reg out_en, // output 72 BW
    output wire [9:0] out_addr, // 676 depth
    output wire [63:0] out_din
);
    reg [575:0] wmem_doutb_reg;
    always @(posedge clk or negedge resetn) begin
        if (~resetn) begin
            wmem_doutb_reg <= 0;
        end else begin
            wmem_doutb_reg <= wmem_doutb[575:0];
        end
    end
    assign pe_weight = wmem_doutb_reg;
    assign pe_input = buffer_data_out;


    // FSM states
    localparam IDLE = 2'd0;
    localparam CONV = 2'd1;
    localparam DONE = 2'd2;

    wire conv_done;

    reg [1:0] state, n_state;

    // Counters
    reg [9:0] img_cnt; // 784 = 28*28
    reg [4:0] stride_cnt; // 0 to 27
    reg img_load_done_reg;

    // Data storing regs
    reg [63:0] pe_output;

    // Pipeline registers
    reg [7:0] data_out0_pipe [0:2];
    reg [7:0] data_out1_pipe [0:2];
    reg [7:0] data_out2_pipe [0:2];
    reg [2:0] data_rdy_pipe;

    // FSM
    always @(posedge clk or negedge resetn) begin
        if(~resetn) state <= IDLE;
        else state <= n_state;
    end
    
    // FSM logic
    always @(*) begin
        case(state)
            IDLE: n_state = start ? CONV : IDLE;
            CONV: n_state = (conv_done) ? DONE : CONV;
            DONE: n_state = IDLE;
            default: n_state = IDLE;
        endcase
    end
    wire new_filter;
    assign new_filter = (state == DONE);
    // Counter controls
    always @(posedge clk) begin
        if (state == CONV) begin
            if(img_cnt < 783 && img_load_done_reg == 0) begin
                img_cnt <= img_cnt + 1;
            end else begin
                img_cnt <= img_cnt;
            end
        end else begin
            img_cnt <= 0;
        end
    end

    always @(posedge clk) begin
        if(state == CONV) begin
            if(img_cnt == 783) img_load_done_reg <= 1;
        end else begin
            img_load_done_reg <= 0;
        end
    end

    assign img_en = (state == CONV) && (img_load_done_reg == 0);
    assign img_addr = img_cnt;

    // img_valid_pipe
    reg [1:0] img_valid_pipe;
    always @(posedge clk) begin
        if(state == CONV) begin
            img_valid_pipe <= {img_valid_pipe[0], img_en};
        end else begin
            img_valid_pipe <= 0;
        end
    end

    // weight control
    assign weight_en = data_rdy_pipe[0];
    assign weight_addr = 0; // Will be controlled by external logic

    // Control signals
    wire data_push = img_valid_pipe[1];

    // stride counter control
    always @(posedge clk) begin
        if(state == CONV) begin
            if(data_rdy_pipe[2] == 1) begin
                if(stride_cnt < 27) stride_cnt <= stride_cnt + 1;
                else stride_cnt <= 0;
            end
        end else begin
            stride_cnt <= 0;
        end
    end

    assign buffer_data_valid = (state == CONV) && (stride_cnt != 26) && (stride_cnt != 27) && (data_rdy_pipe[2]);
    
    // Concatenate 8 times for 8 filters
    // 9占쏙옙占쏙옙 占쏙옙占쏙옙占싶몌옙 占쏙옙占쏙옙 占쏙옙占쏙옙占?? 8占쏙옙 占쌥븝옙
    wire [71:0] base_data = {
    data_out2_pipe[0], data_out2_pipe[1], data_out2_pipe[2],
    data_out1_pipe[0], data_out1_pipe[1], data_out1_pipe[2],
    data_out0_pipe[0], data_out0_pipe[1], data_out0_pipe[2]
    };

    assign buffer_data_out = {8{base_data}};

    // Result handling
    reg [9:0] out_cnt;
    
    always @(posedge clk) begin
        if(state == CONV) begin
            if(result_valid) begin
                pe_output <= result_in;
            end 
        end else begin
            pe_output <= 0;
        end
    end
    
    // pr_output占쏙옙 out_en占쏙옙 占쏙옙占쏙옙 占쏙옙占쏙옙占쏙옙 占쏙옙효
    always @(posedge clk) begin
        if(state == CONV) begin
            if(result_valid) begin // result_valid占쏙옙 1 clk delay 占쏙옙 占쏙옙占쏙옙. 
                out_en <= 1;
            end else begin
                out_en <= 0;
            end
        end else begin
            out_en <= 0;
        end
    end

    // out_cnt占쏙옙 out_en占쏙옙 1占쏙옙 占쏙옙占쏙옙 占쏙옙占쏙옙
    always @(posedge clk) begin
        if(state == CONV) begin
            if(out_en == 1) begin
                if(out_cnt < 675) out_cnt <= out_cnt + 1;   
                else out_cnt <= 0;
            end 
        end else begin
            out_cnt <= 0;
        end
    end

    assign out_addr = out_cnt;
    assign out_din = pe_output;
    assign conv_done = (out_cnt == 675) && (out_en == 1);
    assign done = (state == DONE);

    // Line buffer instance
    wire [7:0] data_out0, data_out1, data_out2;
    wire data_rdy;

    conv1_line_buffer line_buffer (
        .clk(clk),
        .resetn(resetn),
        .new_filter(new_filter),
        .data_push(data_push),
        .data_in(img_dout),
        .data_rdy(data_rdy),
        .data_out0(data_out0),
        .data_out1(data_out1),
        .data_out2(data_out2)
    );

    // Pipeline registers for line buffer outputs
    always @(posedge clk) begin
        if (state == CONV) begin
            data_out0_pipe[2] <= data_out0_pipe[1];  // [2] 가 옛날 꺼야 
            data_out0_pipe[1] <= data_out0_pipe[0];  // out2는 최신
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
        end
    end

endmodule