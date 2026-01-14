# infer_shift_only_int.py
import os
import time
import numpy as np
import tensorflow as tf

# =============================================================================
# [정수-only / Shift-only] FPGA 검증 스크립트
#
# ====== 세계관 ======
# activation: u8 (Q0.8)  real = u8/256
# weight    : i8 (Q1.7)  real = i8/128
#
# Conv:
#   acc = Σ(u8 * i8)                      (signed int32 누산)
#   out_u8 = clamp( round(acc/128) )      (ReLU + clamp 0..255 포함)
#         = clamp( (acc + 64) >> 7 )
#
# Dense:
#   acc = Σ(u8 * i8)                      (signed int32)
#   logits_q15 = acc + bd_q15             (bd_q15 = round(bias_float*32768))
#   argmax(logits_q15)
# =============================================================================

# ----------------------------
# 0) 경로 (동료 PC에서 작업폴더 달라도 안 깨지게)
# ----------------------------
try:
    BASE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    BASE = os.getcwd()

NPZ = os.path.join(BASE, "export", "mnist_shift_only_fpga_export.npz")
if not os.path.exists(NPZ):
    raise FileNotFoundError(f"[ERROR] npz not found: {NPZ}")

pack = np.load(NPZ)
W1 = pack["W1_q"].astype(np.int8)         # (5,5,1,3)
W2 = pack["W2_q"].astype(np.int8)         # (5,5,3,3)
Wd = pack["Wd_q"].astype(np.int8)         # (48,10)
bd_q15 = pack["bd_q15"].astype(np.int32)  # (10,)

# ----------------------------
# 1) MNIST u8 로드
# ----------------------------
mnist = tf.keras.datasets.mnist
(_, _), (x_test_u8, y_test) = mnist.load_data()

x_test_u8 = x_test_u8.astype(np.uint8)   # (10000,28,28)
y_test = y_test.astype(np.int32)

# ----------------------------
# 2) clamp / requant 유틸
# ----------------------------
def clamp_u8(v: int) -> int:
    # ReLU 포함: 음수면 0
    if v < 0:
        return 0
    if v > 255:
        return 255
    return v

def requant_shift7(acc: int) -> int:
    """
    out_u8 = clamp( round(acc/128) )
          = clamp( (acc + 64) >> 7 )
    - acc는 signed 값
    - 여기서는 ReLU를 clamp_u8에서 처리
    """
    tmp = (acc + 64) >> 7
    return clamp_u8(tmp)

# ----------------------------
# 3) Conv / Pool / Dense (RTL처럼 "기본 for-loop"로 작성)
# ----------------------------
def conv5x5_valid_u8_i8_to_u8(x_u8_hw_c: np.ndarray, W_i8: np.ndarray) -> np.ndarray:
    """
    x: (H,W,Cin)  uint8
    W: (5,5,Cin,Cout) int8
    out: (H-4, W-4, Cout) uint8
    """
    H, Ww, Cin = x_u8_hw_c.shape
    Kh, Kw, Cin2, Cout = W_i8.shape
    assert (Kh, Kw) == (5, 5)
    assert Cin == Cin2

    Hout, Wout = H - 4, Ww - 4
    out = np.zeros((Hout, Wout, Cout), dtype=np.uint8)

    for oy in range(Hout):
        for ox in range(Wout):
            for oc in range(Cout):
                acc = 0  # signed 누산 (RTL에서는 signed[31:0])

                # 5x5xCin MAC
                for ky in range(5):
                    for kx in range(5):
                        for ic in range(Cin):
                            a = int(x_u8_hw_c[oy + ky, ox + kx, ic])  # 0..255
                            w = int(W_i8[ky, kx, ic, oc])             # -128..127
                            acc += a * w

                out[oy, ox, oc] = np.uint8(requant_shift7(acc))

    return out

def maxpool2x2_u8(x_u8_hw_c: np.ndarray) -> np.ndarray:
    """
    2x2 maxpool stride=2
    x: (H,W,C) uint8, H/W 짝수 가정
    """
    H, Ww, C = x_u8_hw_c.shape
    assert H % 2 == 0 and Ww % 2 == 0

    out = np.zeros((H // 2, Ww // 2, C), dtype=np.uint8)

    for oy in range(H // 2):
        for ox in range(Ww // 2):
            for c in range(C):
                m = int(x_u8_hw_c[2*oy,   2*ox,   c])
                v = int(x_u8_hw_c[2*oy,   2*ox+1, c]);  m = v if v > m else m
                v = int(x_u8_hw_c[2*oy+1, 2*ox,   c]);  m = v if v > m else m
                v = int(x_u8_hw_c[2*oy+1, 2*ox+1, c]);  m = v if v > m else m
                out[oy, ox, c] = np.uint8(m)

    return out

def dense_u8_i8_logits_q15(flat_u8_48: np.ndarray, Wd_i8: np.ndarray, bd_q15: np.ndarray) -> np.ndarray:
    """
    logits_q15[j] = Σ(flat_u8 * Wd_i8) + bd_q15[j]
    return: int32 (10,)
    """
    logits = np.zeros((10,), dtype=np.int32)

    for j in range(10):
        acc = 0
        for i in range(48):
            a = int(flat_u8_48[i])       # 0..255
            w = int(Wd_i8[i, j])         # -128..127
            acc += a * w

        logits[j] = np.int32(acc) + np.int32(bd_q15[j])

    return logits

# ----------------------------
# 4) 전체 추론 (RTL 데이터 흐름 그대로)
# ----------------------------
def infer_one(img_u8_28x28: np.ndarray) -> int:
    # 입력 (28,28) u8 -> (28,28,1)
    a0 = img_u8_28x28.reshape(28, 28, 1)

    # conv1 -> u8
    c1 = conv5x5_valid_u8_i8_to_u8(a0, W1)     # (24,24,3)
    p1 = maxpool2x2_u8(c1)                     # (12,12,3)

    # conv2 -> u8
    c2 = conv5x5_valid_u8_i8_to_u8(p1, W2)     # (8,8,3)
    p2 = maxpool2x2_u8(c2)                     # (4,4,3)

    # flatten
    flat = p2.reshape(48)

    # dense logits(q15) -> argmax
    logits = dense_u8_i8_logits_q15(flat, Wd, bd_q15)
    return int(np.argmax(logits))

# ----------------------------
# 5) 정확도 측정
# ----------------------------
N_TEST = 1000# 느리면 2000 등으로 줄여도 됨
correct = 0
t0 = time.time()

for i in range(N_TEST):
    pred = infer_one(x_test_u8[i])
    if pred == int(y_test[i]):
        correct += 1
    if (i + 1) % 100 == 0:
        print(f"[{i+1}/{N_TEST}] acc_so_far={correct/(i+1):.4f}")

acc = correct / N_TEST
print("\n================ RESULT ================")
print(f"[SHIFT-ONLY INT] acc={acc:.4f} (N={N_TEST})")
print(f"elapsed = {time.time()-t0:.1f} sec")
print("========================================")

