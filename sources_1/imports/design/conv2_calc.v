`timescale 1ns / 1ps

module conv2_calc #(
    parameter WEIGHT_FILE = "conv2_weight_1.txt",
    parameter DATA_BITS = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire in_valid,
    // 입력 포트 생략 (기존 코드와 동일)
    input  wire [DATA_BITS-1:0] ch1_0, ch1_1, ch1_2, ch1_3, ch1_4,
    input  wire [DATA_BITS-1:0] ch1_5, ch1_6, ch1_7, ch1_8, ch1_9,
    input  wire [DATA_BITS-1:0] ch1_10,ch1_11,ch1_12,ch1_13,ch1_14,
    input  wire [DATA_BITS-1:0] ch1_15,ch1_16,ch1_17,ch1_18,ch1_19,
    input  wire [DATA_BITS-1:0] ch1_20,ch1_21,ch1_22,ch1_23,ch1_24,

    input  wire [DATA_BITS-1:0] ch2_0, ch2_1, ch2_2, ch2_3, ch2_4,
    input  wire [DATA_BITS-1:0] ch2_5, ch2_6, ch2_7, ch2_8, ch2_9,
    input  wire [DATA_BITS-1:0] ch2_10,ch2_11,ch2_12,ch2_13,ch2_14,
    input  wire [DATA_BITS-1:0] ch2_15,ch2_16,ch2_17,ch2_18,ch2_19,
    input  wire [DATA_BITS-1:0] ch2_20,ch2_21,ch2_22,ch2_23,ch2_24,

    input  wire [DATA_BITS-1:0] ch3_0, ch3_1, ch3_2, ch3_3, ch3_4,
    input  wire [DATA_BITS-1:0] ch3_5, ch3_6, ch3_7, ch3_8, ch3_9,
    input  wire [DATA_BITS-1:0] ch3_10,ch3_11,ch3_12,ch3_13,ch3_14,
    input  wire [DATA_BITS-1:0] ch3_15,ch3_16,ch3_17,ch3_18,ch3_19,
    input  wire [DATA_BITS-1:0] ch3_20,ch3_21,ch3_22,ch3_23,ch3_24,

    output reg         out_valid,
    output reg  [7:0]  data_out
);

    // 1. 가중치 로드
    reg signed [7:0] w_mem [0:74];
    initial begin
        $readmemh(WEIGHT_FILE, w_mem);
    end

    // 2. 입력 데이터 매핑
    wire signed [8:0] d1[0:24];
    wire signed [8:0] d2[0:24];
    wire signed [8:0] d3[0:24];

    // (기존 assign 문들은 그대로 사용)
    assign d1[0]={1'b0,ch1_0}; assign d1[1]={1'b0,ch1_1}; assign d1[2]={1'b0,ch1_2}; assign d1[3]={1'b0,ch1_3}; assign d1[4]={1'b0,ch1_4};
    assign d1[5]={1'b0,ch1_5}; assign d1[6]={1'b0,ch1_6}; assign d1[7]={1'b0,ch1_7}; assign d1[8]={1'b0,ch1_8}; assign d1[9]={1'b0,ch1_9};
    assign d1[10]={1'b0,ch1_10}; assign d1[11]={1'b0,ch1_11}; assign d1[12]={1'b0,ch1_12}; assign d1[13]={1'b0,ch1_13}; assign d1[14]={1'b0,ch1_14};
    assign d1[15]={1'b0,ch1_15}; assign d1[16]={1'b0,ch1_16}; assign d1[17]={1'b0,ch1_17}; assign d1[18]={1'b0,ch1_18}; assign d1[19]={1'b0,ch1_19};
    assign d1[20]={1'b0,ch1_20}; assign d1[21]={1'b0,ch1_21}; assign d1[22]={1'b0,ch1_22}; assign d1[23]={1'b0,ch1_23}; assign d1[24]={1'b0,ch1_24};
    
    assign d2[0]={1'b0,ch2_0}; assign d2[1]={1'b0,ch2_1}; assign d2[2]={1'b0,ch2_2}; assign d2[3]={1'b0,ch2_3}; assign d2[4]={1'b0,ch2_4};
    assign d2[5]={1'b0,ch2_5}; assign d2[6]={1'b0,ch2_6}; assign d2[7]={1'b0,ch2_7}; assign d2[8]={1'b0,ch2_8}; assign d2[9]={1'b0,ch2_9};
    assign d2[10]={1'b0,ch2_10}; assign d2[11]={1'b0,ch2_11}; assign d2[12]={1'b0,ch2_12}; assign d2[13]={1'b0,ch2_13}; assign d2[14]={1'b0,ch2_14};
    assign d2[15]={1'b0,ch2_15}; assign d2[16]={1'b0,ch2_16}; assign d2[17]={1'b0,ch2_17}; assign d2[18]={1'b0,ch2_18}; assign d2[19]={1'b0,ch2_19};
    assign d2[20]={1'b0,ch2_20}; assign d2[21]={1'b0,ch2_21}; assign d2[22]={1'b0,ch2_22}; assign d2[23]={1'b0,ch2_23}; assign d2[24]={1'b0,ch2_24};

    assign d3[0]={1'b0,ch3_0}; assign d3[1]={1'b0,ch3_1}; assign d3[2]={1'b0,ch3_2}; assign d3[3]={1'b0,ch3_3}; assign d3[4]={1'b0,ch3_4};
    assign d3[5]={1'b0,ch3_5}; assign d3[6]={1'b0,ch3_6}; assign d3[7]={1'b0,ch3_7}; assign d3[8]={1'b0,ch3_8}; assign d3[9]={1'b0,ch3_9};
    assign d3[10]={1'b0,ch3_10}; assign d3[11]={1'b0,ch3_11}; assign d3[12]={1'b0,ch3_12}; assign d3[13]={1'b0,ch3_13}; assign d3[14]={1'b0,ch3_14};
    assign d3[15]={1'b0,ch3_15}; assign d3[16]={1'b0,ch3_16}; assign d3[17]={1'b0,ch3_17}; assign d3[18]={1'b0,ch3_18}; assign d3[19]={1'b0,ch3_19};
    assign d3[20]={1'b0,ch3_20}; assign d3[21]={1'b0,ch3_21}; assign d3[22]={1'b0,ch3_22}; assign d3[23]={1'b0,ch3_23}; assign d3[24]={1'b0,ch3_24};

    // =================================================================
    // [Stage 1] 곱셈 (Multiplication) - ★ 32비트로 확장
    // =================================================================
    reg signed [31:0] mult_ch1 [0:24]; // 16bit -> 32bit
    reg signed [31:0] mult_ch2 [0:24];
    reg signed [31:0] mult_ch3 [0:24];
    reg               valid_st1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_st1 <= 0;
        end else begin
            valid_st1 <= in_valid;
            if (in_valid) begin
                // Ch1 (코드 생략된 부분도 채워 넣으세요, 기존과 로직 동일)
                mult_ch1[0] <= d1[0]*w_mem[0];   mult_ch1[1] <= d1[1]*w_mem[1];   mult_ch1[2] <= d1[2]*w_mem[2];   mult_ch1[3] <= d1[3]*w_mem[3];   mult_ch1[4] <= d1[4]*w_mem[4];
                mult_ch1[5] <= d1[5]*w_mem[5];   mult_ch1[6] <= d1[6]*w_mem[6];   mult_ch1[7] <= d1[7]*w_mem[7];   mult_ch1[8] <= d1[8]*w_mem[8];   mult_ch1[9] <= d1[9]*w_mem[9];
                mult_ch1[10]<= d1[10]*w_mem[10]; mult_ch1[11]<= d1[11]*w_mem[11]; mult_ch1[12]<= d1[12]*w_mem[12]; mult_ch1[13]<= d1[13]*w_mem[13]; mult_ch1[14]<= d1[14]*w_mem[14];
                mult_ch1[15]<= d1[15]*w_mem[15]; mult_ch1[16]<= d1[16]*w_mem[16]; mult_ch1[17]<= d1[17]*w_mem[17]; mult_ch1[18]<= d1[18]*w_mem[18]; mult_ch1[19]<= d1[19]*w_mem[19];
                mult_ch1[20]<= d1[20]*w_mem[20]; mult_ch1[21]<= d1[21]*w_mem[21]; mult_ch1[22]<= d1[22]*w_mem[22]; mult_ch1[23]<= d1[23]*w_mem[23]; mult_ch1[24]<= d1[24]*w_mem[24];
                
                // Ch2
                mult_ch2[0] <= d2[0]*w_mem[25];  mult_ch2[1] <= d2[1]*w_mem[26];  mult_ch2[2] <= d2[2]*w_mem[27];  mult_ch2[3] <= d2[3]*w_mem[28];  mult_ch2[4] <= d2[4]*w_mem[29];
                mult_ch2[5] <= d2[5]*w_mem[30];  mult_ch2[6] <= d2[6]*w_mem[31];  mult_ch2[7] <= d2[7]*w_mem[32];  mult_ch2[8] <= d2[8]*w_mem[33];  mult_ch2[9] <= d2[9]*w_mem[34];
                mult_ch2[10]<= d2[10]*w_mem[35]; mult_ch2[11]<= d2[11]*w_mem[36]; mult_ch2[12]<= d2[12]*w_mem[37]; mult_ch2[13]<= d2[13]*w_mem[38]; mult_ch2[14]<= d2[14]*w_mem[39];
                mult_ch2[15]<= d2[15]*w_mem[40]; mult_ch2[16]<= d2[16]*w_mem[41]; mult_ch2[17]<= d2[17]*w_mem[42]; mult_ch2[18]<= d2[18]*w_mem[43]; mult_ch2[19]<= d2[19]*w_mem[44];
                mult_ch2[20]<= d2[20]*w_mem[45]; mult_ch2[21]<= d2[21]*w_mem[46]; mult_ch2[22]<= d2[22]*w_mem[47]; mult_ch2[23]<= d2[23]*w_mem[48]; mult_ch2[24]<= d2[24]*w_mem[49];

                // Ch3
                mult_ch3[0] <= d3[0]*w_mem[50];  mult_ch3[1] <= d3[1]*w_mem[51];  mult_ch3[2] <= d3[2]*w_mem[52];  mult_ch3[3] <= d3[3]*w_mem[53];  mult_ch3[4] <= d3[4]*w_mem[54];
                mult_ch3[5] <= d3[5]*w_mem[55];  mult_ch3[6] <= d3[6]*w_mem[56];  mult_ch3[7] <= d3[7]*w_mem[57];  mult_ch3[8] <= d3[8]*w_mem[58];  mult_ch3[9] <= d3[9]*w_mem[59];
                mult_ch3[10]<= d3[10]*w_mem[60]; mult_ch3[11]<= d3[11]*w_mem[61]; mult_ch3[12]<= d3[12]*w_mem[62]; mult_ch3[13]<= d3[13]*w_mem[63]; mult_ch3[14]<= d3[14]*w_mem[64];
                mult_ch3[15]<= d3[15]*w_mem[65]; mult_ch3[16]<= d3[16]*w_mem[66]; mult_ch3[17]<= d3[17]*w_mem[67]; mult_ch3[18]<= d3[18]*w_mem[68]; mult_ch3[19]<= d3[19]*w_mem[69];
                mult_ch3[20]<= d3[20]*w_mem[70]; mult_ch3[21]<= d3[21]*w_mem[71]; mult_ch3[22]<= d3[22]*w_mem[72]; mult_ch3[23]<= d3[23]*w_mem[73]; mult_ch3[24]<= d3[24]*w_mem[74];
            end
        end
    end

    // =================================================================
    // [Stage 2] 중간 덧셈 (Partial Sum)
    // =================================================================
    reg signed [31:0] ps_ch1 [0:4];
    reg signed [31:0] ps_ch2 [0:4];
    reg signed [31:0] ps_ch3 [0:4];
    reg               valid_st2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_st2 <= 0;
        end else begin
            valid_st2 <= valid_st1;
            if (valid_st1) begin
                // mult_ch가 이제 32비트라 오버플로우 없이 안전하게 더해짐
                ps_ch1[0] <= mult_ch1[0]  + mult_ch1[1]  + mult_ch1[2]  + mult_ch1[3]  + mult_ch1[4];
                ps_ch1[1] <= mult_ch1[5]  + mult_ch1[6]  + mult_ch1[7]  + mult_ch1[8]  + mult_ch1[9];
                ps_ch1[2] <= mult_ch1[10] + mult_ch1[11] + mult_ch1[12] + mult_ch1[13] + mult_ch1[14];
                ps_ch1[3] <= mult_ch1[15] + mult_ch1[16] + mult_ch1[17] + mult_ch1[18] + mult_ch1[19];
                ps_ch1[4] <= mult_ch1[20] + mult_ch1[21] + mult_ch1[22] + mult_ch1[23] + mult_ch1[24];

                ps_ch2[0] <= mult_ch2[0]  + mult_ch2[1]  + mult_ch2[2]  + mult_ch2[3]  + mult_ch2[4];
                ps_ch2[1] <= mult_ch2[5]  + mult_ch2[6]  + mult_ch2[7]  + mult_ch2[8]  + mult_ch2[9];
                ps_ch2[2] <= mult_ch2[10] + mult_ch2[11] + mult_ch2[12] + mult_ch2[13] + mult_ch2[14];
                ps_ch2[3] <= mult_ch2[15] + mult_ch2[16] + mult_ch2[17] + mult_ch2[18] + mult_ch2[19];
                ps_ch2[4] <= mult_ch2[20] + mult_ch2[21] + mult_ch2[22] + mult_ch2[23] + mult_ch2[24];

                ps_ch3[0] <= mult_ch3[0]  + mult_ch3[1]  + mult_ch3[2]  + mult_ch3[3]  + mult_ch3[4];
                ps_ch3[1] <= mult_ch3[5]  + mult_ch3[6]  + mult_ch3[7]  + mult_ch3[8]  + mult_ch3[9];
                ps_ch3[2] <= mult_ch3[10] + mult_ch3[11] + mult_ch3[12] + mult_ch3[13] + mult_ch3[14];
                ps_ch3[3] <= mult_ch3[15] + mult_ch3[16] + mult_ch3[17] + mult_ch3[18] + mult_ch3[19];
                ps_ch3[4] <= mult_ch3[20] + mult_ch3[21] + mult_ch3[22] + mult_ch3[23] + mult_ch3[24];
            end
        end
    end

    // Stage 3, Stage 4는 기존 로직(32비트 덧셈) 그대로 둬도 안전합니다.
    // ... (기존 코드 유지) ...
    
    reg signed [31:0] sum_ch1, sum_ch2, sum_ch3;
    reg               valid_st3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_ch1 <= 0; sum_ch2 <= 0; sum_ch3 <= 0;
            valid_st3 <= 0;
        end else begin
            valid_st3 <= valid_st2;
            if (valid_st2) begin
                sum_ch1 <= ps_ch1[0] + ps_ch1[1] + ps_ch1[2] + ps_ch1[3] + ps_ch1[4];
                sum_ch2 <= ps_ch2[0] + ps_ch2[1] + ps_ch2[2] + ps_ch2[3] + ps_ch2[4];
                sum_ch3 <= ps_ch3[0] + ps_ch3[1] + ps_ch3[2] + ps_ch3[3] + ps_ch3[4];
            end
        end
    end

    wire signed [31:0] total_sum = sum_ch1 + sum_ch2 + sum_ch3;
    wire signed [31:0] raw = (total_sum + 32'sd64) >>> 7;
    // 부호 체크 raw[31] 사용 권장
    wire [7:0] clamp = (raw[31]) ? 8'd0 : (raw > 32'sd255) ? 8'd255 : raw[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 0;
            data_out  <= 0;
        end else begin
            out_valid <= valid_st3;
            if (valid_st3) begin
                data_out <= clamp;
            end
        end
    end

endmodule