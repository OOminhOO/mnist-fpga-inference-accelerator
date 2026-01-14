/*
 * ======================================================================================
 * 프로젝트 명 : Zynq-7000 PS CNN 벤치마크 (CPU Inference)
 * 파일 명     : main.c
 * 설명        : ARM Cortex-A9 CPU(Single Core)에서 CNN 모델의
 * 추론 속도(지연 시간 및 사이클)를 정밀 측정합니다.
 *
 * 타겟 보드   : Digilent Zybo Z7-20 (xc7z020)
 * 동작 클럭   : 667 MHz (기본 PS 클럭)
 * 작성일      : 2026.01.03
 * ======================================================================================
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xtime_l.h"    // 타이머 라이브러리 (Xilinx Timer)
#include "xil_cache.h"  // 캐시 제어 라이브러리
#include "model_data.h" // 가중치 및 입력 데이터 (Pre-trained)

// ==========================================
// [설정] 벤치마크 환경 설정
// ==========================================
#define LOOP_COUNT  100  // 100회 반복 실행하여 평균값을 산출합니다.

// ==========================================
// [버퍼] 메모리 할당 (Global Static)
// ==========================================
// 함수 내부(Stack)에 선언하면 스택 오버플로우(Stack Overflow)가 발생할 수 있으므로,
// 전역 변수(Data Section)로 선언하여 안전하게 메모리를 확보합니다.
static uint8_t c1_out[24 * 24 * 3];
static uint8_t p1_out[12 * 12 * 3];
static uint8_t c2_out[8 * 8 * 3];
static uint8_t p2_out[4 * 4 * 3];
static int32_t fc_out[10];

// ==========================================
// [유틸리티] 보조 함수
// ==========================================

// 값의 범위를 0~255로 제한 (Saturation 함수)
static inline int32_t clamp_u8(int32_t v) {
    if (v < 0) return 0;
    if (v > 255) return 255;
    return v;
}

// 하드웨어 동작을 모사한 양자화 및 시프트 연산
// (Shift-7 연산을 통해 부동소수점 없이 정수 연산 수행)
static inline uint8_t requant_shift7(int32_t acc) {
    return (uint8_t)clamp_u8((acc + 64) >> 7);
}

// ==========================================
// [커널] CNN 연산 함수 (Core Logic)
// ==========================================

// 1. 합성곱 계층 (Convolution 5x5)
void conv5x5(const uint8_t* in, const int8_t* w, uint8_t* out, int H, int W, int Cin, int Cout) {
    int H_out = H - 4;
    int W_out = W - 4;
    
    for (int r = 0; r < H_out; r++) {
        for (int c = 0; c < W_out; c++) {
            for (int k = 0; k < Cout; k++) {
                int32_t acc = 0;
                for (int i = 0; i < 5; i++) {
                    for (int j = 0; j < 5; j++) {
                        for (int ch = 0; ch < Cin; ch++) {
                            // 입력 인덱스 및 가중치 인덱스 계산
                            int in_idx = ((r + i) * W + (c + j)) * Cin + ch;
                            int w_idx = (i * 5 * Cin * Cout) + (j * Cin * Cout) + (ch * Cout) + k;
                            // 곱셈 누적 연산 (MAC)
                            acc += (int32_t)in[in_idx] * (int32_t)w[w_idx];
                        }
                    }
                }
                // 결과 저장 (Re-quantization 적용)
                out[(r * W_out + c) * Cout + k] = requant_shift7(acc);
            }
        }
    }
}

// 2. 맥스 풀링 계층 (Max Pooling 2x2)
void maxpool2x2(const uint8_t* in, uint8_t* out, int H, int W, int C) {
    int H_out = H / 2;
    int W_out = W / 2;

    for (int r = 0; r < H_out; r++) {
        for (int c = 0; c < W_out; c++) {
            for (int k = 0; k < C; k++) {
                uint8_t max_val = 0;
                for (int i = 0; i < 2; i++) {
                    for (int j = 0; j < 2; j++) {
                        int in_idx = ((r * 2 + i) * W + (c * 2 + j)) * C + k;
                        if (in[in_idx] > max_val) max_val = in[in_idx];
                    }
                }
                out[(r * W_out + c) * C + k] = max_val;
            }
        }
    }
}

// 3. 완전 연결 계층 (Dense / Fully Connected)
void dense(const uint8_t* in, const int8_t* w, const int32_t* b, int32_t* out, int In_Size, int Out_Size) {
    for (int o = 0; o < Out_Size; o++) {
        int32_t acc = 0;
        for (int i = 0; i < In_Size; i++) {
            int w_idx = i * Out_Size + o;
            acc += (int32_t)in[i] * (int32_t)w[w_idx];
        }
        out[o] = acc + b[o]; // 편향(Bias) 더하기
    }
}

// [래퍼 함수] 전체 추론 과정 1회 실행
void run_inference_sequence() {
    // Layer 1: Conv1 -> Pool1
    conv5x5(img_in, w1, c1_out, 28, 28, 1, 3);
    maxpool2x2(c1_out, p1_out, 24, 24, 3);

    // Layer 2: Conv2 -> Pool2
    conv5x5(p1_out, w2, c2_out, 12, 12, 3, 3);
    maxpool2x2(c2_out, p2_out, 8, 8, 3);

    // Layer 3: Dense (Output)
    dense(p2_out, wd, bd, fc_out, 48, 10);
}

// ==========================================
// [메인] 프로그램 진입점
// ==========================================
int main() {
    init_platform();

    // 1. 캐시 활성화 (성능 측정의 필수 조건)
    // 캐시를 끄면 CPU 성능이 수백 배 저하되므로 반드시 켜야 합니다.
    Xil_ICacheEnable();
    Xil_DCacheEnable();

    // 2. 워밍업 (Warm-up)
    // 첫 실행 시 발생하는 Cold Cache Miss 시간을 측정에서 제외하기 위함입니다.
    run_inference_sequence();

    // 3. 측정 시작
    XTime tStart, tEnd;
    XTime_GetTime(&tStart);

    for (int i = 0; i < LOOP_COUNT; i++) {
        run_inference_sequence();
    }

    // 4. 측정 종료
    XTime_GetTime(&tEnd);

    // 5. 결과 계산
    // Zynq-7000 Global Timer는 CPU 주파수의 1/2 속도로 동작합니다.
    long long total_timer_counts = tEnd - tStart;
    long long total_cpu_cycles   = total_timer_counts * 2;
    
    double total_time_us = (double)total_timer_counts / (double)COUNTS_PER_SECOND * 1000000.0;
    double cpu_freq_mhz  = (double)COUNTS_PER_SECOND * 2 / 1000000.0;
    
    // 평균값 산출
    double avg_time_us   = total_time_us / LOOP_COUNT;
    long long avg_cycles = total_cpu_cycles / LOOP_COUNT;

    // 6. 결과 리포트 출력 (PPT/논문용 포맷)
    printf("\033[2J\033[H"); // 터미널 화면 클리어
    printf("\n\r");
    printf("================================================\n\r");
    printf("   [ Benchmark Result: Zynq PS (Cortex-A9) ]    \n\r");
    printf("================================================\n\r");
    printf(" * CPU Frequency : %.2f MHz \n\r", cpu_freq_mhz);
    printf("------------------------------------------------\n\r");
    printf(" 1. Total (%d runs) \n\r", LOOP_COUNT);
    printf("   - Time Cost   : %.2f us \n\r", total_time_us);
    printf("   - CPU Cycles  : %llu cycles \n\r", total_cpu_cycles);
    printf("------------------------------------------------\n\r");
    printf(" 2. Average (Per 1 Inference) \n\r");
    printf("   - Time Cost   : %.2f us \n\r", avg_time_us);
    printf("   - CPU Cycles  : %llu cycles  <-- Check! \n\r", avg_cycles);
    printf("================================================\n\r");
    printf(" Benchmark Done.\n\r");

    cleanup_platform();
    return 0;
}
