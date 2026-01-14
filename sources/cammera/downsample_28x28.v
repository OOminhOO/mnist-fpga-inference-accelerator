
`timescale 1ns/1ps
`default_nettype none
// -----------------------------------------------------------------------------
// roi28x28_downsample_writer
// - Keeps full 640x480 display path untouched.
// - Builds CNN input by taking a CENTER ROI of size (ROI_W*REC_W) x (ROI_H*REC_H)
//   from the active video (H_ACTIVE x V_ACTIVE), accumulating each REC_W x REC_H
//   block and writing its average into a 28x28 (ROI_W x ROI_H) buffer.
// - Also provides box coordinates so you can draw a rectangle overlay that matches
//   exactly what the CNN "sees".
// -----------------------------------------------------------------------------
// Usage (typical):
//   ROI_W=28, ROI_H=28, REC_W=8, REC_H=8  => BOX is 224x224 centered.
//   Connect pix_u8 = framebuffer pixel (u8 grayscale).
//   Connect x,y,de from vga_timing (active coords), pclk=PixelClk.
//   Capture roi_we/roi_addr/roi_dout into a small RAM (784 bytes).
// -----------------------------------------------------------------------------
module downsample_28x28 #(
    parameter integer H_ACTIVE = 640,
    parameter integer V_ACTIVE = 480,
    parameter integer ROI_W    = 28,
    parameter integer ROI_H    = 28,
    parameter integer REC_W    = 8,
    parameter integer REC_H    = 8,
    parameter integer ACC_BITS = 16  // enough for 8*8*255 = 16320 (14 bits); 16 is safe
)(
    input  wire        pclk,
    input  wire        rst_n,

    // active-video coordinates and valid flag
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        de,

    // pixel (0..255). Use grayscale or luma.
    input  wire [7:0]  pix_u8,

    // write interface for 28x28 buffer (row-major)
    output reg  [9:0]  roi_addr,      // 0..(ROI_W*ROI_H-1)
    output reg  [7:0]  roi_dout,      // averaged pixel
    output reg         roi_we,        // 1-cycle strobe when a ROI pixel is ready
    output reg         roi_frame_done,// 1-cycle pulse when last ROI pixel is written

    // box coordinates in active domain (for overlay)
    output wire [9:0]  box_left,
    output wire [9:0]  box_right, // exclusive
    output wire [9:0]  box_up,
    output wire [9:0]  box_down   // exclusive
);
    // box size in active pixels
    localparam integer BOX_W = ROI_W * REC_W;
    localparam integer BOX_H = ROI_H * REC_H;
    localparam integer N = REC_W * REC_H;

    // center box in active area
    localparam integer LEFT  = (H_ACTIVE - BOX_W) / 2;
    localparam integer UP    = (V_ACTIVE - BOX_H) / 2;
    localparam integer RIGHT = LEFT + BOX_W;
    localparam integer DOWN  = UP   + BOX_H;

    assign box_left  = LEFT[9:0];
    assign box_right = RIGHT[9:0];
    assign box_up    = UP[9:0];
    assign box_down  = DOWN[9:0];

    // ROI-in-box test (only when de=1 to ignore blanking)
    wire in_box = de &&
                  (x >= LEFT[9:0])  && (x < RIGHT[9:0]) &&
                  (y >= UP[9:0])    && (y < DOWN[9:0]);

    // local indices
    // NOTE: division/mod by constant REC_W/REC_H will synthesize OK when constants (8).
    wire [9:0] xr = x - LEFT[9:0];
    wire [9:0] yr = y - UP[9:0];

    wire [9:0] roi_x = xr / REC_W;  // 0..ROI_W-1
    wire [9:0] roi_y = yr / REC_H;  // 0..ROI_H-1

    wire [9:0] sub_x = xr % REC_W;  // 0..REC_W-1
    wire [9:0] sub_y = yr % REC_H;  // 0..REC_H-1

    // We accumulate per ROI column (like your core.v style).
    // When we finish each REC_W x REC_H block (sub_x==REC_W-1 && sub_y==REC_H-1),
    // we compute avg and write a single pixel.
    reg [ACC_BITS-1:0] acc_col [0:ROI_W-1];
    reg [ACC_BITS-1:0] sum;
    reg [ACC_BITS-1:0] avg;

    integer i;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<ROI_W; i=i+1) acc_col[i] <= {ACC_BITS{1'b0}};
            roi_we         <= 1'b0;
            roi_frame_done <= 1'b0;
            roi_addr       <= 10'd0;
            roi_dout       <= 8'd0;
        end else begin
            roi_we         <= 1'b0;
            roi_frame_done <= 1'b0;

            // start-of-frame reset for write address can be handled outside if you prefer.
            // Here we implicitly compute roi_addr from roi_x/roi_y on each write.

            if (in_box) begin
                // At the start of each REC_H-row for a given column, reset acc at sub_x==0 && sub_y==0
                if ((sub_x == 0) && (sub_y == 0)) begin
                    acc_col[roi_x] <= pix_u8;
                end else begin
                    acc_col[roi_x] <= acc_col[roi_x] + pix_u8;
                end

                // End of REC_W x REC_H block => emit averaged pixel
                if ((sub_x == (REC_W-1)) && (sub_y == (REC_H-1))) begin
                    // average with rounding: (sum + N/2)/N
                    // N = REC_W*REC_H (typically 64)
                    sum = acc_col[roi_x] + pix_u8; // include current pix if not already in acc (acc has it via nonblocking update order)
                    // Because acc_col updates nonblocking, sum uses old acc_col; we add pix_u8 to cover current cycle.
                    avg = (sum + (N/2)) / N;

                    roi_dout <= (avg[7:0]); // clamp not needed (0..255)
                    roi_addr <= roi_y * ROI_W + roi_x;
                    roi_we   <= 1'b1;

                    if ((roi_x == ROI_W-1) && (roi_y == ROI_H-1))
                        roi_frame_done <= 1'b1;
                end
            end
        end
    end
endmodule

`default_nettype wire
