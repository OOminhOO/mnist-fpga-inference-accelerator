`timescale 1ns/1ps

module simple_score_overlay #(
    parameter H_VISIBLE = 640,
    parameter V_VISIBLE = 480
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire [3:0]  number, // 0~9 (CNN 결과)
    output reg         draw_on // 1이면 글자 픽셀임
);

    // ----------------------------------------------------
    // 설정: 위치 및 크기
    // ----------------------------------------------------
    localparam START_X = 32;  // 화면 좌측에서 떨어진 거리
    localparam START_Y = 32;  // 화면 상단에서 떨어진 거리
    localparam SCALE   = 4;   // 폰트 크기 확대 배율 (기본 8x16 -> 32x64)
    
    // 기본 폰트 크기 (8x16)
    wire [3:0] font_col = (x - START_X) / SCALE; // 0..7
    wire [3:0] font_row = (y - START_Y) / SCALE; // 0..15

    // 현재 좌표가 폰트 박스 안에 있는지 확인
    wire in_rect = (x >= START_X) && (x < START_X + 8*SCALE) &&
                   (y >= START_Y) && (y < START_Y + 16*SCALE);

    // ----------------------------------------------------
    // 폰트 데이터 (0~9) - 8x16 비트맵
    // ----------------------------------------------------
    reg [7:0] font_data;
    
    always @(*) begin
        case ({number, font_row}) // {숫자, 행}
            // Number 0
            {4'd0, 4'd0 }: font_data = 8'h00; {4'd0, 4'd1 }: font_data = 8'h3C; {4'd0, 4'd2 }: font_data = 8'h42; {4'd0, 4'd3 }: font_data = 8'h42;
            {4'd0, 4'd4 }: font_data = 8'h42; {4'd0, 4'd5 }: font_data = 8'h42; {4'd0, 4'd6 }: font_data = 8'h42; {4'd0, 4'd7 }: font_data = 8'h42;
            {4'd0, 4'd8 }: font_data = 8'h42; {4'd0, 4'd9 }: font_data = 8'h42; {4'd0, 4'd10}: font_data = 8'h42; {4'd0, 4'd11}: font_data = 8'h42;
            {4'd0, 4'd12}: font_data = 8'h42; {4'd0, 4'd13}: font_data = 8'h42; {4'd0, 4'd14}: font_data = 8'h3C; {4'd0, 4'd15}: font_data = 8'h00;
            
            // Number 1
            {4'd1, 4'd0 }: font_data = 8'h00; {4'd1, 4'd1 }: font_data = 8'h08; {4'd1, 4'd2 }: font_data = 8'h18; {4'd1, 4'd3 }: font_data = 8'h28;
            {4'd1, 4'd4 }: font_data = 8'h08; {4'd1, 4'd5 }: font_data = 8'h08; {4'd1, 4'd6 }: font_data = 8'h08; {4'd1, 4'd7 }: font_data = 8'h08;
            {4'd1, 4'd8 }: font_data = 8'h08; {4'd1, 4'd9 }: font_data = 8'h08; {4'd1, 4'd10}: font_data = 8'h08; {4'd1, 4'd11}: font_data = 8'h08;
            {4'd1, 4'd12}: font_data = 8'h08; {4'd1, 4'd13}: font_data = 8'h08; {4'd1, 4'd14}: font_data = 8'h3E; {4'd0, 4'd15}: font_data = 8'h00;

            // Number 2
            {4'd2, 4'd0 }: font_data = 8'h00; {4'd2, 4'd1 }: font_data = 8'h3C; {4'd2, 4'd2 }: font_data = 8'h42; {4'd2, 4'd3 }: font_data = 8'h42;
            {4'd2, 4'd4 }: font_data = 8'h02; {4'd2, 4'd5 }: font_data = 8'h02; {4'd2, 4'd6 }: font_data = 8'h04; {4'd2, 4'd7 }: font_data = 8'h08;
            {4'd2, 4'd8 }: font_data = 8'h10; {4'd2, 4'd9 }: font_data = 8'h20; {4'd2, 4'd10}: font_data = 8'h40; {4'd2, 4'd11}: font_data = 8'h80;
            {4'd2, 4'd12}: font_data = 8'h80; {4'd2, 4'd13}: font_data = 8'h80; {4'd2, 4'd14}: font_data = 8'hFE; {4'd2, 4'd15}: font_data = 8'h00;

            // Number 3
            {4'd3, 4'd0 }: font_data = 8'h00; {4'd3, 4'd1 }: font_data = 8'h3C; {4'd3, 4'd2 }: font_data = 8'h42; {4'd3, 4'd3 }: font_data = 8'h42;
            {4'd3, 4'd4 }: font_data = 8'h02; {4'd3, 4'd5 }: font_data = 8'h02; {4'd3, 4'd6 }: font_data = 8'h1C; {4'd3, 4'd7 }: font_data = 8'h02;
            {4'd3, 4'd8 }: font_data = 8'h02; {4'd3, 4'd9 }: font_data = 8'h02; {4'd3, 4'd10}: font_data = 8'h02; {4'd3, 4'd11}: font_data = 8'h02;
            {4'd3, 4'd12}: font_data = 8'h42; {4'd3, 4'd13}: font_data = 8'h42; {4'd3, 4'd14}: font_data = 8'h3C; {4'd3, 4'd15}: font_data = 8'h00;

            // Number 4
            {4'd4, 4'd0 }: font_data = 8'h00; {4'd4, 4'd1 }: font_data = 8'h04; {4'd4, 4'd2 }: font_data = 8'h0C; {4'd4, 4'd3 }: font_data = 8'h14;
            {4'd4, 4'd4 }: font_data = 8'h24; {4'd4, 4'd5 }: font_data = 8'h44; {4'd4, 4'd6 }: font_data = 8'h44; {4'd4, 4'd7 }: font_data = 8'h84;
            {4'd4, 4'd8 }: font_data = 8'hFE; {4'd4, 4'd9 }: font_data = 8'h04; {4'd4, 4'd10}: font_data = 8'h04; {4'd4, 4'd11}: font_data = 8'h04;
            {4'd4, 4'd12}: font_data = 8'h04; {4'd4, 4'd13}: font_data = 8'h04; {4'd4, 4'd14}: font_data = 8'h04; {4'd4, 4'd15}: font_data = 8'h00;

            // Number 5
            {4'd5, 4'd0 }: font_data = 8'h00; {4'd5, 4'd1 }: font_data = 8'hFE; {4'd5, 4'd2 }: font_data = 8'h80; {4'd5, 4'd3 }: font_data = 8'h80;
            {4'd5, 4'd4 }: font_data = 8'h80; {4'd5, 4'd5 }: font_data = 8'hFC; {4'd5, 4'd6 }: font_data = 8'h02; {4'd5, 4'd7 }: font_data = 8'h02;
            {4'd5, 4'd8 }: font_data = 8'h02; {4'd5, 4'd9 }: font_data = 8'h02; {4'd5, 4'd10}: font_data = 8'h02; {4'd5, 4'd11}: font_data = 8'h02;
            {4'd5, 4'd12}: font_data = 8'h82; {4'd5, 4'd13}: font_data = 8'h42; {4'd5, 4'd14}: font_data = 8'h3C; {4'd5, 4'd15}: font_data = 8'h00;

            // Number 6
            {4'd6, 4'd0 }: font_data = 8'h00; {4'd6, 4'd1 }: font_data = 8'h3C; {4'd6, 4'd2 }: font_data = 8'h42; {4'd6, 4'd3 }: font_data = 8'h80;
            {4'd6, 4'd4 }: font_data = 8'h80; {4'd6, 4'd5 }: font_data = 8'h80; {4'd6, 4'd6 }: font_data = 8'hBC; {4'd6, 4'd7 }: font_data = 8'hC2;
            {4'd6, 4'd8 }: font_data = 8'h82; {4'd6, 4'd9 }: font_data = 8'h82; {4'd6, 4'd10}: font_data = 8'h82; {4'd6, 4'd11}: font_data = 8'h82;
            {4'd6, 4'd12}: font_data = 8'h42; {4'd6, 4'd13}: font_data = 8'h42; {4'd6, 4'd14}: font_data = 8'h3C; {4'd6, 4'd15}: font_data = 8'h00;

            // Number 7
            {4'd7, 4'd0 }: font_data = 8'h00; {4'd7, 4'd1 }: font_data = 8'hFE; {4'd7, 4'd2 }: font_data = 8'h02; {4'd7, 4'd3 }: font_data = 8'h04;
            {4'd7, 4'd4 }: font_data = 8'h04; {4'd7, 4'd5 }: font_data = 8'h08; {4'd7, 4'd6 }: font_data = 8'h08; {4'd7, 4'd7 }: font_data = 8'h10;
            {4'd7, 4'd8 }: font_data = 8'h10; {4'd7, 4'd9 }: font_data = 8'h20; {4'd7, 4'd10}: font_data = 8'h20; {4'd7, 4'd11}: font_data = 8'h20;
            {4'd7, 4'd12}: font_data = 8'h20; {4'd7, 4'd13}: font_data = 8'h20; {4'd7, 4'd14}: font_data = 8'h20; {4'd7, 4'd15}: font_data = 8'h00;

            // Number 8
            {4'd8, 4'd0 }: font_data = 8'h00; {4'd8, 4'd1 }: font_data = 8'h3C; {4'd8, 4'd2 }: font_data = 8'h42; {4'd8, 4'd3 }: font_data = 8'h42;
            {4'd8, 4'd4 }: font_data = 8'h42; {4'd8, 4'd5 }: font_data = 8'h42; {4'd8, 4'd6 }: font_data = 8'h3C; {4'd8, 4'd7 }: font_data = 8'h42;
            {4'd8, 4'd8 }: font_data = 8'h42; {4'd8, 4'd9 }: font_data = 8'h42; {4'd8, 4'd10}: font_data = 8'h42; {4'd8, 4'd11}: font_data = 8'h42;
            {4'd8, 4'd12}: font_data = 8'h42; {4'd8, 4'd13}: font_data = 8'h42; {4'd8, 4'd14}: font_data = 8'h3C; {4'd8, 4'd15}: font_data = 8'h00;

            // Number 9
            {4'd9, 4'd0 }: font_data = 8'h00; {4'd9, 4'd1 }: font_data = 8'h3C; {4'd9, 4'd2 }: font_data = 8'h42; {4'd9, 4'd3 }: font_data = 8'h42;
            {4'd9, 4'd4 }: font_data = 8'h42; {4'd9, 4'd5 }: font_data = 8'h42; {4'd9, 4'd6 }: font_data = 8'h46; {4'd9, 4'd7 }: font_data = 8'h3A;
            {4'd9, 4'd8 }: font_data = 8'h02; {4'd9, 4'd9 }: font_data = 8'h02; {4'd9, 4'd10}: font_data = 8'h02; {4'd9, 4'd11}: font_data = 8'h02;
            {4'd9, 4'd12}: font_data = 8'h42; {4'd9, 4'd13}: font_data = 8'h42; {4'd9, 4'd14}: font_data = 8'h3C; {4'd9, 4'd15}: font_data = 8'h00;
            
            default:      font_data = 8'h00;
        endcase
    end

    always @(posedge clk) begin
        if (in_rect) begin
            // 8비트 데이터 중 현재 x에 해당하는 비트가 1인지 확인 (MSB first)
            draw_on <= font_data[7 - font_col]; 
        end else begin
            draw_on <= 1'b0;
        end
    end

endmodule