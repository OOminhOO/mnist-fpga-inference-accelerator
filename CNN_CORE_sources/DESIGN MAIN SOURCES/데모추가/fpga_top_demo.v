`timescale 1ns / 1ps

module fpga_top_demo(
    input  wire       sys_clk,    // 125MHz
    input  wire       rst_btn,    // BTN0
    input  wire       start_btn,  // BTN1
    input  wire [3:0] sw,         // SW[3:0] (이미지 선택)
    output wire [3:0] led,        // LED[3:0] (결과)
    output wire       done_led    // 완료 확인용 LED (선택사항)
    );

    wire rst_n = ~rst_btn;
    
    // CNN 신호
    reg  [7:0] data_in;
    reg        data_valid;
    wire [3:0] decision;
    wire       out_valid;
    
    // ROM 신호
    wire [7:0] rom_data;
    reg  [9:0] pixel_cnt;
    
    // 상태 머신
    localparam IDLE  = 2'b00;
    localparam RUN   = 2'b01;
    localparam DONE  = 2'b10;
    reg [1:0] state;

    // ★ 수정된 ROM 모듈 연결 (16 images)
    rom_16_images u_rom (
        .img_idx   (sw),        // 스위치 4개 연결
        .pixel_idx (pixel_cnt),
        .data_out  (rom_data)
    );

    // CNN 가속기
    cnn_core_top u_cnn (
        .clk        (sys_clk),
        .rst_n      (rst_n),
        .data_in    (data_in),
        .data_valid (data_valid),
        .decision   (decision),
        .out_valid  (out_valid)
    );

    // 결과 저장
    reg [3:0] result_reg;
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) result_reg <= 0;
        else if (out_valid) result_reg <= decision;
    end
    
    assign led = result_reg;
    assign done_led = (state == DONE);

    // 제어 로직
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            pixel_cnt  <= 0;
            data_valid <= 0;
            data_in    <= 0;
        end else begin
            case (state)
                IDLE: begin
                    pixel_cnt  <= 0;
                    data_valid <= 0;
                    if (start_btn) state <= RUN; 
                end

                RUN: begin
                    if (pixel_cnt < 784) begin
                        data_valid <= 1;
                        data_in    <= rom_data;
                        pixel_cnt  <= pixel_cnt + 1;
                    end else begin
                        data_valid <= 0;
                        data_in    <= 0;
                        if (out_valid) state <= DONE;
                    end
                end

                DONE: begin
                    if (!start_btn) state <= IDLE;
                end
            endcase
        end
    end
endmodule