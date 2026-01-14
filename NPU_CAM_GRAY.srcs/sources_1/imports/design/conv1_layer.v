module conv1_layer(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [7:0]  data_in,
    output wire        out_valid,
    output wire [7:0]  out_1,
    output wire [7:0]  out_2,
    output wire [7:0]  out_3
);
    // Line Buffer Signals
    wire lb_valid;
    wire [7:0] d0, d1, d2, d3, d4, d5, d6, d7, d8, d9;
    wire [7:0] d10,d11,d12,d13,d14,d15,d16,d17,d18,d19;
    wire [7:0] d20,d21,d22,d23,d24;

    // Line Buffer Instance
    conv1_linebuf u_linebuf (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .data_in(data_in),
        .window_valid(lb_valid),
        .data_out_0(d0), .data_out_1(d1), .data_out_2(d2), .data_out_3(d3), .data_out_4(d4),
        .data_out_5(d5), .data_out_6(d6), .data_out_7(d7), .data_out_8(d8), .data_out_9(d9),
        .data_out_10(d10),.data_out_11(d11),.data_out_12(d12),.data_out_13(d13),.data_out_14(d14),
        .data_out_15(d15),.data_out_16(d16),.data_out_17(d17),.data_out_18(d18),.data_out_19(d19),
        .data_out_20(d20),.data_out_21(d21),.data_out_22(d22),.data_out_23(d23),.data_out_24(d24)
    );

    wire v1, v2, v3;

    // ★ 수정 포인트: 파라미터에 "절대 경로"를 넣어줍니다. ★
    
    // Filter 1
    conv1_calc #(
        .WEIGHT_FILE("conv1_weight_1.txt")
    ) u_calc_1 (
        .clk(clk), .rst_n(rst_n), .in_valid(lb_valid),
        .data_in_0(d0), .data_in_1(d1), .data_in_2(d2), .data_in_3(d3), .data_in_4(d4),
        .data_in_5(d5), .data_in_6(d6), .data_in_7(d7), .data_in_8(d8), .data_in_9(d9),
        .data_in_10(d10),.data_in_11(d11),.data_in_12(d12),.data_in_13(d13),.data_in_14(d14),
        .data_in_15(d15),.data_in_16(d16),.data_in_17(d17),.data_in_18(d18),.data_in_19(d19),
        .data_in_20(d20),.data_in_21(d21),.data_in_22(d22),.data_in_23(d23),.data_in_24(d24),
        .out_valid(v1), .data_out(out_1)
    );

    // Filter 2
    conv1_calc #(
        .WEIGHT_FILE("conv1_weight_2.txt")
    ) u_calc_2 (
        .clk(clk), .rst_n(rst_n), .in_valid(lb_valid),
        .data_in_0(d0), .data_in_1(d1), .data_in_2(d2), .data_in_3(d3), .data_in_4(d4),
        .data_in_5(d5), .data_in_6(d6), .data_in_7(d7), .data_in_8(d8), .data_in_9(d9),
        .data_in_10(d10),.data_in_11(d11),.data_in_12(d12),.data_in_13(d13),.data_in_14(d14),
        .data_in_15(d15),.data_in_16(d16),.data_in_17(d17),.data_in_18(d18),.data_in_19(d19),
        .data_in_20(d20),.data_in_21(d21),.data_in_22(d22),.data_in_23(d23),.data_in_24(d24),
        .out_valid(v2), .data_out(out_2)
    );

    // Filter 3
    conv1_calc #(
        .WEIGHT_FILE("conv1_weight_3.txt")
    ) u_calc_3 (
        .clk(clk), .rst_n(rst_n), .in_valid(lb_valid),
        .data_in_0(d0), .data_in_1(d1), .data_in_2(d2), .data_in_3(d3), .data_in_4(d4),
        .data_in_5(d5), .data_in_6(d6), .data_in_7(d7), .data_in_8(d8), .data_in_9(d9),
        .data_in_10(d10),.data_in_11(d11),.data_in_12(d12),.data_in_13(d13),.data_in_14(d14),
        .data_in_15(d15),.data_in_16(d16),.data_in_17(d17),.data_in_18(d18),.data_in_19(d19),
        .data_in_20(d20),.data_in_21(d21),.data_in_22(d22),.data_in_23(d23),.data_in_24(d24),
        .out_valid(v3), .data_out(out_3)
    );

    assign out_valid = v1;
endmodule