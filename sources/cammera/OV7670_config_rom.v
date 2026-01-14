`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: OV7670_config_rom
// Description:
//   OV7670 configuration ROM
//   - VGA 640x480
//   - YUV422 output
//   - Use Y (luminance) only -> true grayscale
//////////////////////////////////////////////////////////////////////////////////

module OV7670_config_rom(
    input  wire        clk,
    input  wire        clk_en,
    input  wire        rst_n,
    input  wire [7:0]  addr,
    output reg  [15:0] dout
);

    // FFFF : end of ROM
    // FFF0 : delay (handled by controller if supported)

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dout <= 16'h0000;
        end else if (clk_en) begin
            case (addr)

                // --------------------------------------------------
                // Reset
                // --------------------------------------------------
                8'd0:  dout <= 16'h12_80; // COM7: Reset
                8'd1:  dout <= 16'hFF_F0; // Delay after reset

                // --------------------------------------------------
                // Output format: YUV422
                // --------------------------------------------------
                8'd2:  dout <= 16'h12_00; // COM7: YUV
                8'd3:  dout <= 16'h8C_00; // RGB444/555 disable
                8'd4:  dout <= 16'h3A_04; // TSLB: YUYV order
                8'd5:  dout <= 16'h40_D0; // COM15: full range 0-255, YUV

                // --------------------------------------------------
                // VGA timing (640x480)
                // --------------------------------------------------
                8'd6:  dout <= 16'h11_00; // CLKRC: input clock /1
                8'd7:  dout <= 16'h0C_00; // COM3: no scaling
                8'd8:  dout <= 16'h3E_00; // COM14: no scaling

                // Horizontal window
                8'd9:  dout <= 16'h17_13; // HSTART
                8'd10: dout <= 16'h18_01; // HSTOP
                8'd11: dout <= 16'h32_B6; // HREF

                // Vertical window
                8'd12: dout <= 16'h19_02; // VSTART
                8'd13: dout <= 16'h1A_7A; // VSTOP

                // --------------------------------------------------
                // Image control (disable test patterns, etc.)
                // --------------------------------------------------
                8'd14: dout <= 16'h70_3A; // Scaling X
                8'd15: dout <= 16'h71_35; // Scaling Y
                8'd16: dout <= 16'h72_11; // DCW
                8'd17: dout <= 16'h73_F0; // PCLK divider

                // --------------------------------------------------
                // End of ROM
                // --------------------------------------------------
                default: dout <= 16'hFF_FF;
            endcase
        end
    end
endmodule
