module conv2_layer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [7:0]  in_1,
    input  wire [7:0]  in_2,
    input  wire [7:0]  in_3,

    output wire        out_valid,
    output wire [7:0]  out_1,
    output wire [7:0]  out_2,
    output wire [7:0]  out_3
);

    // --- Internal Wires (Window 5x5 for 3 channels) ---
    wire [7:0] w1_0, w1_1, w1_2, w1_3, w1_4, w1_5, w1_6, w1_7, w1_8, w1_9;
    wire [7:0] w1_10,w1_11,w1_12,w1_13,w1_14,w1_15,w1_16,w1_17,w1_18,w1_19;
    wire [7:0] w1_20,w1_21,w1_22,w1_23,w1_24;

    wire [7:0] w2_0, w2_1, w2_2, w2_3, w2_4, w2_5, w2_6, w2_7, w2_8, w2_9;
    wire [7:0] w2_10,w2_11,w2_12,w2_13,w2_14,w2_15,w2_16,w2_17,w2_18,w2_19;
    wire [7:0] w2_20,w2_21,w2_22,w2_23,w2_24;

    wire [7:0] w3_0, w3_1, w3_2, w3_3, w3_4, w3_5, w3_6, w3_7, w3_8, w3_9;
    wire [7:0] w3_10,w3_11,w3_12,w3_13,w3_14,w3_15,w3_16,w3_17,w3_18,w3_19;
    wire [7:0] w3_20,w3_21,w3_22,w3_23,w3_24;

    wire lb_valid, valid_dummy_2, valid_dummy_3;
    wire valid_out_1, valid_out_2, valid_out_3;

    // --- Line Buffers ---
    conv2_linebuf u_linebuf_1 (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .data_in(in_1),
        .window_valid(lb_valid),
        .data_out_0(w1_0), .data_out_1(w1_1), .data_out_2(w1_2), .data_out_3(w1_3), .data_out_4(w1_4),
        .data_out_5(w1_5), .data_out_6(w1_6), .data_out_7(w1_7), .data_out_8(w1_8), .data_out_9(w1_9),
        .data_out_10(w1_10),.data_out_11(w1_11),.data_out_12(w1_12),.data_out_13(w1_13),.data_out_14(w1_14),
        .data_out_15(w1_15),.data_out_16(w1_16),.data_out_17(w1_17),.data_out_18(w1_18),.data_out_19(w1_19),
        .data_out_20(w1_20),.data_out_21(w1_21),.data_out_22(w1_22),.data_out_23(w1_23),.data_out_24(w1_24)
    );

    conv2_linebuf u_linebuf_2 (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .data_in(in_2),
        .window_valid(valid_dummy_2),
        .data_out_0(w2_0), .data_out_1(w2_1), .data_out_2(w2_2), .data_out_3(w2_3), .data_out_4(w2_4),
        .data_out_5(w2_5), .data_out_6(w2_6), .data_out_7(w2_7), .data_out_8(w2_8), .data_out_9(w2_9),
        .data_out_10(w2_10),.data_out_11(w2_11),.data_out_12(w2_12),.data_out_13(w2_13),.data_out_14(w2_14),
        .data_out_15(w2_15),.data_out_16(w2_16),.data_out_17(w2_17),.data_out_18(w2_18),.data_out_19(w2_19),
        .data_out_20(w2_20),.data_out_21(w2_21),.data_out_22(w2_22),.data_out_23(w2_23),.data_out_24(w2_24)
    );

    conv2_linebuf u_linebuf_3 (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .data_in(in_3),
        .window_valid(valid_dummy_3),
        .data_out_0(w3_0), .data_out_1(w3_1), .data_out_2(w3_2), .data_out_3(w3_3), .data_out_4(w3_4),
        .data_out_5(w3_5), .data_out_6(w3_6), .data_out_7(w3_7), .data_out_8(w3_8), .data_out_9(w3_9),
        .data_out_10(w3_10),.data_out_11(w3_11),.data_out_12(w3_12),.data_out_13(w3_13),.data_out_14(w3_14),
        .data_out_15(w3_15),.data_out_16(w3_16),.data_out_17(w3_17),.data_out_18(w3_18),.data_out_19(w3_19),
        .data_out_20(w3_20),.data_out_21(w3_21),.data_out_22(w3_22),.data_out_23(w3_23),.data_out_24(w3_24)
    );

    // --- Calculations ---
    
    // ¡Ú Filter 1 (conv2_weight_1.txt Absolute Path)
    conv2_calc #(
        .WEIGHT_FILE("conv2_weight_1.txt")
    ) u_calc_1 (
        .clk(clk), .rst_n(rst_n), .in_valid(lb_valid),
        .ch1_0(w1_0), .ch1_1(w1_1), .ch1_2(w1_2), .ch1_3(w1_3), .ch1_4(w1_4),
        .ch1_5(w1_5), .ch1_6(w1_6), .ch1_7(w1_7), .ch1_8(w1_8), .ch1_9(w1_9),
        .ch1_10(w1_10),.ch1_11(w1_11),.ch1_12(w1_12),.ch1_13(w1_13),.ch1_14(w1_14),
        .ch1_15(w1_15),.ch1_16(w1_16),.ch1_17(w1_17),.ch1_18(w1_18),.ch1_19(w1_19),
        .ch1_20(w1_20),.ch1_21(w1_21),.ch1_22(w1_22),.ch1_23(w1_23),.ch1_24(w1_24),
        .ch2_0(w2_0), .ch2_1(w2_1), .ch2_2(w2_2), .ch2_3(w2_3), .ch2_4(w2_4),
        .ch2_5(w2_5), .ch2_6(w2_6), .ch2_7(w2_7), .ch2_8(w2_8), .ch2_9(w2_9),
        .ch2_10(w2_10),.ch2_11(w2_11),.ch2_12(w2_12),.ch2_13(w2_13),.ch2_14(w2_14),
        .ch2_15(w2_15),.ch2_16(w2_16),.ch2_17(w2_17),.ch2_18(w2_18),.ch2_19(w2_19),
        .ch2_20(w2_20),.ch2_21(w2_21),.ch2_22(w2_22),.ch2_23(w2_23),.ch2_24(w2_24),
        .ch3_0(w3_0), .ch3_1(w3_1), .ch3_2(w3_2), .ch3_3(w3_3), .ch3_4(w3_4),
        .ch3_5(w3_5), .ch3_6(w3_6), .ch3_7(w3_7), .ch3_8(w3_8), .ch3_9(w3_9),
        .ch3_10(w3_10),.ch3_11(w3_11),.ch3_12(w3_12),.ch3_13(w3_13),.ch3_14(w3_14),
        .ch3_15(w3_15),.ch3_16(w3_16),.ch3_17(w3_17),.ch3_18(w3_18),.ch3_19(w3_19),
        .ch3_20(w3_20),.ch3_21(w3_21),.ch3_22(w3_22),.ch3_23(w3_23),.ch3_24(w3_24),
        .out_valid(valid_out_1), .data_out(out_1)
    );

    // ¡Ú Filter 2 (conv2_weight_2.txt Absolute Path)
    conv2_calc #(
        .WEIGHT_FILE("conv2_weight_2.txt")
    ) u_calc_2 (
        .clk(clk), .rst_n(rst_n), .in_valid(lb_valid),
        .ch1_0(w1_0), .ch1_1(w1_1), .ch1_2(w1_2), .ch1_3(w1_3), .ch1_4(w1_4),
        .ch1_5(w1_5), .ch1_6(w1_6), .ch1_7(w1_7), .ch1_8(w1_8), .ch1_9(w1_9),
        .ch1_10(w1_10),.ch1_11(w1_11),.ch1_12(w1_12),.ch1_13(w1_13),.ch1_14(w1_14),
        .ch1_15(w1_15),.ch1_16(w1_16),.ch1_17(w1_17),.ch1_18(w1_18),.ch1_19(w1_19),
        .ch1_20(w1_20),.ch1_21(w1_21),.ch1_22(w1_22),.ch1_23(w1_23),.ch1_24(w1_24),
        .ch2_0(w2_0), .ch2_1(w2_1), .ch2_2(w2_2), .ch2_3(w2_3), .ch2_4(w2_4),
        .ch2_5(w2_5), .ch2_6(w2_6), .ch2_7(w2_7), .ch2_8(w2_8), .ch2_9(w2_9),
        .ch2_10(w2_10),.ch2_11(w2_11),.ch2_12(w2_12),.ch2_13(w2_13),.ch2_14(w2_14),
        .ch2_15(w2_15),.ch2_16(w2_16),.ch2_17(w2_17),.ch2_18(w2_18),.ch2_19(w2_19),
        .ch2_20(w2_20),.ch2_21(w2_21),.ch2_22(w2_22),.ch2_23(w2_23),.ch2_24(w2_24),
        .ch3_0(w3_0), .ch3_1(w3_1), .ch3_2(w3_2), .ch3_3(w3_3), .ch3_4(w3_4),
        .ch3_5(w3_5), .ch3_6(w3_6), .ch3_7(w3_7), .ch3_8(w3_8), .ch3_9(w3_9),
        .ch3_10(w3_10),.ch3_11(w3_11),.ch3_12(w3_12),.ch3_13(w3_13),.ch3_14(w3_14),
        .ch3_15(w3_15),.ch3_16(w3_16),.ch3_17(w3_17),.ch3_18(w3_18),.ch3_19(w3_19),
        .ch3_20(w3_20),.ch3_21(w3_21),.ch3_22(w3_22),.ch3_23(w3_23),.ch3_24(w3_24),
        .out_valid(valid_out_2), .data_out(out_2)
    );

    // ¡Ú Filter 3 (conv2_weight_3.txt Absolute Path)
    conv2_calc #(
        .WEIGHT_FILE("conv2_weight_3.txt")
    ) u_calc_3 (
        .clk(clk), .rst_n(rst_n), .in_valid(lb_valid),
        .ch1_0(w1_0), .ch1_1(w1_1), .ch1_2(w1_2), .ch1_3(w1_3), .ch1_4(w1_4),
        .ch1_5(w1_5), .ch1_6(w1_6), .ch1_7(w1_7), .ch1_8(w1_8), .ch1_9(w1_9),
        .ch1_10(w1_10),.ch1_11(w1_11),.ch1_12(w1_12),.ch1_13(w1_13),.ch1_14(w1_14),
        .ch1_15(w1_15),.ch1_16(w1_16),.ch1_17(w1_17),.ch1_18(w1_18),.ch1_19(w1_19),
        .ch1_20(w1_20),.ch1_21(w1_21),.ch1_22(w1_22),.ch1_23(w1_23),.ch1_24(w1_24),
        .ch2_0(w2_0), .ch2_1(w2_1), .ch2_2(w2_2), .ch2_3(w2_3), .ch2_4(w2_4),
        .ch2_5(w2_5), .ch2_6(w2_6), .ch2_7(w2_7), .ch2_8(w2_8), .ch2_9(w2_9),
        .ch2_10(w2_10),.ch2_11(w2_11),.ch2_12(w2_12),.ch2_13(w2_13),.ch2_14(w2_14),
        .ch2_15(w2_15),.ch2_16(w2_16),.ch2_17(w2_17),.ch2_18(w2_18),.ch2_19(w2_19),
        .ch2_20(w2_20),.ch2_21(w2_21),.ch2_22(w2_22),.ch2_23(w2_23),.ch2_24(w2_24),
        .ch3_0(w3_0), .ch3_1(w3_1), .ch3_2(w3_2), .ch3_3(w3_3), .ch3_4(w3_4),
        .ch3_5(w3_5), .ch3_6(w3_6), .ch3_7(w3_7), .ch3_8(w3_8), .ch3_9(w3_9),
        .ch3_10(w3_10),.ch3_11(w3_11),.ch3_12(w3_12),.ch3_13(w3_13),.ch3_14(w3_14),
        .ch3_15(w3_15),.ch3_16(w3_16),.ch3_17(w3_17),.ch3_18(w3_18),.ch3_19(w3_19),
        .ch3_20(w3_20),.ch3_21(w3_21),.ch3_22(w3_22),.ch3_23(w3_23),.ch3_24(w3_24),
        .out_valid(valid_out_3), .data_out(out_3)
    );

    // Final Valid Assignment
    assign out_valid = valid_out_1;

endmodule