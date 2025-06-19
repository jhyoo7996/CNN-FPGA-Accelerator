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

// outer_start�� ������ inner_start�� pulse �ֱ�
// ���� outer_done�� ������ inner_start �� pulse �ֱ�
// inner_done�� ������ counter 1 ���� (������ 0)
// c1_imem_addrb_cnted �� c1_imem_addrb + counter*784
// fc_omem_addra_cnted �� fc_omem_addra + counter*10
// ���� outer_done�� ���Դµ� counter �� IMG_NUM - 1 �̸� -> counter �ʱ�ȭ �� outer_done �� pulse �ֱ�

    // ���� ����
    localparam IDLE = 2'b00;
    localparam ACTIVE = 2'b01;
    localparam DONE = 2'b10;

    // ���� ���¿� ���� ����
    reg [1:0] state, next_state;
    
    // �̹��� ī����
    reg [$clog2(IMG_NUM)-1:0] counter;
    wire is_last_img;
    
    // ī���Ͱ� ������ �̹������� Ȯ��
    assign is_last_img = (counter == IMG_NUM - 1);
    
    // �ּ� ��� (counter�� 784�� 10�� ����)
    assign c2_imem_addrb_cnted = c1_imem_addrb + (counter * 784);  // �� �̹����� 784���� �ȼ��� ����
    assign fc_omem_addra_cnted = fc_omem_addra + (counter * 10);   // �� �̹����� 10���� ����� ����

    // ���� ���� ����
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // ���� ���� ���� ����
    always @(*) begin
        case (state)
            IDLE: next_state = outer_start ? ACTIVE : IDLE;
            ACTIVE: next_state = (inner_done && is_last_img) ? DONE : ACTIVE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // ī���� ����
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
                    counter <= counter + 1;  // ���� �̹����� �̵�
                end
            end
        end
    end

    // ��� ��ȣ ���� ����
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            inner_start <= 0;
            outer_done <= 0;
        end else begin
            // inner_start pulse ����
            inner_start <= (state == IDLE && outer_start) || 
                          (state == ACTIVE && inner_done && !is_last_img);
            
            // outer_done ��ȣ ���� - outer_start�� ���� ������ ����
            if (outer_start) begin
                outer_done <= 0;
            end else if (state == ACTIVE && inner_done && is_last_img) begin
                outer_done <= 1;
            end
        end
    end

endmodule
