`timescale 1ns / 1ps

module tb_cnn_10k_verify; // 모듈 이름 변경 (선택사항)

    // ========================================================================
    // 1. 파라미터 및 경로 설정 (★수정 완료★)
    // ========================================================================
    // 10k용 파일로 변경
    parameter IMG_FILE = "input_10k.txt";
    parameter LBL_FILE = "label_10k.txt";

    integer N_TEST = 10000; // ★수정: 테스트 개수 1000 -> 10000

    // ========================================================================
    // 2. 신호 선언
    // ========================================================================
    reg           clk;
    reg           rst_n;
    reg  [7:0]    data_in;
    reg           data_valid;
    wire [3:0]    decision;
    wire          out_valid;

    // ★수정: 대용량 메모리 선언 확장★
    // 10,000장 * 784픽셀 = 7,840,000 바이트
    // 인덱스는 0부터 시작하므로 7,839,999 까지 선언
    reg [7:0]  mem_inputs [0:7839999]; 
    
    // 정답지 10,000개
    reg [31:0] mem_labels [0:9999];   

    // 카운터 및 인덱스
    integer img_idx;    // 몇 번째 이미지인지
    integer px_idx;     // 픽셀 인덱스 (0~783)
    integer correct_cnt;
    integer error_cnt;
    
    // ========================================================================
    // 3. DUT 인스턴스
    // ========================================================================
    cnn_core_top u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_in    (data_in),
        .data_valid (data_valid),
        .decision   (decision),
        .out_valid  (out_valid)
    );

    // ========================================================================
    // 4. 클럭 및 초기화
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // ========================================================================
    // 5. 메인 검증 시퀀스
    // ========================================================================
    initial begin
        // (1) 파일 로드
        $display("\n[TB] Loading 10,000 Images & Labels... (This may take a moment)");
        
        // 시뮬레이터가 파일을 읽을 메모리 공간이 충분한지 확인 필요
        $readmemh(IMG_FILE, mem_inputs);
        $readmemh(LBL_FILE, mem_labels);

        // (2) 변수 초기화
        rst_n = 0;
        data_valid = 0;
        data_in = 0;
        correct_cnt = 0;
        error_cnt = 0;
        
        #100;
        rst_n = 1;
        #100;

        $display("[TB] Start 10,000 Image Verification Loop...");
        $display("------------------------------------------------");

        // (3) 루프 시작
        for (img_idx = 0; img_idx < N_TEST; img_idx = img_idx + 1) begin
            
            // --- 이미지 1장 주입 (784클럭) ---
            for (px_idx = 0; px_idx < 784; px_idx = px_idx + 1) begin
                @(posedge clk);
                data_valid <= 1;
                // 메모리 주소 계산: (현재 이미지 번호 * 784) + 픽셀 번호
                data_in    <= mem_inputs[img_idx * 784 + px_idx];
            end
            
            // 주입 끝
            @(posedge clk);
            data_valid <= 0;
            data_in    <= 0;

            // --- 결과 대기 ---
            wait(out_valid);
            
            // --- 채점 ---
            @(posedge clk); 
            if (decision === mem_labels[img_idx][3:0]) begin
                correct_cnt = correct_cnt + 1;
            end else begin
                error_cnt = error_cnt + 1;
                // 에러가 너무 많이 뜨면 로그가 지저분해지므로 에러는 초반 20개만 자세히 출력하거나 그대로 둠
                 if (error_cnt <= 20) begin
                    $display("[FAIL] Image #%0d: Expected=%d, Got=%d", 
                             img_idx, mem_labels[img_idx], decision);
                 end
            end

            // 진행 상황 출력 (1000개마다 출력하도록 수정 추천 - 로그 너무 길어짐 방지)
            if ((img_idx + 1) % 1000 == 0) begin
                $display("   ... Processed %0d/%0d (Current Accuracy: %0.2f%%)", 
                         img_idx + 1, N_TEST, (correct_cnt * 100.0) / (img_idx + 1));
            end

            // 다음 이미지를 위해 약간의 텀
            repeat(20) @(posedge clk);
        end

        // (4) 최종 결과 출력
        $display("------------------------------------------------");
        $display("[FINAL RESULT - 10k Test]");
        $display("Total Images : %0d", N_TEST);
        $display("Correct      : %0d", correct_cnt);
        $display("Errors       : %0d", error_cnt);
        
        // 정확도 계산 (소수점 2자리)
        $display("Accuracy     : %0.2f %%", (correct_cnt * 100.0) / N_TEST);

        if (error_cnt == 0) begin
            $display("\n   ★ SUCCESS! 100%% Accuracy with 10k Set! ★\n");
        end else if (correct_cnt >= 9000) begin
             $display("\n   [PASS] Good Accuracy (>90%%).\n");
        end else begin
            $display("\n   [FAIL] Low Accuracy.\n");
        end
        $display("------------------------------------------------");
        $finish;
    end

endmodule