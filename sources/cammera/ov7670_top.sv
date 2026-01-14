`timescale 1ns/1ps

module ov7670_top_hdmi #(
    parameter H_ACTIVE = 640,
    parameter V_ACTIVE = 480
)(
    input  wire        clk,          // board clock
    input  wire        btn,

    // OV7670 Signals (XDC 핀 배치와 호환)
    input  wire        OV7670_PCLK,  // MRCC 핀(Y6) 사용 -> 노이즈 제거됨
    input  wire        OV7670_VSYNC,
    input  wire        OV7670_HREF,
    input  wire [7:0]  OV7670_D,
    output wire        OV7670_XCLK,
    output wire        OV7670_SIOC,
    inout  wire        OV7670_SIOD,
    output wire        OV7670_PWDN,
    output wire        OV7670_RESET_N,

    // HDMI Signals
    output wire        hdmi_tx_clk_p,
    output wire        hdmi_tx_clk_n,
    output wire [2:0]  hdmi_tx_data_p,
    output wire [2:0]  hdmi_tx_data_n,

    output wire [3:0]  led,

    // ---------------------------------------------------------
    // [필수 추가] ZYNQ PS 연결 포트 (SD카드 부팅용)
    // ---------------------------------------------------------
    inout  wire [14:0] DDR_addr,
    inout  wire [2:0]  DDR_ba,
    inout  wire        DDR_cas_n,
    inout  wire        DDR_ck_n,
    inout  wire        DDR_ck_p,
    inout  wire        DDR_cke,
    inout  wire        DDR_cs_n,
    inout  wire [3:0]  DDR_dm,
    inout  wire [31:0] DDR_dq,
    inout  wire [3:0]  DDR_dqs_n,
    inout  wire [3:0]  DDR_dqs_p,
    inout  wire        DDR_odt,
    inout  wire        DDR_ras_n,
    inout  wire        DDR_reset_n,
    inout  wire        DDR_we_n,
    inout  wire        FIXED_IO_ddr_vrn,
    inout  wire        FIXED_IO_ddr_vrp,
    inout  wire [53:0] FIXED_IO_mio,
    inout  wire        FIXED_IO_ps_clk,
    inout  wire        FIXED_IO_ps_porb,
    inout  wire        FIXED_IO_ps_srstb
);

    localparam integer FB_SIZE = H_ACTIVE*V_ACTIVE;

    wire rst_n = ~btn;
    wire [9:0] box_left, box_right, box_up, box_down;
    
    // Clock Wizard
    wire locked;
    wire clk_cam;
    wire pclk_vid;
    wire clk_serial;

    clk_wiz_0 u_clk (
        .clk_in1 (clk),
        .reset   (~rst_n),
        .locked  (locked),
        .clk_out1(clk_cam),
        .clk_out2(pclk_vid),
        .clk_out3(clk_serial)
    );

    assign OV7670_XCLK    = clk_cam;
    assign OV7670_PWDN    = 1'b0;
    assign OV7670_RESET_N = 1'b1;

    // Camera Config
    wire config_done;
    camera_configure u_cfg (
        .clk   (pclk_vid),
        .rst_n (rst_n),
        .sioc  (OV7670_SIOC),
        .siod  (OV7670_SIOD),
        .done  (config_done)
    );

    // Capture Module
    wire [18:0] cap_addr;
    wire [7:0]  cap_dout;
    wire        cap_we;
    wire        cap_end;

    ov7670_capture #(
        .H_ACTIVE(640),
        .V_ACTIVE(480),
        .ENABLE_THRESH(0),
        .THRESH(8'd128),
        .Y_ON_ODD_BYTE(1)
    ) u_cap (
        .pclk        (OV7670_PCLK), // Y6 핀(MRCC) 사용
        .vsync       (OV7670_VSYNC),
        .href        (OV7670_HREF),
        .din         (OV7670_D),
        .rst_n       (rst_n),
        .box_left    (box_left),
        .box_right   (box_right),
        .box_up      (box_up),
        .box_down    (box_down),
        .addr        (cap_addr),
        .dout        (cap_dout),
        .we          (cap_we),
        .capture_end (cap_end)
    );

    // Framebuffer
    (* ram_style="block" *) reg [7:0] fb [0:FB_SIZE-1];
    reg [7:0] fb_q;

    always @(posedge OV7670_PCLK) begin
        if (!rst_n) begin
            // no clear
        end else if (cap_we) begin
            if (cap_addr < FB_SIZE)
                fb[cap_addr] <= cap_dout;
        end
    end

    // VGA Timing
    wire [9:0] x;
    wire [9:0] y;
    wire       hsync, vsync, de;

    vga_timing_640x480 u_timing (
        .pclk  (pclk_vid),
        .rst_n (rst_n),
        .x     (x),
        .y     (y),
        .hsync (hsync),
        .vsync (vsync),
        .de    (de)
    );

    wire [18:0] rd_addr = (y * H_ACTIVE) + x;

    always @(posedge pclk_vid) begin
        if (!rst_n) fb_q <= 8'h00;
        else if (de) fb_q <= fb[rd_addr];
        else fb_q <= 8'h00;
    end
    
    // Overlay Logic
    wire [11:0] rgb_overlay;
    wire [3:0] r4 = rgb_overlay[11:8];
    wire [3:0] g4 = rgb_overlay[7:4];
    wire [3:0] b4 = rgb_overlay[3:0];
    wire [23:0] video_with_box = {r4, r4, g4, g4, b4, b4};

    // ---------------------------------------------------------
    // [색상 설정] 숫자 색상: 강렬한 빨간색 (Red)
    // ---------------------------------------------------------
    // R=FF, G=00, B=00 -> 24'hFF0000
    // (참고: 만약 화면에 파란색으로 나오면 BGR 순서인 것이니 나중에 수정 가능)
    wire [23:0] color_score = 24'hFF0000; 
    
    wire score_on;

    wire [23:0] vid_pData24 = (score_on) ? color_score : video_with_box;

    overlay_28x28 #(
      .THICK(2),
      .BORDER_RGB(12'hF00)
    ) u_box (
      .x(x),
      .y(y),
      .de(de),
      .pix_u8(fb_q),
      .box_left(box_left),
      .box_right(box_right),
      .box_up(box_up),
      .box_down(box_down),
      .rgb444_out(rgb_overlay)
    );
    
    simple_score_overlay u_score (
        .clk     (pclk_vid),
        .rst_n   (rst_n),
        .x       (x),
        .y       (y),
        .number  (result_latch),
        .draw_on (score_on)
    );
    
    // HDMI Output
    rgb2dvi_0 u_hdmi (
        .TMDS_Clk_p  (hdmi_tx_clk_p),
        .TMDS_Clk_n  (hdmi_tx_clk_n),
        .TMDS_Data_p (hdmi_tx_data_p),
        .TMDS_Data_n (hdmi_tx_data_n),
        .aRst        (~rst_n),
        .vid_pData   (vid_pData24),
        .vid_pVDE    (de),
        .vid_pHSync  (hsync),
        .vid_pVSync  (vsync),
        .PixelClk    (pclk_vid),
        .SerialClk   (clk_serial)
    );
    
    // CNN Processing
    (* ram_style="block" *) reg [7:0] roi_mem [0:28*28-1];
    wire [9:0] roi_addr;
    wire [7:0] roi_dout;
    wire       roi_we;
    wire       roi_done;
    
    always @(posedge pclk_vid) begin
      if (roi_we) roi_mem[roi_addr] <= roi_dout;
    end

    downsample_28x28 #(
      .H_ACTIVE(640), .V_ACTIVE(480),
      .ROI_W(28), .ROI_H(28), .REC_W(8), .REC_H(8)
    ) u_roi (
      .pclk(pclk_vid), .rst_n(rst_n),
      .x(x), .y(y), .de(de),
      .pix_u8(fb_q),
      .roi_addr(roi_addr), .roi_dout(roi_dout),
      .roi_we(roi_we), .roi_frame_done(roi_done),
      .box_left(box_left), .box_right(box_right),
      .box_up(box_up), .box_down(box_down)
    );
    
    reg [9:0]  cnn_rd_addr;
    reg        cnn_running;
    
    always @(posedge pclk_vid) begin
        if (!rst_n) begin
            cnn_rd_addr <= 10'd0;
            cnn_running <= 1'b0;
        end else begin
            if (roi_done) begin
                cnn_running <= 1'b1;
                cnn_rd_addr <= 10'd0;
            end else if (cnn_running) begin
                if (cnn_rd_addr == 10'd783) cnn_running <= 1'b0;
                else cnn_rd_addr <= cnn_rd_addr + 10'd1;
            end
        end
    end

    wire [7:0] cnn_in_data = roi_mem[cnn_rd_addr];
    wire       cnn_in_valid = cnn_running;

    wire [3:0] cnn_decision;
    wire       cnn_out_valid;
    reg  [3:0] result_latch;

    cnn_core_top u_cnn_core (
        .clk        (pclk_vid),
        .rst_n      (rst_n),
        .data_in    (cnn_in_data),
        .data_valid (cnn_in_valid),
        .decision   (cnn_decision),
        .out_valid  (cnn_out_valid)
    );

    always @(posedge pclk_vid) begin
        if (!rst_n) result_latch <= 4'd0;
        else if (cnn_out_valid) result_latch <= cnn_decision;
    end

    assign led = result_latch;
    
    // ---------------------------------------------------------
    // [필수 추가] ZYNQ 프로세서 인스턴스 (SD부팅용)
    // ---------------------------------------------------------
    design_1_wrapper u_ps_inst (
        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb)
    );

endmodule