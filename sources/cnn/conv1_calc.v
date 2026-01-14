`timescale 1ns / 1ps

module conv1_calc #(
    parameter WEIGHT_FILE = "conv1_weight_1.txt"
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    // 입력 포트 유지
    input  wire [7:0]  data_in_0,  data_in_1,  data_in_2,  data_in_3,  data_in_4,
    input  wire [7:0]  data_in_5,  data_in_6,  data_in_7,  data_in_8,  data_in_9,
    input  wire [7:0]  data_in_10, data_in_11, data_in_12, data_in_13, data_in_14,
    input  wire [7:0]  data_in_15, data_in_16, data_in_17, data_in_18, data_in_19,
    input  wire [7:0]  data_in_20, data_in_21, data_in_22, data_in_23, data_in_24,

    output reg         out_valid,
    output reg  [7:0]  data_out
);

    // 1. 가중치 로드
    reg signed [7:0] w_mem [0:24];
    initial begin
        $readmemh(WEIGHT_FILE, w_mem);
    end

    // 2. 입력 매핑 (9bit signed)
    wire signed [8:0] d[0:24];
    assign d[0]={1'b0,data_in_0};   assign d[1]={1'b0,data_in_1};   assign d[2]={1'b0,data_in_2};   assign d[3]={1'b0,data_in_3};   assign d[4]={1'b0,data_in_4};
    assign d[5]={1'b0,data_in_5};   assign d[6]={1'b0,data_in_6};   assign d[7]={1'b0,data_in_7};   assign d[8]={1'b0,data_in_8};   assign d[9]={1'b0,data_in_9};
    assign d[10]={1'b0,data_in_10}; assign d[11]={1'b0,data_in_11}; assign d[12]={1'b0,data_in_12}; assign d[13]={1'b0,data_in_13}; assign d[14]={1'b0,data_in_14};
    assign d[15]={1'b0,data_in_15}; assign d[16]={1'b0,data_in_16}; assign d[17]={1'b0,data_in_17}; assign d[18]={1'b0,data_in_18}; assign d[19]={1'b0,data_in_19};
    assign d[20]={1'b0,data_in_20}; assign d[21]={1'b0,data_in_21}; assign d[22]={1'b0,data_in_22}; assign d[23]={1'b0,data_in_23}; assign d[24]={1'b0,data_in_24};

    // =================================================================
    // [Stage 1] 곱셈 (32bit)
    // =================================================================
    reg signed [31:0] mult [0:24];
    reg               valid_st1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_st1 <= 0;
        end else begin
            valid_st1 <= in_valid;
            if (in_valid) begin
                mult[0] <= d[0]*w_mem[0];   mult[1] <= d[1]*w_mem[1];   mult[2] <= d[2]*w_mem[2];   mult[3] <= d[3]*w_mem[3];   mult[4] <= d[4]*w_mem[4];
                mult[5] <= d[5]*w_mem[5];   mult[6] <= d[6]*w_mem[6];   mult[7] <= d[7]*w_mem[7];   mult[8] <= d[8]*w_mem[8];   mult[9] <= d[9]*w_mem[9];
                mult[10]<= d[10]*w_mem[10]; mult[11]<= d[11]*w_mem[11]; mult[12]<= d[12]*w_mem[12]; mult[13]<= d[13]*w_mem[13]; mult[14]<= d[14]*w_mem[14];
                mult[15]<= d[15]*w_mem[15]; mult[16]<= d[16]*w_mem[16]; mult[17]<= d[17]*w_mem[17]; mult[18]<= d[18]*w_mem[18]; mult[19]<= d[19]*w_mem[19];
                mult[20]<= d[20]*w_mem[20]; mult[21]<= d[21]*w_mem[21]; mult[22]<= d[22]*w_mem[22]; mult[23]<= d[23]*w_mem[23]; mult[24]<= d[24]*w_mem[24];
            end
        end
    end

    // =================================================================
    // [Stage 2] 부분 덧셈 (Partial Sum) - ★ 최적화 핵심
    // 25개를 한 번에 더하지 않고, 5개씩 나누어 덧셈한 뒤 레지스터에 저장합니다.
    // 이렇게 하면 Logic Delay가 획기적으로 줄어듭니다.
    // =================================================================
    reg signed [31:0] part_sum [0:4];
    reg               valid_st2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_st2 <= 0;
            part_sum[0] <= 0; part_sum[1] <= 0; part_sum[2] <= 0; 
            part_sum[3] <= 0; part_sum[4] <= 0;
        end else begin
            valid_st2 <= valid_st1;
            if (valid_st1) begin
                part_sum[0] <= mult[0]  + mult[1]  + mult[2]  + mult[3]  + mult[4];
                part_sum[1] <= mult[5]  + mult[6]  + mult[7]  + mult[8]  + mult[9];
                part_sum[2] <= mult[10] + mult[11] + mult[12] + mult[13] + mult[14];
                part_sum[3] <= mult[15] + mult[16] + mult[17] + mult[18] + mult[19];
                part_sum[4] <= mult[20] + mult[21] + mult[22] + mult[23] + mult[24];
            end
        end
    end

    // =================================================================
    // [Stage 3] 최종 덧셈 (Final Sum)
    // 부분합 5개를 더해서 최종 결과를 만듭니다.
    // =================================================================
    reg signed [31:0] sum;
    reg               valid_st3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= 0;
            valid_st3 <= 0;
        end else begin
            valid_st3 <= valid_st2;
            if (valid_st2) begin
                sum <= part_sum[0] + part_sum[1] + part_sum[2] + part_sum[3] + part_sum[4];
            end
        end
    end

    // =================================================================
    // [Stage 4] 출력 처리 (ReLU & Quantization)
    // =================================================================
    wire signed [31:0] raw = (sum + 32'sd64) >>> 7;
    wire [7:0] clamp = (raw[31]) ? 8'd0 : (raw > 32'sd255) ? 8'd255 : raw[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 0;
            data_out  <= 0;
        end else begin
            out_valid <= valid_st3; // Latency가 1 cycle 늘어났으므로 valid_st3 사용
            if (valid_st3) begin
                data_out <= clamp;
            end
        end
    end

endmodule