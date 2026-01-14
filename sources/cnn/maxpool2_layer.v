`timescale 1ns / 1ps

module maxpool2_layer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [7:0]  in_1, in_2, in_3,
    output reg         out_valid,
    output reg  [7:0]  out_1, out_2, out_3
);

    // ★ Conv2의 출력 크기는 8x8 이므로 IMG_WIDTH = 8
    localparam IMG_WIDTH = 8; 

    // 라인 버퍼 & 윈도우 레지스터
    reg [7:0] lb_ch1 [0:IMG_WIDTH-1];
    reg [7:0] lb_ch2 [0:IMG_WIDTH-1];
    reg [7:0] lb_ch3 [0:IMG_WIDTH-1];

    reg [7:0] w1_tl, w1_tr, w1_bl, w1_br;
    reg [7:0] w2_tl, w2_tr, w2_bl, w2_br;
    reg [7:0] w3_tl, w3_tr, w3_bl, w3_br;

    reg [3:0] col_cnt; // 8까지 세야 하므로 4bit면 충분
    reg [3:0] row_cnt;
    reg calc_en;       // 1클럭 지연용

    integer k;
    initial begin
        for(k=0; k<IMG_WIDTH; k=k+1) begin
            lb_ch1[k]=0; lb_ch2[k]=0; lb_ch3[k]=0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            col_cnt <= 0; row_cnt <= 0;
            out_valid <= 0; calc_en <= 0;
            out_1 <= 0; out_2 <= 0; out_3 <= 0;
            w1_tl<=0; w1_tr<=0; w1_bl<=0; w1_br<=0;
            w2_tl<=0; w2_tr<=0; w2_bl<=0; w2_br<=0;
            w3_tl<=0; w3_tr<=0; w3_bl<=0; w3_br<=0;
        end else begin
            if(in_valid) begin
                // 좌표 계산
                if(col_cnt == IMG_WIDTH-1) begin
                    col_cnt <= 0;
                    if(row_cnt == IMG_WIDTH-1) row_cnt <= 0;
                    else row_cnt <= row_cnt + 1;
                end else begin
                    col_cnt <= col_cnt + 1;
                end

                // 윈도우 시프트 (행 시작 시 좌측 초기화)
                if(col_cnt == 0) begin
                    w1_tl <= 0; w1_bl <= 0;
                    w2_tl <= 0; w2_bl <= 0;
                    w3_tl <= 0; w3_bl <= 0;
                end else begin
                    w1_tl <= w1_tr; w1_bl <= w1_br;
                    w2_tl <= w2_tr; w2_bl <= w2_br;
                    w3_tl <= w3_tr; w3_bl <= w3_br;
                end

                // 우측 데이터 로드
                w1_tr <= lb_ch1[col_cnt]; w1_br <= in_1; lb_ch1[col_cnt] <= in_1;
                w2_tr <= lb_ch2[col_cnt]; w2_br <= in_2; lb_ch2[col_cnt] <= in_2;
                w3_tr <= lb_ch3[col_cnt]; w3_br <= in_3; lb_ch3[col_cnt] <= in_3;

                // 계산 트리거 (홀수 행, 홀수 열)
                if(row_cnt[0] && col_cnt[0]) calc_en <= 1;
                else calc_en <= 0;

            end else begin
                calc_en <= 0;
            end

            // 출력 (1클럭 지연)
            if(calc_en) begin
                out_valid <= 1;
                out_1 <= func_max4(w1_tl, w1_tr, w1_bl, w1_br);
                out_2 <= func_max4(w2_tl, w2_tr, w2_bl, w2_br);
                out_3 <= func_max4(w3_tl, w3_tr, w3_bl, w3_br);
            end else begin
                out_valid <= 0;
            end
        end
    end

    function [7:0] func_max4;
        input [7:0] v1, v2, v3, v4;
        reg [7:0] m1, m2;
        begin
            m1 = (v1 > v2) ? v1 : v2;
            m2 = (v3 > v4) ? v3 : v4;
            func_max4 = (m1 > m2) ? m1 : m2;
        end
    endfunction
endmodule