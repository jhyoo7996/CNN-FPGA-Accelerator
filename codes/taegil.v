module img_cnt #(
    parameter IMG_NUM = 250,
    parameter IMG_BW = $clog2(IMG_NUM * 784),
    parameter OUT_BW = $clog2(IMG_NUM * 10)
)(
    input wire clk,
    input wire resetn,
    input wire outer_start,
    input wire inner_done,
    input wire [9:0] c1_imem_addrb,
    input wire [3:0] fc_omem_addra,

    output reg inner_start,
    output reg outer_done,
    output wire [IMG_BW-1:0] c1_imem_addrb_cnted,
    output wire [OUT_BW-1:0] fc_omem_addra_cnted
);

// outer_start가 들어오면 inner_start에 pulse 주기
// 이후 outer_done이 들어오면 inner_start 에 pulse 주기
// inner_done이 들어오면 counter 1 증가 (원래는 0)
// c1_imem_addrb_cnted 는 c1_imem_addrb + counter*784
// fc_omem_addra_cnted 는 fc_omem_addra + counter*10
// 만약 outer_done이 들어왔는데 counter 가 IMG_NUM - 1 이면 -> counter 초기화 및 outer_done 에 pulse 주기

    // 상태 정의
    localparam IDLE = 2'b00;
    localparam ACTIVE = 2'b01;
    localparam DONE = 2'b10;

    // 현재 상태와 다음 상태
    reg [1:0] state, next_state;
    
    // 이미지 카운터
    reg [$clog2(IMG_NUM)-1:0] counter;
    wire is_last_img;
    
    // 카운터가 마지막 이미지인지 확인
    assign is_last_img = (counter == IMG_NUM - 1);
    
    // 주소 계산 (counter에 784와 10을 곱함)
    assign c2_imem_addrb_cnted = c1_imem_addrb + (counter * 784);  // 각 이미지는 784개의 픽셀을 가짐
    assign fc_omem_addra_cnted = fc_omem_addra + (counter * 10);   // 각 이미지는 10개의 출력을 가짐

    // 상태 전이 로직
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 다음 상태 결정 로직
    always @(*) begin
        case (state)
            IDLE: next_state = outer_start ? ACTIVE : IDLE;
            ACTIVE: next_state = (inner_done && is_last_img) ? DONE : ACTIVE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // 카운터 로직
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            counter <= 0;
        end else begin
            if (state == IDLE) begin
                counter <= 0;
            end else if (state == ACTIVE && inner_done) begin
                if (is_last_img) begin
                    counter <= 0;
                end else begin
                    counter <= counter + 1;  // 다음 이미지로 이동
                end
            end
        end
    end

    // 출력 신호 생성 로직
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            inner_start <= 0;
            outer_done <= 0;
        end else begin
            // inner_start pulse 생성
            inner_start <= (state == IDLE && outer_start) || 
                          (state == ACTIVE && inner_done && !is_last_img);
            
            // outer_done 신호 생성 - outer_start가 들어올 때까지 유지
            if (outer_start) begin
                outer_done <= 0;
            end else if (state == ACTIVE && inner_done && is_last_img) begin
                outer_done <= 1;
            end
        end
    end

endmodule
