`timescale 1ns / 1ps

module ov7670_capture #(
    parameter integer H_ACTIVE      = 640,
    parameter integer V_ACTIVE      = 480,
    parameter integer ENABLE_THRESH = 0,    // 0: 흑백, 1: 이진화
    parameter [7:0]   THRESH        = 8'd128,
    parameter integer Y_ON_ODD_BYTE = 1     
)(
    input  wire        pclk,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  din,
    input  wire        rst_n,

    // ROI Box
    input  wire [9:0]  box_left,
    input  wire [9:0]  box_right,
    input  wire [9:0]  box_up,
    input  wire [9:0]  box_down,

    output reg  [18:0] addr,
    output reg  [7:0]  dout,
    output reg         we,
    output reg         capture_end
);

    // -------------------------------------------------------------------------
    // 1. 입력 신호 안정화
    // -------------------------------------------------------------------------
    reg        vsync_r, vsync_rr;
    reg        href_r,  href_rr;
    reg [7:0]  din_r,   din_rr;

    always @(posedge pclk) begin
        vsync_r  <= vsync;
        vsync_rr <= vsync_r;
        href_r   <= href;
        href_rr  <= href_r;
        din_r    <= din;
        din_rr   <= din_r;
    end

    wire vsync_rise = (vsync_r == 1) && (vsync_rr == 0); 
    wire href_rise  = (href_r == 1)  && (href_rr == 0);  
    
    // -------------------------------------------------------------------------
    // 2. 내부 변수 선언 (모두 맨 위로 올림)
    // -------------------------------------------------------------------------
    reg [9:0] x_cnt;
    reg [9:0] y_cnt;
    reg       byte_sel; 
    reg [7:0] y_latch; 
    reg [7:0] final_y; // ★ 에러 해결: 선언을 여기로 이동했습니다.
    
    // ROI 영역 확인
    wire in_box = (x_cnt >= box_left)  && (x_cnt < box_right) &&
                  (y_cnt >= box_up)    && (y_cnt < box_down);

    // =========================================================================
    // 메인 캡처 로직
    // =========================================================================
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            addr        <= 0;
            dout        <= 0;
            we          <= 0;
            capture_end <= 0;
            x_cnt       <= 0;
            y_cnt       <= 0;
            byte_sel    <= 0;
            y_latch     <= 0;
            final_y     <= 0;
        end else begin
            we          <= 0;
            capture_end <= 0;

            // 1. 프레임 시작 (VSYNC)
            if (vsync_rise) begin
                x_cnt <= 0;
                y_cnt <= 0;
                addr  <= 0;
                byte_sel <= 0;
            end
            // 2. 라인 시작
            else if (href_rise) begin
                x_cnt    <= 0;
                byte_sel <= 0; 
            end
            
            // 3. 데이터 유효 구간
            if (href_rr) begin
                byte_sel <= ~byte_sel; 
                
                if (byte_sel == 0) begin
                    // 첫 번째 바이트 임시 저장
                    y_latch <= din_rr;
                end 
                else begin
                    // [두 번째 바이트 구간] -> 1픽셀 완성
                    
                    // 어떤 바이트가 진짜 Y값인지 선택
                    if (Y_ON_ODD_BYTE == 1) final_y = din_rr;  
                    else                    final_y = y_latch; 
                    
                    // ★ 원하시는 대로 자르는 코드 삭제함
                    // 화면 범위 내에만 있다면 무조건 저장
                    if (x_cnt < H_ACTIVE && y_cnt < V_ACTIVE) begin
                        
                        // 이진화 or 흑백
                        if (ENABLE_THRESH && in_box)
                            dout <= (final_y >= THRESH) ? 8'hFF : 8'h00;
                        else
                            dout <= final_y;
                            
                        // 절대 주소 계산 (화면 밀림 방지)
                        addr <= (y_cnt * H_ACTIVE) + x_cnt;
                        we   <= 1;
                    end
                    
                    // 카운터 증가 (타이밍 유지를 위해 항상 증가)
                    if (x_cnt < H_ACTIVE + 50) 
                        x_cnt <= x_cnt + 1;
                end
            end 
            
            // 4. 라인 종료 처리
            if (href_r == 0 && href_rr == 1) begin
               if (y_cnt < V_ACTIVE - 1)
                   y_cnt <= y_cnt + 1;
               else begin
                   capture_end <= 1;
               end
            end
        end
    end

endmodule