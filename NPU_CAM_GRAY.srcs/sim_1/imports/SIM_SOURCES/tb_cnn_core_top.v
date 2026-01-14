`timescale 1ns / 1ps

module tb_cnn_core_top;

    // ========================================================================
    // 1. 신호 및 변수 선언
    // ========================================================================
    reg          clk;
    reg          rst_n;
    reg  [7:0]   data_in;
    reg          data_valid;
    wire [3:0]   decision;
    wire         out_valid;

    // Loop 및 인덱스용 변수 (Verilog는 initial 블록 밖에서 선언 권장)
    integer i;
    integer err_cnt;
    integer c1_cnt;
    integer p1_cnt;
    integer c2_cnt;
    integer p2_cnt;
    integer fc_cnt;

    // ========================================================================
    // 2. DUT (Device Under Test) 인스턴스
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
    // 3. Golden Data 메모리 (Hex 파일 로드용)
    // ========================================================================
    reg [7:0]  mem_img   [0:783];             // Input: 28x28
    reg [7:0]  mem_conv1 [0:1727];            // Conv1: 24x24x3
    reg [7:0]  mem_pool1 [0:431];             // Pool1: 12x12x3
    reg [7:0]  mem_conv2 [0:191];             // Conv2: 8x8x3
    reg [7:0]  mem_pool2 [0:47];              // Pool2: 4x4x3
    reg [31:0] mem_fc    [0:9];               // FC: 10 logits (32bit)
    reg [31:0] mem_pred  [0:0];               // Final: 1 value

    // ========================================================================
    // 4. 클럭 생성
    // ========================================================================
    initial begin
        clk = 0;
        forever #4 clk = ~clk; // 100MHz (10ns 주기)
    end

// ========================================================================
    // 5. 메인 시퀀스 (파일 로드 -> 입력 주입 -> 결과 확인)
    // ========================================================================
    initial begin
        // 변수 초기화
        err_cnt = 0;
        c1_cnt  = 0;
        p1_cnt  = 0;
        c2_cnt  = 0;
        p2_cnt  = 0;
        fc_cnt  = 0;

        // (1) Golden Data 로드 (상대경로)
        $display("\n[TB] Loading Golden Vectors...");
        
        $readmemh("input_img.txt",  mem_img);
        $readmemh("conv1_out.txt",  mem_conv1);
        $readmemh("pool1_out.txt",  mem_pool1);
        $readmemh("conv2_out.txt",  mem_conv2);
        $readmemh("pool2_out.txt",  mem_pool2);
        $readmemh("fc_out.txt",     mem_fc);
        $readmemh("final_pred.txt", mem_pred);

        // (2) 리셋
        rst_n = 0;
        data_valid = 0;
        data_in = 0;
        #100;
        rst_n = 1;
        #100;

        // (3) 이미지 주입 (28x28 = 784 cycles)
        $display("[TB] Start Feeding Image...");
        for (i = 0; i < 784; i = i + 1) begin
            @(posedge clk);
            data_valid <= 1;
            data_in    <= mem_img[i];
        end
        @(posedge clk);
        data_valid <= 0;
        data_in    <= 0;

        // (4) 완료 대기
        fork
            begin
                wait(out_valid);
                @(posedge clk);
                #100;
                $display("\n==================================================");
                if (err_cnt == 0) $display("   [SUCCESS] ALL CHECKS PASSED!");
                else              $display("   [FAIL] Total Errors: %0d", err_cnt);
                $display("==================================================");
                $finish;
            end
            begin
                #50000; 
                $display("\n[ERROR] Simulation Timeout! output_valid never asserted.");
                $finish;
            end
        join
    end


    // ========================================================================
    // 6. 자동 검증 모니터 (Hierarchical Access 사용)
    //    주의: Verilog에서도 상위에서 하위 모듈 wire 접근(u_dut.u_conv1...) 가능
    // ========================================================================

    // --- CHECK 1: Conv1 Output (u8x3) ---
    always @(posedge clk) begin
        if (u_dut.u_conv1.out_valid) begin
            // 채널 0
            if (u_dut.u_conv1.out_1 !== mem_conv1[c1_cnt*3 + 0]) begin
                $display("[ERR] Conv1 Ch0 mismatch at idx %0d: EXP=%h, RTL=%h", 
                         c1_cnt, mem_conv1[c1_cnt*3 + 0], u_dut.u_conv1.out_1);
                err_cnt = err_cnt + 1;
            end
            // 채널 1
            if (u_dut.u_conv1.out_2 !== mem_conv1[c1_cnt*3 + 1]) begin
                $display("[ERR] Conv1 Ch1 mismatch at idx %0d: EXP=%h, RTL=%h", 
                         c1_cnt, mem_conv1[c1_cnt*3 + 1], u_dut.u_conv1.out_2);
                err_cnt = err_cnt + 1;
            end
            // 채널 2
            if (u_dut.u_conv1.out_3 !== mem_conv1[c1_cnt*3 + 2]) begin
                $display("[ERR] Conv1 Ch2 mismatch at idx %0d: EXP=%h, RTL=%h", 
                         c1_cnt, mem_conv1[c1_cnt*3 + 2], u_dut.u_conv1.out_3);
                err_cnt = err_cnt + 1;
            end
            c1_cnt = c1_cnt + 1;
        end
    end

    // --- CHECK 2: Pool1 Output (u8x3) ---
    always @(posedge clk) begin
        if (u_dut.u_pool1.out_valid) begin
            if (u_dut.u_pool1.out_1 !== mem_pool1[p1_cnt*3 + 0]) begin
                $display("[ERR] Pool1 Ch0 mismatch at idx %0d: EXP=%h, RTL=%h", p1_cnt, mem_pool1[p1_cnt*3 + 0], u_dut.u_pool1.out_1); 
                err_cnt = err_cnt + 1;
            end
            if (u_dut.u_pool1.out_2 !== mem_pool1[p1_cnt*3 + 1]) begin
                $display("[ERR] Pool1 Ch1 mismatch at idx %0d: EXP=%h, RTL=%h", p1_cnt, mem_pool1[p1_cnt*3 + 1], u_dut.u_pool1.out_2); 
                err_cnt = err_cnt + 1;
            end
            if (u_dut.u_pool1.out_3 !== mem_pool1[p1_cnt*3 + 2]) begin
                $display("[ERR] Pool1 Ch2 mismatch at idx %0d: EXP=%h, RTL=%h", p1_cnt, mem_pool1[p1_cnt*3 + 2], u_dut.u_pool1.out_3); 
                err_cnt = err_cnt + 1;
            end
            p1_cnt = p1_cnt + 1;
        end
    end

    // --- CHECK 3: Conv2 Output (u8x3) ---
    always @(posedge clk) begin
        if (u_dut.u_conv2.out_valid) begin
            if (u_dut.u_conv2.out_1 !== mem_conv2[c2_cnt*3 + 0]) begin
                $display("[ERR] Conv2 Ch0 mismatch at idx %0d: EXP=%h, RTL=%h", c2_cnt, mem_conv2[c2_cnt*3 + 0], u_dut.u_conv2.out_1); 
                err_cnt = err_cnt + 1;
            end
            if (u_dut.u_conv2.out_2 !== mem_conv2[c2_cnt*3 + 1]) begin
                $display("[ERR] Conv2 Ch1 mismatch at idx %0d: EXP=%h, RTL=%h", c2_cnt, mem_conv2[c2_cnt*3 + 1], u_dut.u_conv2.out_2); 
                err_cnt = err_cnt + 1;
            end
            if (u_dut.u_conv2.out_3 !== mem_conv2[c2_cnt*3 + 2]) begin
                $display("[ERR] Conv2 Ch2 mismatch at idx %0d: EXP=%h, RTL=%h", c2_cnt, mem_conv2[c2_cnt*3 + 2], u_dut.u_conv2.out_3); 
                err_cnt = err_cnt + 1;
            end
            c2_cnt = c2_cnt + 1;
        end
    end

    // --- CHECK 4: Pool2 Output (u8x3) ---
    always @(posedge clk) begin
        if (u_dut.u_pool2.out_valid) begin
            if (u_dut.u_pool2.out_1 !== mem_pool2[p2_cnt*3 + 0]) begin
                $display("[ERR] Pool2 Ch0 mismatch at idx %0d: EXP=%h, RTL=%h", p2_cnt, mem_pool2[p2_cnt*3 + 0], u_dut.u_pool2.out_1); 
                err_cnt = err_cnt + 1;
            end
            if (u_dut.u_pool2.out_2 !== mem_pool2[p2_cnt*3 + 1]) begin
                $display("[ERR] Pool2 Ch1 mismatch at idx %0d: EXP=%h, RTL=%h", p2_cnt, mem_pool2[p2_cnt*3 + 1], u_dut.u_pool2.out_2); 
                err_cnt = err_cnt + 1;
            end
            if (u_dut.u_pool2.out_3 !== mem_pool2[p2_cnt*3 + 2]) begin
                $display("[ERR] Pool2 Ch2 mismatch at idx %0d: EXP=%h, RTL=%h", p2_cnt, mem_pool2[p2_cnt*3 + 2], u_dut.u_pool2.out_3); 
                err_cnt = err_cnt + 1;
            end
            p2_cnt = p2_cnt + 1;
        end
    end

    // --- CHECK 5: FC Logits (Signed 32-bit) ---
    // FC 모듈 출력 시점 확인: u_fc.out_valid가 High일 때 out_logit 비교
    always @(posedge clk) begin
        if (u_dut.u_fc.out_valid) begin
            // !== 연산자는 Verilog에서도 지원함 (x, z 포함 비교)
            if (u_dut.u_fc.out_logit !== mem_fc[fc_cnt]) begin
                $display("[ERR] FC Logit mismatch at Class %0d: EXP=%h, RTL=%h", 
                         fc_cnt, mem_fc[fc_cnt], u_dut.u_fc.out_logit);
                err_cnt = err_cnt + 1;
            end
            fc_cnt = fc_cnt + 1;
        end
    end

    // --- CHECK 6: Final Decision ---
    always @(posedge clk) begin
        if (out_valid) begin
            if (decision !== mem_pred[0][3:0]) begin
                $display("[ERR] Final Prediction Mismatch! EXP=%d, RTL=%d", 
                         mem_pred[0], decision);
                err_cnt = err_cnt + 1;
            end else begin
                $display("[INFO] Final Prediction Match! Result = %d", decision);
            end
        end
    end

endmodule