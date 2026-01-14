
Notion 상세정리 링크  
https://flashy-gopher-3c9.notion.site/2d752e88024880a48a2dd4b3bd12fbf4?v=2e052e88024880b295c7000cbebb5abf&source=copy_link

  
최종발표 10pages  

https://drive.google.com/file/d/1fBy-vvCl_1QFjW2AxEF9NvWb8tMRffSt/view?usp=sharing  
<br>  

최종발표 full_version   
https://drive.google.com/file/d/1pjBEg47TnHvpPdYen-JNLnrxzmVLRcXq/view?usp=sharing
# FPGA End-to-End CNN Inference Accelerator

> FPGA 상에서 카메라 입력부터 CNN 추론 결과 출력까지  
> End-to-End로 동작하는 **Shift-only 정수 기반 CNN 추론 가속기**를  
> RTL로 설계·구현·검증한 프로젝트입니다.

---

## 1. Project Overview

본 프로젝트는 **FPGA 환경에서 실시간 입력을 처리할 수 있는 CNN 추론 가속기**를  
RTL 수준에서 설계하고, 소프트웨어 참조 모델과의 **정확한 검증(bit-exact)**까지 수행하는 것을 목표로 합니다.

카메라 입력 → 프레임 버퍼 → CNN Core → 결과 출력으로 이어지는  
전체 데이터 흐름을 하나의 시스템으로 통합했으며,  
**시스템 클럭 125 MHz 환경에서 프레임 드랍 없이 안정적으로 동작**하도록 설계했습니다.

---

## 2. System Architecture

![System Architecture](./images/system_architecture.png)

전체 시스템은 RTL 기준의 데이터 흐름에 맞춰 다음과 같이 구성되어 있습니다.

- Camera Input
- Frame Buffer
- CNN Core (Conv / Pool / FC)
- Result Output

각 블록은 스트리밍 기반으로 연결되어 있으며,  
CNN 추론 중에도 입력 프레임이 연속적으로 처리될 수 있도록 설계했습니다.

---

## 3. Key Design Decisions

### 1) Shift-only Quantization 규칙 정의

기존 PTQ(Post-Training Quantization) 방식도 구현 가능했으나,  
**RTL 구현 복잡도와 검증 부담을 줄이기 위해**  
곱셈 기반 스케일링을 제거한 **Shift-only 고정소수점 연산 규칙**을 독자적으로 정의했습니다.

- Activation: `uint8 (Q0.8)`
- Weight: `int8 (Q1.7)`
- Accumulation: `int32`
- Requantization: `(acc + round) >> shift + clamp`

CNN Core 단위 비교 결과,
자원 사용량, 전력 소모, 추론 지연 시간, SW–HW 결과 일치 측면에서  
기존 PTQ 기반 구현 대비 **전반적으로 우수한 특성**을 확인했고,  
이를 전체 시스템 구현 방식으로 채택했습니다.

---

### 2) CNN Core RTL 중심 설계

개별 연산 블록 최적화가 아닌,  
**CNN 추론 전체 흐름이 RTL 관점에서 자연스럽게 이어지도록** Core 구조를 설계했습니다.

- Line Buffer 기반 Convolution 구조
- Pooling 및 Fully Connected 포함 End-to-End Core
- 125 MHz 동작을 고려한 파이프라인 및 타이밍 설계

---

### 3) End-to-End 시스템 통합

CNN Core 단독 검증에 그치지 않고,  
카메라 입력부터 추론 결과 출력까지를 하나의 시스템으로 통합했습니다.

이를 통해 실제 입력 환경에서도  
**프레임 드랍 없이 연속적인 추론이 가능함을 확인**했습니다.

---

## 4. Verification & Results

### ✔ Bit-exact Verification

![Bit-exact Verification](./images/bit_exact.png)

- Python 정수 reference 모델과 RTL 시뮬레이션 결과 간  
  **100% bit-exact 일치 검증**
- Shift / Round / Clamp 규칙을 SW–HW 간 동일하게 유지

---

### ✔ Performance Comparison

![Performance Comparison](./images/performance.png)

- ARM Cortex-A9 CPU 대비 FPGA 기반 CNN 추론 성능 비교
- 낮은 전력 소모로 안정적인 추론 성능 확보

---

## 5. Hardware Implementation Summary

- **Target Board:** Digilent Zybo Z7-20 (XC7Z020)
- **Clock Frequency:** 125 MHz
- **Resource Utilization (Post-Implementation)**
  - LUT: 약 27%
  - FF: 약 9%
  - DSP: 0 (0%)
- **Total On-Chip Power:** 0.3W 미만

---

## 6. Repository Structure
.
├── cnn_python_final/        # Python 학습모델 코드 및 가중치 export, golden data export, ...
├── sources/                 # Verilog RTL 소스 (CNN Core 하위모듈들 & OV7670 카메라 모듈)
├── sim_1/                   # Testbench 및 시뮬레이션 환경
├── constrs_1/               # FPGA 제약 파일 (XDC)
├── README.md


