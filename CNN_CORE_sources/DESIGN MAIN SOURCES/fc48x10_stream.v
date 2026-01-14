`timescale 1ns / 1ps

(* use_dsp = "no" *)
module fully_connected (
    input  wire               clk,
    input  wire               rst_n,
    
    input  wire               in_valid,
    input  wire [7:0]         in_1, // Ch0
    input  wire [7:0]         in_2, // Ch1
    input  wire [7:0]         in_3, // Ch2

    output reg                out_valid,
    output reg  [3:0]         out_cls,
    output reg  signed [31:0] out_logit,
    output reg                out_last
);

    // 1. 메모리 로드
    reg signed [7:0]  w_mem [0:479];
    reg signed [31:0] b_mem [0:9];

    // ★ 수정된 부분: 절대 경로 사용
    initial begin
        $readmemh("Wd.txt", w_mem); 
        $readmemh("bd.txt", b_mem);
    end

    // 2. 제어 신호 및 파이프라인 레지스터
    reg [4:0]  cnt_in;
    reg [3:0]  cnt_out;
    reg        calc_busy;
    reg        out_busy;

    // 파이프라인 스테이지 제어 (Stage 0 -> Stage 1 -> Stage 2)
    reg        valid_st0;      // 가중치 읽기 유효
    reg [4:0]  cnt_in_st0;     
    
    reg        valid_st1;      // 곱셈 유효
    reg [4:0]  cnt_in_st1;

    // 입력 데이터 딜레이 (가중치 읽는 동안 기다려야 함)
    reg [7:0]  in_1_d, in_2_d, in_3_d;

    // 누적기
    reg signed [31:0] acc [0:9]; 

    // 3. 파이프라인 연산 (10개 병렬)
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : PE_ARRAY
            
            // [Stage 0] 가중치 읽기 (Registering)
            reg signed [7:0] w1, w2, w3;
            
            always @(posedge clk) begin
                // cnt_in에 맞춰 미리 읽어둠
                w1 <= w_mem[((cnt_in * 3) + 0) * 10 + i];
                w2 <= w_mem[((cnt_in * 3) + 1) * 10 + i];
                w3 <= w_mem[((cnt_in * 3) + 2) * 10 + i];
            end

            // [Stage 1] 곱셈 (Multiplier)
            // w1, w2, w3는 이미 1클럭 전의 cnt_in에 해당하는 값임.
            // 따라서 입력 데이터(in_1)도 1클럭 지연된 것(in_1_d)을 써야 짝이 맞음.
            reg signed [15:0] m1, m2, m3;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    m1 <= 0; m2 <= 0; m3 <= 0;
                end else if (valid_st0) begin
                    m1 <= $signed({1'b0, in_1_d}) * w1;
                    m2 <= $signed({1'b0, in_2_d}) * w2;
                    m3 <= $signed({1'b0, in_3_d}) * w3;
                end
            end

            // [Stage 2] 누적 (Accumulate)
            // 16비트 곱셈 결과 3개를 32비트 부호 확장(Sign Extension) 후 덧셈
            wire signed [31:0] sum_m;
            assign sum_m = {{16{m1[15]}}, m1} + {{16{m2[15]}}, m2} + {{16{m3[15]}}, m3};

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    acc[i] <= 0;
                end else if (valid_st1) begin
                    if (cnt_in_st1 == 0) begin
                        // 첫 번째 턴: Bias + 현재 합
                        acc[i] <= b_mem[i] + sum_m;
                    end else begin
                        // 그 외: 기존 Acc + 현재 합
                        acc[i] <= acc[i] + sum_m;
                    end
                end
            end
        end
    endgenerate

    // 4. 제어 로직
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_in <= 0; 
            valid_st0 <= 0; cnt_in_st0 <= 0;
            valid_st1 <= 0; cnt_in_st1 <= 0;
            
            cnt_out <= 0; calc_busy <= 0; out_busy <= 0;
            out_valid <= 0; out_last <= 0; out_cls <= 0; out_logit <= 0;
            
            in_1_d <= 0; in_2_d <= 0; in_3_d <= 0;
        end else begin
            // [입력 파이프라인]
            if (in_valid) begin
                calc_busy  <= 1;
                
                // Stage 0으로 넘기는 신호
                valid_st0  <= 1;
                cnt_in_st0 <= cnt_in;
                
                // 입력 데이터도 1클럭 딜레이 (가중치 읽는 시간과 동기화)
                in_1_d <= in_1;
                in_2_d <= in_2;
                in_3_d <= in_3;

                if (cnt_in == 15) begin
                    cnt_in <= 0;
                    calc_busy <= 0;
                end else begin
                    cnt_in <= cnt_in + 1;
                end
            end else begin
                valid_st0 <= 0;
            end

            // [Stage 0 -> Stage 1]
            valid_st1  <= valid_st0;
            cnt_in_st1 <= cnt_in_st0;

            // [출력 타이밍]
            // cnt_in_st1이 15이고, valid_st1이 1이면 -> Stage 2에서 마지막 누적 완료됨
            if (valid_st1 && (cnt_in_st1 == 15)) begin
                out_busy <= 1;
                cnt_out  <= 0;
            end

            // [결과 출력]
            if (out_busy) begin
                out_valid <= 1;
                out_cls   <= cnt_out;
                out_logit <= acc[cnt_out]; 

                if (cnt_out == 9) begin
                    out_last <= 1;
                    out_busy <= 0;
                    cnt_out  <= 0;
                end else begin
                    out_last <= 0;
                    cnt_out  <= cnt_out + 1;
                end
            end else begin
                out_valid <= 0;
                out_last  <= 0;
            end
        end
    end

endmodule