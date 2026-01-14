
`timescale 1ns/1ps
`default_nettype none
// -----------------------------------------------------------------------------
// roi_box_overlay
// - Simple rectangle-border overlay for HDMI/VGA pixel path.
// - Use the same LEFT/RIGHT/UP/DOWN as roi28x28_downsample_writer so the drawn
//   box matches exactly the CNN ROI.
// - Outputs RGB444 (12-bit) from grayscale input, with border colored.
// -----------------------------------------------------------------------------
module overlay_28x28 #(
    parameter integer THICK = 2,            // border thickness (pixels)
    parameter [11:0]  BORDER_RGB = 12'hF00  // default red in RGB444
)(
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        de,
    input  wire [7:0]  pix_u8,      // grayscale
    input  wire [9:0]  box_left,
    input  wire [9:0]  box_right,   // exclusive
    input  wire [9:0]  box_up,
    input  wire [9:0]  box_down,    // exclusive
    output wire [11:0] rgb444_out
);
    wire in_box = de &&
                  (x >= box_left)  && (x < box_right) &&
                  (y >= box_up)    && (y < box_down);

    wire on_border = in_box && (
        (x < box_left + THICK) || (x >= box_right - THICK) ||
        (y < box_up   + THICK) || (y >= box_down - THICK)
    );

    wire [3:0] g = pix_u8[7:4];
    wire [11:0] rgb_normal = {g,g,g};

    assign rgb444_out = de ? (on_border ? BORDER_RGB : rgb_normal) : 12'h000;
endmodule

`default_nettype wire
