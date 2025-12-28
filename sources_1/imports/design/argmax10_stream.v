`timescale 1ns / 1ps

module comparator (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               in_valid,
    // in_sof 제거 (in_cls == 0 으로 판단)
    input  wire [3:0]         in_cls,
    input  wire signed [31:0] in_logit,
    input  wire               in_last,

    output reg  [3:0]         decision,
    output reg                out_valid
);
    reg signed [31:0] best_logit;
    reg [3:0]         best_cls;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            best_logit <= -32'sd2147483648; // 최소값 (Signed 32bit Min)
            best_cls   <= 4'd0;
            decision   <= 4'd0;
            out_valid  <= 1'b0;
        end else begin
            out_valid <= 1'b0; // 평소엔 0 (Pulse)

            if (in_valid) begin
                // 1. 첫 번째 클래스(0번)가 들어오면 무조건 초기화
                if (in_cls == 4'd0) begin
                    best_logit <= in_logit;
                    best_cls   <= in_cls;
                end 
                // 2. 그 외 (1~9번): 현재 값이 더 크면 갱신
                else begin
                    if (in_logit > best_logit) begin
                        best_logit <= in_logit;
                        best_cls   <= in_cls;
                    end
                end

                // 3. 마지막 클래스(9번)일 때 최종 결정 (타이밍 버그 수정)
                if (in_last) begin
                    out_valid <= 1'b1;
                    
                    // ★ 중요: 9번이 기존 1등보다 크면 9번이 우승, 아니면 기존 1등 우승
                    // (best_logit이 아직 업데이트 되기 전 값을 가지고 있으므로 여기서 비교해야 함)
                    if (in_cls == 4'd0) begin
                        // 혹시라도 클래스가 1개뿐인 경우 (방어코드)
                        decision <= in_cls;
                    end 
                    else if (in_logit > best_logit) begin
                        decision <= in_cls; // 방금 들어온 9번이 역전승!
                    end else begin
                        decision <= best_cls; // 기존 1등 유지
                    end
                end
            end
        end
    end
endmodule