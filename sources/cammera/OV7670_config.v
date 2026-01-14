`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: OV7670_config
// Description: Converted from SystemVerilog to Verilog for Zybo Z7-20
//              Reads configuration data from ROM and sends it via SCCB
//////////////////////////////////////////////////////////////////////////////////

module OV7670_config #(
    parameter CLK_FREQ = 25000000
    )(
    input  wire        clk,    // Clock
    input  wire        clk_en, // Clock Enable
    input  wire        rst_n,  // Asynchronous reset active low
    input  wire        SCCB_interface_ready,
    input  wire [15:0] rom_data,
    input  wire        start,
    output reg  [7:0]  rom_addr,
    output reg         done,
    output reg  [7:0]  SCCB_interface_addr,
    output reg  [7:0]  SCCB_interface_data,
    output reg         SCCB_interface_start
);

    // 1. State Machine Definitions (enum -> localparam)
    localparam IDLE     = 2'b00;
    localparam SEND_CMD = 2'b01;
    localparam DONE     = 2'b10;
    localparam TIMER    = 2'b11;

    // 2. Registers
    reg [1:0]  state;
    reg [1:0]  return_state;
    reg [31:0] timer;

    // 3. Main State Machine
    always @(posedge clk or negedge rst_n) begin : proc_state
        if(~rst_n) begin
            state <= IDLE;
        end 
        else if(clk_en) begin
            case (state)
                IDLE: begin
                    state <= start ? SEND_CMD : IDLE;
                end
                SEND_CMD: begin
                    case (rom_data)
                        16'hFFFF: begin // End of ROM marker
                            state <= DONE;
                        end
                        16'hFFF0: begin // Delay marker
                            state <= TIMER;
                        end
                        default: begin
                            if (SCCB_interface_ready) begin
                                state <= TIMER;
                            end
                        end 
                    endcase
                end
                DONE: begin
                    state <= IDLE;
                end
                TIMER: begin
                    state <= (timer == 0) ? return_state : TIMER;
                end
                default : begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // 4. Return State Logic
    always @(posedge clk or negedge rst_n) begin : proc_return_state
        if(~rst_n) begin
            return_state <= IDLE;
        end 
        else if(clk_en) begin
            case (state)
                IDLE: begin
                    // do nothing
                end
                SEND_CMD: begin
                    case (rom_data)
                        16'hFFFF: begin
                            // do nothing
                        end
                        16'hFFF0: begin
                            return_state <= SEND_CMD;
                        end
                        default: begin
                            if (SCCB_interface_ready) begin
                                return_state <= SEND_CMD;
                            end
                        end 
                    endcase
                end
                // Other states do nothing regarding return_state
                default: ; 
            endcase
        end
    end

    // 5. ROM Address Control
    always @(posedge clk or negedge rst_n) begin : proc_rom_addr
        if(~rst_n) begin
            rom_addr <= 0;
        end 
        else if(clk_en) begin
            if (state == IDLE) begin
                rom_addr <= 0;
            end
            else if (state == SEND_CMD) begin
                case (rom_data)
                    16'hFFFF: ; // End
                    16'hFFF0: rom_addr <= rom_addr + 1; // Delay, move next
                    default: begin
                        if (SCCB_interface_ready) begin
                            rom_addr <= rom_addr + 1; // Sent, move next
                        end
                    end 
                endcase
            end
        end
    end

    // 6. Done Signal
    always @(posedge clk or negedge rst_n) begin : proc_done
        if(~rst_n) begin
            done <= 0;
        end 
        else if(clk_en) begin
            if (state == IDLE) begin
                if (start) done <= 0;
            end
            else if (state == DONE) begin
                done <= 1;
            end
        end
    end

    // 7. SCCB Interface Address Output
    always @(posedge clk or negedge rst_n) begin : proc_SCCB_interface_addr
        if(~rst_n) begin
            SCCB_interface_addr <= 0;
        end 
        else if(clk_en) begin
            if (state == SEND_CMD) begin
                if (rom_data != 16'hFFFF && rom_data != 16'hFFF0) begin
                     if (SCCB_interface_ready) begin
                        SCCB_interface_addr <= rom_data[15:8];
                     end
                end
            end
        end
    end

    // 8. SCCB Interface Data Output
    always @(posedge clk or negedge rst_n) begin : proc_SCCB_interface_data
        if(~rst_n) begin
            SCCB_interface_data <= 0;
        end 
        else if(clk_en) begin
             if (state == SEND_CMD) begin
                if (rom_data != 16'hFFFF && rom_data != 16'hFFF0) begin
                     if (SCCB_interface_ready) begin
                        SCCB_interface_data <= rom_data[7:0];
                     end
                end
            end
        end
    end

    // 9. SCCB Interface Start Signal
    always @(posedge clk or negedge rst_n) begin : proc_SCCB_interface_start
        if(~rst_n) begin
            SCCB_interface_start <= 0;
        end 
        else if(clk_en) begin
            if (state == SEND_CMD) begin
                if (rom_data != 16'hFFFF && rom_data != 16'hFFF0) begin
                    if (SCCB_interface_ready) begin
                        SCCB_interface_start <= 1;
                    end
                end
            end
            else if (state == TIMER) begin
                SCCB_interface_start <= 0;
            end
        end
    end

    // 10. Timer Logic
    always @(posedge clk or negedge rst_n) begin : proc_timer
        if(~rst_n) begin
            timer <= 0;
        end 
        else if(clk_en) begin
            if (state == SEND_CMD) begin
                if (rom_data == 16'hFFF0) begin
                    timer <= (CLK_FREQ/100); // 10ms delay
                end
                else if (rom_data != 16'hFFFF) begin
                    if (SCCB_interface_ready) begin
                        timer <= 0; // No delay for normal write
                    end
                end
            end
            else if (state == TIMER) begin
                timer <= (timer == 0) ? 0 : timer - 1;
            end
        end
    end

endmodule



