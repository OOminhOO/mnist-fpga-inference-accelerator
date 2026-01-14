# export_hex_for_fpga.py
import os
import numpy as np

# =============================================================================
# [FPGA 검증용 가중치/바이어스 HEX 덤프 - 최종 수정본]
#
# 목적: Verilog $readmemh용 txt 파일 생성
# [수정 내역]
# 1. Conv2: (5,5,3) -> (3,5,5)로 Transpose 후 저장 (RTL이 채널별 블록 읽기 때문)
# 2. Dense: (48,10) 그대로 저장 (RTL 병렬 구조)
# =============================================================================

# 경로 설정
BASE = os.getcwd()
NPZ_PATH = os.path.join(BASE, "export", "mnist_shift_only_fpga_export.npz")
OUT_DIR = os.path.join(BASE, "export", "hex")

os.makedirs(OUT_DIR, exist_ok=True)

if not os.path.exists(NPZ_PATH):
    raise FileNotFoundError(f"파일을 찾을 수 없습니다: {NPZ_PATH}\n먼저 학습 코드를 실행해 npz를 생성해주세요.")

# 데이터 로드
pack = np.load(NPZ_PATH)
W1 = pack["W1_q"].astype(np.int8)          # (5, 5, 1, 3)
W2 = pack["W2_q"].astype(np.int8)          # (5, 5, 3, 3)
Wd = pack["Wd_q"].astype(np.int8)          # (48, 10)
bd = pack["bd_q15"].astype(np.int32)       # (10,)

print("=== 모델 데이터 로드 완료 ===")
print(f"W1 shape: {W1.shape}")
print(f"W2 shape: {W2.shape}")
print(f"Wd shape: {Wd.shape}")
print(f"bd shape: {bd.shape}")
print("==============================")

def to_hex_i8(val):
    return f"{val & 0xFF:02X}"

def to_hex_i32(val):
    return f"{val & 0xFFFFFFFF:08X}"

def save_txt(filename, data_list):
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w") as f:
        for val in data_list:
            f.write(f"{val}\n")
    print(f"Saved: {filename} (Lines: {len(data_list)})")

# ---------------------------------------------------------
# 1. Conv1 Weights Export
#    Input Ch=1이므로 Transpose 불필요
# ---------------------------------------------------------
print("\n--- Exporting Conv1 ---")
for out_c in range(3):
    kernel = W1[:, :, :, out_c] # (5, 5, 1)
    flat_data = kernel.flatten()
    hex_data = [to_hex_i8(x) for x in flat_data]
    save_txt(f"conv1_weight_{out_c+1}.txt", hex_data)

# ---------------------------------------------------------
# 2. Conv2 Weights Export [★핵심 수정★]
#    RTL: w_mem[0~24]=Ch1, w_mem[25~49]=Ch2, w_mem[50~74]=Ch3
#    Python Default: (Row, Col, Ch) -> Interleaved
#    Solution: Transpose (5,5,3) -> (3,5,5) to group by Channel
# ---------------------------------------------------------
print("\n--- Exporting Conv2 (Channel-First Grouping) ---")
for out_c in range(3):
    kernel = W2[:, :, :, out_c]  # Shape: (5, 5, 3)
    
    # (H, W, Cin) -> (Cin, H, W) 순서로 변경
    kernel_ch_first = kernel.transpose(2, 0, 1) # Shape: (3, 5, 5)
    
    flat_data = kernel_ch_first.flatten()
    hex_data = [to_hex_i8(x) for x in flat_data]
    save_txt(f"conv2_weight_{out_c+1}.txt", hex_data)

# ---------------------------------------------------------
# 3. Dense Weights Export
#    RTL 병렬 구조에 맞춰 (48, 10) 순서 유지
# ---------------------------------------------------------
print("\n--- Exporting Dense Weights ---")
flat_data = Wd.flatten() 
hex_data = [to_hex_i8(x) for x in flat_data]
save_txt("Wd.txt", hex_data)

# ---------------------------------------------------------
# 4. Dense Bias Export
# ---------------------------------------------------------
print("\n--- Exporting Dense Bias ---")
flat_data = bd.flatten()
hex_data = [to_hex_i32(x) for x in flat_data]
save_txt("bd.txt", hex_data)

print("\n=== 모든 파일 생성 완료 ===")
print(f"저장 위치: {OUT_DIR}")