module cnn_core_top (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  data_in,
    input  wire        data_valid,   // TB가 784클럭 동안만 1

    output wire [3:0]  decision,
    output wire        out_valid
);

    // -----------------------------
    // Stage wires
    // -----------------------------
    wire v1, v2, v3, v4, v5;

    wire [7:0] conv1_out_1, conv1_out_2, conv1_out_3;
    wire [7:0] pool1_out_1, pool1_out_2, pool1_out_3;
    wire [7:0] conv2_out_1, conv2_out_2, conv2_out_3;
    wire [7:0] pool2_out_1, pool2_out_2, pool2_out_3;

    // FC -> comparator stream
    wire [3:0]          fc_cls;
    wire signed [31:0]  fc_logit;
    wire                fc_last;

    // -----------------------------
    // conv1 (u8 -> u8x3)
    // -----------------------------
    conv1_layer u_conv1 (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (data_valid),
        .data_in  (data_in),
        .out_valid(v1),
        .out_1    (conv1_out_1),
        .out_2    (conv1_out_2),
        .out_3    (conv1_out_3)
    );

    // -----------------------------
    // pool1 (u8x3 -> u8x3) : 24x24 -> 12x12
    // -----------------------------
    maxpool1_layer u_pool1 (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (v1),
        .in_1     (conv1_out_1),
        .in_2     (conv1_out_2),
        .in_3     (conv1_out_3),
        .out_valid(v2),
        .out_1    (pool1_out_1),
        .out_2    (pool1_out_2),
        .out_3    (pool1_out_3)
    );

    // -----------------------------
    // conv2 (u8x3 -> u8x3) : 12x12 -> 8x8
    // -----------------------------
    conv2_layer u_conv2 (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (v2),
        .in_1     (pool1_out_1),
        .in_2     (pool1_out_2),
        .in_3     (pool1_out_3),
        .out_valid(v3),
        .out_1    (conv2_out_1),
        .out_2    (conv2_out_2),
        .out_3    (conv2_out_3)
    );

    // -----------------------------
    // pool2 (u8x3 -> u8x3) : 8x8 -> 4x4
    // - 프레임당 16클럭 동안 v4=1, 각 클럭마다 3채널이 같은 (y,x)의 값
    // -----------------------------
    maxpool2_layer u_pool2 (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (v3),
        .in_1     (conv2_out_1),
        .in_2     (conv2_out_2),
        .in_3     (conv2_out_3),
        .out_valid(v4),
        .out_1    (pool2_out_1),
        .out_2    (pool2_out_2),
        .out_3    (pool2_out_3)
    );

    // -----------------------------
    // fully_connected
    // - 입력: pool2 16클럭 * 3채널 = 48개 u8
    // - 출력: 10클럭 동안 (cls, logit_s32, last) 스트림
    // -----------------------------
    fully_connected u_fc (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (v4),
        .in_1      (pool2_out_1), // ch0
        .in_2      (pool2_out_2), // ch1
        .in_3      (pool2_out_3), // ch2

        .out_valid (v5),
        .out_cls   (fc_cls),
        .out_logit (fc_logit),
        .out_last  (fc_last)
    );

    // -----------------------------
    // comparator (argmax)
    // -----------------------------
    comparator u_cmp (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (v5),
        .in_cls    (fc_cls),
        .in_logit  (fc_logit),
        .in_last   (fc_last),

        .decision  (decision),
        .out_valid (out_valid)
    );

endmodule