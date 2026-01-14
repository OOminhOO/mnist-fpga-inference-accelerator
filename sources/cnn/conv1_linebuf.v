module conv1_linebuf #(
    parameter DATA_BITS = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [DATA_BITS-1:0] data_in,
    output reg         window_valid,
    // (출력 포트들은 그대로 유지)
    output wire [DATA_BITS-1:0] data_out_0,  data_out_1,  data_out_2,  data_out_3,  data_out_4,
    output wire [DATA_BITS-1:0] data_out_5,  data_out_6,  data_out_7,  data_out_8,  data_out_9,
    output wire [DATA_BITS-1:0] data_out_10, data_out_11, data_out_12, data_out_13, data_out_14,
    output wire [DATA_BITS-1:0] data_out_15, data_out_16, data_out_17, data_out_18, data_out_19,
    output wire [DATA_BITS-1:0] data_out_20, data_out_21, data_out_22, data_out_23, data_out_24
);

    localparam IMG_WIDTH = 28;
    localparam K_SIZE    = 5;

    reg [DATA_BITS-1:0] lb0 [0:IMG_WIDTH-1];
    reg [DATA_BITS-1:0] lb1 [0:IMG_WIDTH-1];
    reg [DATA_BITS-1:0] lb2 [0:IMG_WIDTH-1];
    reg [DATA_BITS-1:0] lb3 [0:IMG_WIDTH-1];
    reg [DATA_BITS-1:0] win [0:4][0:4];

    reg [4:0] col_cnt;
    reg [4:0] row_cnt;
    integer i;

    // 초기화 및 동작
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
            window_valid <= 0;
            // 윈도우 초기화
            for(i=0; i<5; i=i+1) begin
                win[i][0]<=0; win[i][1]<=0; win[i][2]<=0; win[i][3]<=0; win[i][4]<=0;
            end
        end else if (in_valid) begin
            // 1. 좌표 계산
            if (col_cnt == IMG_WIDTH-1) begin
                col_cnt <= 0;
                if (row_cnt == IMG_WIDTH-1) row_cnt <= 0;
                else row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end

            // 2. Line Buffer Shift
            for (i = 0; i < IMG_WIDTH-1; i = i + 1) begin
                lb0[i] <= lb0[i+1]; lb1[i] <= lb1[i+1];
                lb2[i] <= lb2[i+1]; lb3[i] <= lb3[i+1];
            end
            lb0[IMG_WIDTH-1] <= lb1[0];
            lb1[IMG_WIDTH-1] <= lb2[0];
            lb2[IMG_WIDTH-1] <= lb3[0];
            lb3[IMG_WIDTH-1] <= data_in;

            // 3. Window Shift
            for (i = 0; i < 5; i = i + 1) begin
                win[i][0] <= win[i][1]; win[i][1] <= win[i][2];
                win[i][2] <= win[i][3]; win[i][3] <= win[i][4];
            end
            win[0][4] <= lb0[0]; win[1][4] <= lb1[0];
            win[2][4] <= lb2[0]; win[3][4] <= lb3[0];
            win[4][4] <= data_in;

            // 4. Valid 생성 (정석: 데이터가 유효한 구간인지 정확히 체크)
            if ((row_cnt >= 4) && (col_cnt >= 4)) // Index 4 = 5번째 픽셀
                window_valid <= 1;
            else
                window_valid <= 0;
                
        end else begin
            window_valid <= 0;
        end
    end

    // Output Assign
    assign data_out_0  = win[0][0]; assign data_out_1  = win[0][1]; assign data_out_2  = win[0][2]; assign data_out_3  = win[0][3]; assign data_out_4  = win[0][4];
    assign data_out_5  = win[1][0]; assign data_out_6  = win[1][1]; assign data_out_7  = win[1][2]; assign data_out_8  = win[1][3]; assign data_out_9  = win[1][4];
    assign data_out_10 = win[2][0]; assign data_out_11 = win[2][1]; assign data_out_12 = win[2][2]; assign data_out_13 = win[2][3]; assign data_out_14 = win[2][4];
    assign data_out_15 = win[3][0]; assign data_out_16 = win[3][1]; assign data_out_17 = win[3][2]; assign data_out_18 = win[3][3]; assign data_out_19 = win[3][4];
    assign data_out_20 = win[4][0]; assign data_out_21 = win[4][1]; assign data_out_22 = win[4][2]; assign data_out_23 = win[4][3]; assign data_out_24 = win[4][4];

endmodule