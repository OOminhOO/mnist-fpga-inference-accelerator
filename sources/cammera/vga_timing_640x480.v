// -----------------------------
// 640x480 timing generator (Corrected based on measurement: 24px Left Shift)
// -----------------------------
module vga_timing_640x480(
    input  wire       pclk,
    input  wire       rst_n,
    output reg [9:0]  x,
    output reg [9:0]  y,
    output reg        hsync,
    output reg        vsync,
    output wire       de
);
    localparam H_ACTIVE = 640;
    
    // [정밀 계산 결과 적용]
    // 사용자 측정: 0.1cm(잔상) + 1.5cm(검은줄) ? 21 픽셀 오차
    // 보정 값: 24 픽셀 (21픽셀을 덮고 3픽셀 여유 확보)
    
    localparam H_FP     = 16 + 24; // 40 (Front Porch 증가)
    localparam H_SYNC   = 96;
    localparam H_BP     = 48 - 24; // 24 (Back Porch 감소 -> 화면 왼쪽 이동)
    
    // H_TOTAL = 640 + 40 + 96 + 24 = 800 (타이밍 규격 준수함)
    localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP; 

    localparam V_ACTIVE = 480;
    localparam V_FP     = 10;
    localparam V_SYNC   = 2;
    localparam V_BP     = 33;
    localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP; 

    assign de = (x < H_ACTIVE) && (y < V_ACTIVE);

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 10'd0;
            y <= 10'd0;
        end else begin
            if (x == H_TOTAL-1) begin
                x <= 10'd0;
                if (y == V_TOTAL-1) y <= 10'd0;
                else                 y <= y + 10'd1;
            end else begin
                x <= x + 10'd1;
            end
        end
    end

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            hsync <= ~((x >= H_ACTIVE + H_FP) && (x < H_ACTIVE + H_FP + H_SYNC));
            vsync <= ~((y >= V_ACTIVE + V_FP) && (y < V_ACTIVE + V_FP + V_SYNC));
        end
    end
      
endmodule