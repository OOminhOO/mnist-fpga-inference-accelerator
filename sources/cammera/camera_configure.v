`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: camera_configure
// Description: Converted from SystemVerilog to Verilog for Zybo Z7-20
//////////////////////////////////////////////////////////////////////////////////

module camera_configure
    #(
    parameter CLK_FREQ = 25000000
    )
    (
    input  wire       clk,
    input  wire       sclk,
    input  wire       clk_en,
    input  wire       rst_n,
    output wire       sioc,
    inout  wire       siod,
    output wire       done,
    output wire       reset,
    output wire       pwdn,
    output wire       xclk,
    output wire [7:0] read,
    input  wire       capture_end,
    input  wire       core_end
    );
    
    // SystemVerilog 'logic' -> Verilog 'reg' or 'wire'
    wire       sys_clk; // ?? ????? ???????? ?????? ??? ?? ?????? ?????? ????????.
    reg        start;
    reg  [9:0] counter;
    reg        xclk_en;
    
    // logic assignments
    assign pwdn  = 1'b0;
    assign reset = 1'b1;
    assign xclk  = xclk_en ? sclk : 1'b0;

    // Internal wires for sub-module connection
    wire [7:0]  rom_addr;
    wire [15:0] rom_dout;
    wire [7:0]  SCCB_addr;
    wire [7:0]  SCCB_data;
    wire        SCCB_start;
    wire        SCCB_ready;
    
    // always_ff -> always
    // xclk enable control logic
    always @(posedge sclk or negedge rst_n) begin : proc_xclk_en
       if (~rst_n) begin
           xclk_en <= 1'b1;
       end
       else begin
           if (done && capture_end) begin       // SCCB ?????? ???? ?????? sync ?????? ????
               xclk_en <= 1'b0;
           end 
           else if (core_end) begin
               xclk_en <= 1'b1;
           end
       end
    end

    // Start signal generation logic
    always @(posedge clk or negedge rst_n) begin : proc_start
        if(~rst_n) begin
            start   <= 1'b0;
            counter <= 100;
        end 
        else if(clk_en) begin
            counter <= (counter == 0) ? 0 : counter - 1;
            if (counter == 1) begin
                start <= 1'b1;
            end 
            else begin
                start <= 1'b0;
            end
        end
    end
    
    // Sub-module instantiation
    // (Note: ??? ???? Verilog?? ????? ????? ?? ??????)
    
    OV7670_config_rom rom1(
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),              
        .addr(rom_addr),        
        .dout(rom_dout)
        );
        
    OV7670_config #(.CLK_FREQ(CLK_FREQ)) config_1(
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .SCCB_interface_ready(SCCB_ready),
        .rom_data(rom_dout),
        .start(start),
        .rom_addr(rom_addr),
        .done(done),
        .SCCB_interface_addr(SCCB_addr),
        .SCCB_interface_data(SCCB_data),
        .SCCB_interface_start(SCCB_start)
        );
    
    sccb_interface #( .CLK_FREQ(CLK_FREQ)) SCCB1(
        .clk(clk),
        .clk_en(clk_en),
        .rst_n(rst_n),
        .start(SCCB_start),
        .address(SCCB_addr),
        .data(SCCB_data),
        .ready(SCCB_ready),
        .sioc_signal(sioc),
        .siod_signal(siod),
        .read_data(read)
        );
    
endmodule