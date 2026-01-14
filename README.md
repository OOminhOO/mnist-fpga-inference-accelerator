# mnist-fpga-inference-accelerator
# FPGA Shift-only CNN Accelerator for MNIST

Notion 상세정리 링크  
https://flashy-gopher-3c9.notion.site/2d752e88024880a48a2dd4b3bd12fbf4?v=2e052e88024880b295c7000cbebb5abf&source=copy_link

최종발표 full_version  

[링크수정_최종제출용_full version_CNN 추론 가속기 설계- 복사본.pdf](https://github.com/user-attachments/files/24612220/_._full.version_CNN.-.pdf)


## 📝 Project Overview
This project implements a lightweight CNN accelerator on Xilinx Zynq-7000 FPGA (Zybo Z7-20) for MNIST digit classification.
Unlike traditional implementations, this design uses a **Shift-only Arithmetic** approach to minimize DSP usage and power consumption, achieving efficient hardware inference.

## 🚀 Key Features
* **No DSP Usage:** All convolutions and dense layers are implemented using only Shift & Add operations.
* **Integer Quantization:**
    * Input/Activation: `uint8` (Q0.8 scale)
    * Weights: `int8` (Q1.7 scale)
    * Accumulation: `int32`
* **End-to-End Flow:**
    * **Python:** Custom quantization-aware training (TensorFlow) & Hex export.
    * **RTL:** Verilog implementation of Line Buffers, PE Arrays (10-way parallel FC), and Control Logic.
    * **Verification:** Bit-exact matching between Python Golden Vectors and RTL simulation.

## 🛠 Hardware Spec (Post-Implementation)
* **Target Board:** Digilent Zybo Z7-20 (XC7Z020)
* **Clock Frequency:** 125 MHz
* **Resource Utilization:**
    * LUT: ~27%
    * FF: ~9%
    * DSP: 0 (0%)
    * Power: < 0.3W (Total On-Chip Power)

## 📂 Repository Structure
* `design/`: Verilog source codes (Conv, Pool, FC, LineBuf, etc.)
* `sim/`: Testbenches and simulation scripts.
* `python/`:
    * `train_export_shift_only.py`: Training & quantization script.
    * `export_hex_for_fpga.py`: Generates .txt files for Verilog $readmemh.
    * `infer_int_only_shift.py`: Bit-exact Python inference model for verification.
* `constraints/`: XDC file for Zybo Z7.

## 📊 Verification Result
Passed 100% bit-exact verification against Python Golden Model.
