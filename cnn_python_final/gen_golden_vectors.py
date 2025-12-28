import os
import numpy as np
import tensorflow as tf

# =============================================================================
# [FPGA 검증용 Golden Vector 생성기]
#
# 목적: RTL 시뮬레이션 결과와 비교할 "정답지" 생성
# 대상: MNIST Test set 중 첫 번째 이미지 (숫자 7)
# 흐름: Input -> Conv1 -> Pool1 -> Conv2 -> Pool2 -> Flatten -> FC -> Argmax
# =============================================================================

# 경로 설정
BASE = os.getcwd()
NPZ_PATH = os.path.join(BASE, "export", "mnist_shift_only_fpga_export.npz")
OUT_DIR = os.path.join(BASE, "export", "golden_data")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------
# 1. 가중치 및 데이터 로드
# ---------------------------------------------------------
if not os.path.exists(NPZ_PATH):
    raise FileNotFoundError(f"파일 없음: {NPZ_PATH}")

pack = np.load(NPZ_PATH)
W1 = pack["W1_q"].astype(np.int8)          # (5,5,1,3)
W2 = pack["W2_q"].astype(np.int8)          # (5,5,3,3)
Wd = pack["Wd_q"].astype(np.int8)          # (48,10)
bd_q15 = pack["bd_q15"].astype(np.int32)   # (10,)

# MNIST 로드 (Test set)
(_, _), (x_test_u8, y_test) = tf.keras.datasets.mnist.load_data()

# ★ 검증할 이미지 인덱스 선택 (0번: 숫자 7) ★
TEST_IDX = 0
input_img = x_test_u8[TEST_IDX].astype(np.uint8)  # (28, 28)
label_gold = y_test[TEST_IDX]

print(f"=== Golden Vector 생성 시작 (Index: {TEST_IDX}, Label: {label_gold}) ===")

# ---------------------------------------------------------
# 2. 연산 함수 정의 (FPGA 로직과 100% 동일한 '세계관')
# ---------------------------------------------------------
def clamp_u8(v):
    if v < 0: return 0
    if v > 255: return 255
    return v

def requant_shift7(acc):
    """ (acc + 64) >> 7 """
    return clamp_u8((acc + 64) >> 7)

def conv5x5_fpga(x_in, w_in):
    """
    x_in: (H, W, Cin)
    w_in: (5, 5, Cin, Cout)
    return: (H-4, W-4, Cout)
    """
    H, W_img, Cin = x_in.shape
    Kh, Kw, _, Cout = w_in.shape
    H_out, W_out = H - 4, W_img - 4
    
    out = np.zeros((H_out, W_out, Cout), dtype=np.uint8)
    
    for r in range(H_out):
        for c in range(W_out):
            for ch_out in range(Cout):
                acc = 0  # Signed 32-bit accumulator
                for kr in range(5):
                    for kc in range(5):
                        for ch_in in range(Cin):
                            # 입력 * 가중치
                            px = int(x_in[r+kr, c+kc, ch_in])
                            wt = int(w_in[kr, kc, ch_in, ch_out])
                            acc += px * wt
                # 결과 Requant (ReLU 포함)
                out[r, c, ch_out] = requant_shift7(acc)
    return out

def maxpool2x2_fpga(x_in):
    """
    x_in: (H, W, C)
    return: (H/2, W/2, C)
    """
    H, W_img, C = x_in.shape
    H_out, W_out = H // 2, W_img // 2
    out = np.zeros((H_out, W_out, C), dtype=np.uint8)
    
    for r in range(H_out):
        for c in range(W_out):
            for ch in range(C):
                v0 = int(x_in[2*r,   2*c,   ch])
                v1 = int(x_in[2*r,   2*c+1, ch])
                v2 = int(x_in[2*r+1, 2*c,   ch])
                v3 = int(x_in[2*r+1, 2*c+1, ch])
                out[r, c, ch] = max(v0, v1, v2, v3)
    return out

def dense_fpga(flat_in, w_d, b_d):
    """
    flat_in: (48,)
    w_d: (48, 10)
    b_d: (10,)
    return: (10,) int32
    """
    logits = np.zeros(10, dtype=np.int32)
    for o in range(10):
        acc = 0
        for i in range(48):
            px = int(flat_in[i])
            wt = int(w_d[i, o])
            acc += px * wt
        # Bias Add (Bias는 이미 Q15 스케일로 맞춰져 있음)
        logits[o] = acc + int(b_d[o])
    return logits

# ---------------------------------------------------------
# 3. 단계별 추론 및 저장
# ---------------------------------------------------------
# (1) 입력 저장 (Input Image)
# ----------------------------
# Reshape to (28, 28, 1)
img_in = input_img.reshape(28, 28, 1)

def save_hex(name, data, width_bits=8):
    path = os.path.join(OUT_DIR, name)
    data_flat = data.flatten()
    with open(path, "w") as f:
        for val in data_flat:
            if width_bits == 8:
                f.write(f"{int(val) & 0xFF:02X}\n")
            elif width_bits == 32:
                f.write(f"{int(val) & 0xFFFFFFFF:08X}\n")
    print(f"[{name}] Saved. Shape: {data.shape}")

save_hex("input_img.txt", img_in)

# (2) Conv1 -> u8
# ----------------------------
conv1_out = conv5x5_fpga(img_in, W1)  # (24, 24, 3)
save_hex("conv1_out.txt", conv1_out)

# (3) Pool1 -> u8
# ----------------------------
pool1_out = maxpool2x2_fpga(conv1_out) # (12, 12, 3)
save_hex("pool1_out.txt", pool1_out)

# (4) Conv2 -> u8
# ----------------------------
conv2_out = conv5x5_fpga(pool1_out, W2) # (8, 8, 3)
save_hex("conv2_out.txt", conv2_out)

# (5) Pool2 -> u8
# ----------------------------
pool2_out = maxpool2x2_fpga(conv2_out) # (4, 4, 3)
save_hex("pool2_out.txt", pool2_out)

# (6) Flatten & Dense -> int32 (Logits)
# ----------------------------
flat = pool2_out.flatten() # (48,)
fc_out = dense_fpga(flat, Wd, bd_q15) # (10,)
save_hex("fc_out.txt", fc_out, width_bits=32)

# (7) Comparator (Argmax)
# ----------------------------
pred = np.argmax(fc_out)
with open(os.path.join(OUT_DIR, "final_pred.txt"), "w") as f:
    f.write(f"{pred}\n")

print("\n------------------------------------------------")
print(f"Golden Vector 생성 완료: {OUT_DIR}")
print(f"FPGA 예상 결과(Pred): {pred} (정답: {label_gold})")
print("------------------------------------------------")
print("FC Logits (10진수 확인용):")
print(fc_out)