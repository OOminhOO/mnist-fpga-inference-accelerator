`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sccb_interface
// Description: Converted from SystemVerilog to Verilog for Zybo Z7-20
//////////////////////////////////////////////////////////////////////////////////

module sccb_interface #(
    parameter CAMERA_ADDR = 8'h42,
    parameter CLK_FREQ = 25000000,
    parameter SCCB_FREQ = 100000
    )(
    input  wire       clk,    // Clock
    input  wire       clk_en, // Clock Enable
    input  wire       rst_n,  // Asynchronous reset active low
    input  wire       start,
    input  wire [7:0] address,
    input  wire [7:0] data,
    output reg        ready,
    output reg        read_done,
    output reg        sioc_signal,
    
    output reg  [7:0] read_data,
    inout  wire       siod_signal
);

    // 1. State Machine Definitions (enum -> localparam)
    localparam IDLE         = 5'd0;
    localparam START_SIGNAL = 5'd1;
    localparam LOAD_BYTE    = 5'd2;
    localparam TX_BYTE_1    = 5'd3;
    localparam TX_BYTE_2    = 5'd4;
    localparam TX_BYTE_3    = 5'd5;
    localparam TX_BYTE_4    = 5'd6;
    localparam RX_BYTE_1    = 5'd7;
    localparam RX_BYTE_2    = 5'd8;
    localparam RX_BYTE_3    = 5'd9;
    localparam RX_BYTE_4    = 5'd10;
    localparam END_SIGNAL_1 = 5'd11;
    localparam END_SIGNAL_2 = 5'd12;
    localparam END_SIGNAL_3 = 5'd13;
    localparam END_SIGNAL_4 = 5'd14;
    localparam ALL_DONE     = 5'd15;
    localparam TIMER        = 5'd16;

    localparam ACTION_WRITE = 1'b0;
    localparam ACTION_READ  = 1'b1;

    localparam ORDER_FIRST_WRITE = 1'b0;
    localparam ORDER_SECOND_READ = 1'b1;
    
    // 2. Registers
    reg [4:0]  state;
    reg [4:0]  return_state;
    wire       action; // Combinational logic
    reg        order;
    
    reg [31:0] timer;
    reg [7:0]  latched_address;
    reg [7:0]  latched_data;
    reg [1:0]  byte_counter;
    reg [7:0]  tx_byte;
    reg [7:0]  rx_byte;
    reg [3:0]  byte_index;
    reg        SIOD_oe;
    reg        siod_temp;
    
    // NOTE: former_two_phase_write was declared but not driven in original code.
    // Assuming 0 (default behavior for logic not assigned) to prevent errors.
    wire       former_two_phase_write; 
    assign     former_two_phase_write = 1'b0; 

    // 3. Logic Assignments
    assign siod_signal = SIOD_oe ? 1'bz : siod_temp;
    // pullup p (siod_signal); // Xilinx Vivado handles internal pullups in .xdc usually, but can keep.
    
    assign action = (address == 8'hFE) ? ACTION_READ : ACTION_WRITE;

    // 4. Main State Machine (proc_state)
    always @(posedge clk or negedge rst_n) begin : proc_state
        if(~rst_n) begin
            state <= IDLE;
        end else if(clk_en) begin
            case (action)
                ACTION_READ: begin
                    case (state)
                        IDLE: begin
                            if (start || !former_two_phase_write) state <= TIMER;
                        end
                        START_SIGNAL: state <= TIMER;
                        LOAD_BYTE: begin
                            if (byte_counter == 2) state <= END_SIGNAL_1;
                            else if(byte_counter == 1 && !former_two_phase_write) state <= RX_BYTE_1;
                            else state <= TX_BYTE_1;
                        end
                        TX_BYTE_1: state <= TIMER;
                        TX_BYTE_2: state <= TIMER;
                        TX_BYTE_3: state <= TIMER;
                        TX_BYTE_4: state <= (byte_index == 8) ? LOAD_BYTE : TX_BYTE_1;
                        RX_BYTE_1: state <= TIMER;
                        RX_BYTE_2: state <= TIMER;
                        RX_BYTE_3: state <= TIMER;
                        RX_BYTE_4: state <= (byte_index == 8) ? END_SIGNAL_1 : RX_BYTE_1;
                        END_SIGNAL_1: state <= TIMER;
                        END_SIGNAL_2: state <= TIMER;
                        END_SIGNAL_3: state <= TIMER;
                        END_SIGNAL_4: state <= TIMER;
                        ALL_DONE:     state <= TIMER;
                        TIMER:        state <= (timer == 0) ? return_state : TIMER;
                        default:      state <= IDLE;
                    endcase
                end
                ACTION_WRITE: begin
                    case (state)
                        IDLE:         if (start) state <= TIMER;
                        START_SIGNAL: state <= TIMER;
                        LOAD_BYTE:    state <= (byte_counter == 3) ? END_SIGNAL_1 : TX_BYTE_1;
                        TX_BYTE_1:    state <= TIMER;
                        TX_BYTE_2:    state <= TIMER;
                        TX_BYTE_3:    state <= TIMER;
                        TX_BYTE_4:    state <= (byte_index == 8) ? LOAD_BYTE : TX_BYTE_1;
                        // RX_BYTE cases do nothing in WRITE
                        END_SIGNAL_1: state <= TIMER;
                        END_SIGNAL_2: state <= TIMER;
                        END_SIGNAL_3: state <= TIMER;
                        END_SIGNAL_4: state <= TIMER;
                        ALL_DONE:     state <= TIMER;
                        TIMER:        state <= (timer == 0) ? return_state : TIMER;
                        default:      state <= IDLE;
                    endcase                     
                end
                default: ; // Do nothing
            endcase
        end
    end    

    // 5. Return State Logic
    always @(posedge clk or negedge rst_n) begin : proc_return_state
        if(~rst_n) begin
            return_state <= IDLE;
        end else if(clk_en) begin
            case (state)
                IDLE:         return_state <= START_SIGNAL;
                START_SIGNAL: return_state <= LOAD_BYTE;
                TX_BYTE_1:    return_state <= TX_BYTE_2;
                TX_BYTE_2:    return_state <= TX_BYTE_3;
                TX_BYTE_3:    return_state <= TX_BYTE_4;
                RX_BYTE_1:    return_state <= RX_BYTE_2;
                RX_BYTE_2:    return_state <= RX_BYTE_3;
                RX_BYTE_3:    return_state <= RX_BYTE_4;
                END_SIGNAL_1: return_state <= END_SIGNAL_2;
                END_SIGNAL_2: return_state <= END_SIGNAL_3;
                END_SIGNAL_3: return_state <= END_SIGNAL_4;
                END_SIGNAL_4: return_state <= ALL_DONE;
                ALL_DONE:     return_state <= IDLE;
                default: ; // Maintain value
            endcase
        end
    end

    // 6. Timer Logic
    always @(posedge clk or negedge rst_n) begin : proc_timer
        if(~rst_n) begin
            timer <= 0;
        end else if(clk_en) begin
            if (state == TIMER) begin
                timer <= (timer == 0) ? 0 : timer - 1;
            end else begin
                // Load timer values based on NEXT state (or current logic flow)
                // Note: Simplified logic by grouping identical timer values
                case (state)
                    IDLE, START_SIGNAL, TX_BYTE_1, TX_BYTE_2, TX_BYTE_3,
                    RX_BYTE_1, RX_BYTE_2, RX_BYTE_3, 
                    END_SIGNAL_1, END_SIGNAL_2, END_SIGNAL_3, END_SIGNAL_4: 
                        timer <= (CLK_FREQ/(4*SCCB_FREQ));
                    ALL_DONE: 
                        timer <= (10*CLK_FREQ/SCCB_FREQ);
                    LOAD_BYTE: begin
                        if(action == ACTION_WRITE) timer <= (CLK_FREQ/(4*SCCB_FREQ));
                    end
                    default: ;
                endcase
            end
        end
    end

    // 7. Data Latching
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            latched_address <= 0;
            latched_data <= 0;
        end else if(clk_en && state == IDLE && start) begin
             if(action == ACTION_READ) latched_address <= data;
             else latched_address <= address;
             
             if(action == ACTION_WRITE) latched_data <= data;
        end
    end

    // 8. Byte Counter
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) byte_counter <= 0;
        else if(clk_en) begin
            if(state == IDLE || state == ALL_DONE) byte_counter <= 0;
            else if(state == LOAD_BYTE) byte_counter <= byte_counter + 1;
        end
    end

    // 9. TX Byte Logic
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) tx_byte <= 0;
        else if(clk_en) begin
            if(state == LOAD_BYTE) begin
                if(action == ACTION_READ) begin
                    case (byte_counter)
                        0: tx_byte <= CAMERA_ADDR + !former_two_phase_write;
                        1: tx_byte <= latched_address;
                    endcase
                end else begin // WRITE
                    case (byte_counter)
                        0: tx_byte <= CAMERA_ADDR;
                        1: tx_byte <= latched_address;
                        2: tx_byte <= latched_data;
                    endcase
                end
            end else if (state == TX_BYTE_4) begin
                tx_byte <= tx_byte << 1;
            end
        end
    end

    // 10. RX Byte & Read Data
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rx_byte <= 0;
            read_data <= 0;
        end else if(clk_en) begin
            if(state == RX_BYTE_2 && byte_index != 8) 
                rx_byte[0] <= siod_signal;
            else if(state == RX_BYTE_4) 
                rx_byte <= rx_byte << 1;
            
            // Latch to output
            if(action == ACTION_READ && state == RX_BYTE_3 && byte_index == 7)
                read_data <= rx_byte;
        end
    end

    // 11. Byte Index
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) byte_index <= 0;
        else if(clk_en) begin
            if(state == IDLE || state == LOAD_BYTE) byte_index <= 0;
            else if(state == TX_BYTE_4 || state == RX_BYTE_4) byte_index <= byte_index + 1;
        end
    end

    // 12. SIOC Signal Output
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) sioc_signal <= 1;
        else if(clk_en) begin
            case(state)
                START_SIGNAL, TX_BYTE_3, RX_BYTE_3, END_SIGNAL_3: sioc_signal <= 1;
                TX_BYTE_1, RX_BYTE_1, END_SIGNAL_1: sioc_signal <= 0;
            endcase
        end
    end

    // 13. SIOD OE (Output Enable)
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) SIOD_oe <= 1;
        else if(clk_en) begin
            case(state)
                IDLE: if(start) SIOD_oe <= 0;
                TX_BYTE_2: SIOD_oe <= (byte_index == 8);
                RX_BYTE_2: if(action == ACTION_READ) SIOD_oe <= (byte_index != 8);
                END_SIGNAL_2: SIOD_oe <= 0;
                ALL_DONE: SIOD_oe <= 1;
            endcase
        end
    end

    // 14. SIOD Temp (Data Out)
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) siod_temp <= 1; // Pull-up default
        else if(clk_en) begin
            case(state)
                IDLE: if(start) siod_temp <= 1;
                START_SIGNAL: siod_temp <= 0;
                TX_BYTE_2: siod_temp <= tx_byte[7];
                RX_BYTE_2: if(action == ACTION_READ && byte_index == 8) siod_temp <= 1;
                END_SIGNAL_2: siod_temp <= 0;
                END_SIGNAL_4: siod_temp <= 1;
            endcase
        end
    end

    // 15. Read Done & Ready
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            read_done <= 0;
            ready <= 1;
        end else if(clk_en) begin
            // Read Done Logic
            if(action == ACTION_READ && state == END_SIGNAL_3) read_done <= 1;
            else if(state == TIMER) read_done <= 0;

            // Ready Logic
            if(state == IDLE) begin
                if(start) ready <= 0;
                else ready <= 1;
            end
        end
    end

    // 16. Order Logic (Toggle between read/write phases if needed)
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) order <= ORDER_FIRST_WRITE;
        else if(clk_en && state == ALL_DONE && action == ACTION_READ) begin
            if(order == ORDER_FIRST_WRITE) order <= ORDER_SECOND_READ;
            else order <= ORDER_FIRST_WRITE;
        end
    end

endmodule