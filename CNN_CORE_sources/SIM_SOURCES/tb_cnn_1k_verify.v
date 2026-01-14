`timescale 1ns / 1ps

module tb_cnn_1k_verify;

    // ========================================================================
    // 1. 파라미터 및 경로 설정 (★수정 필요★)
    // ========================================================================
    // 아까 수정하신 절대 경로로 맞춰주세요!
    parameter IMG_FILE = "input_1k.txt";
    parameter LBL_FILE = "label_1k.txt";

    integer N_TEST = 1000; // 테스트할 개수

    // ========================================================================
    // 2. 신호 선언
    // ========================================================================
    reg          clk;
    reg          rst_n;
    reg  [7:0]   data_in;
    reg          data_valid;
    wire [3:0]   decision;
    wire         out_valid;

    // 대용량 메모리 선언
    // 1000장 * 784픽셀 = 784,000 바이트
    reg [7:0]  mem_inputs [0:784000]; 
    reg [31:0] mem_labels [0:1000];   // 정답지

    // 카운터 및 인덱스
    integer img_idx;   // 몇 번째 이미지인지
    integer px_idx;    // 픽셀 인덱스 (0~783)
    integer correct_cnt;
    integer error_cnt;
    integer file_ptr_idx; // 전체 메모리 인덱스

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
        $display("\n[TB] Loading 1,000 Images & Labels...");
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

        $display("[TB] Start 1,000 Image Verification Loop...");
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
            // out_valid가 1이 될 때까지 기다림
            wait(out_valid);
            
            // --- 채점 ---
            // 타이밍 맞추기 위해 클럭 엣지에서 샘플링
            @(posedge clk); 
            if (decision === mem_labels[img_idx][3:0]) begin
                correct_cnt = correct_cnt + 1;
            end else begin
                error_cnt = error_cnt + 1;
                $display("[FAIL] Image #%0d: Expected=%d, Got=%d", 
                         img_idx, mem_labels[img_idx], decision);
            end

            // 진행 상황 출력 (100개마다)
            if ((img_idx + 1) % 100 == 0) begin
                $display("   ... Processed %0d/%0d (Errors: %0d)", 
                         img_idx + 1, N_TEST, error_cnt);
            end

            // 다음 이미지를 위해 약간의 텀을 둠 (Pipeline Flush 여유)
            repeat(20) @(posedge clk);
        end

        // (4) 최종 결과 출력
        $display("------------------------------------------------");
        $display("[FINAL RESULT]");
        $display("Total Images : %0d", N_TEST);
        $display("Correct      : %0d", correct_cnt);
        $display("Errors       : %0d", error_cnt);
        
        if (error_cnt == 0) begin
            $display("\n   ★ SUCCESS! 100%% Accuracy Match with Python! ★\n");
        end else begin
            $display("\n   [FAIL] There were errors.\n");
        end
        $display("------------------------------------------------");
        $finish;
    end

endmodule