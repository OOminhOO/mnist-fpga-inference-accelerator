# infer_shift_only_int_stats.py
import os
import time
import numpy as np
import tensorflow as tf

# =============================================================================
# [정수-only / Shift-only] FPGA 검증 + "포화/클램프" 통계 출력 전용 스크립트
#
# ✅ 기존 infer_shift_only_int.py는 건드리지 말고,
#    이 파일 하나만 새로 만들어서 돌리면 됨.
#
# ====== 세계관 ======
# activation: u8 (Q0.8)  real = u8/256
# weight    : i8 (Q1.7)  real = i8/128
#
# Conv:
#   acc = Σ(u8 * i8)                      (signed int32 누산)
#   tmp = round(acc/128)                  (shift-only)
#       = (acc + 64) >> 7                 (rounding)
#   out_u8 = clamp(tmp)                   (ReLU + clamp 0..255)
#
# Dense:
#   acc = Σ(u8 * i8)                      (signed int32)
#   logits_q15 = acc + bd_q15             (bd_q15 = round(bias_float*32768))
#   argmax(logits_q15)
#
# ====== 이 파일의 목적(통계) ======
# 1) "진짜 상단 포화" 비율: tmp > 255  (hi_clamp)
# 2) "ReLU로 0" 비율      : tmp < 0    (relu0)
# 3) 각 레이어 출력 배열에서 값==0, 값==255 비율
#    (주의: 값==255는 hi_clamp 때문일 수도 있고, 원래 255가 나온 것일 수도 있음.
#     그래서 hi_clamp/tmp 통계를 같이 보는 게 핵심)
# =============================================================================


# ----------------------------
# 0) 경로 (PC마다 작업폴더 달라도 안 깨지게)
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

print("[INFO] Loaded NPZ:", NPZ)
print("  W1:", W1.shape, W1.dtype, " W2:", W2.shape, W2.dtype)
print("  Wd:", Wd.shape, Wd.dtype, " bd_q15:", bd_q15.shape, bd_q15.dtype)


# ----------------------------
# 1) MNIST u8 로드
# ----------------------------
mnist = tf.keras.datasets.mnist
(_, _), (x_test_u8, y_test) = mnist.load_data()

x_test_u8 = x_test_u8.astype(np.uint8)   # (10000,28,28)
y_test = y_test.astype(np.int32)

print("[INFO] MNIST test:", x_test_u8.shape, x_test_u8.dtype)


# ----------------------------
# 2) 통계 컨테이너
# ----------------------------
# sat_stats: "requant 직전 tmp" 기준 통계
# - total   : requant 수행 횟수(= 출력 픽셀 개수)
# - relu0   : tmp < 0  → ReLU로 0이 된 비율
# - hi_clamp: tmp > 255 → 상단 clamp로 255가 된 비율(진짜 정보 손실)
sat_stats = {
    "c1": {"total": 0, "relu0": 0, "hi_clamp": 0},
    "c2": {"total": 0, "relu0": 0, "hi_clamp": 0},
}

# out_stats: 실제 u8 출력 배열 값 분포 통계(0/255 비율)
out_stats = {
    "c1": {"n": 0, "z": 0, "m255": 0},
    "p1": {"n": 0, "z": 0, "m255": 0},
    "c2": {"n": 0, "z": 0, "m255": 0},
    "p2": {"n": 0, "z": 0, "m255": 0},
}

def update_out_stats(tag: str, a_u8: np.ndarray):
    """u8 배열에서 0/255 비율 누적"""
    n = int(a_u8.size)
    out_stats[tag]["n"] += n
    out_stats[tag]["z"] += int(np.count_nonzero(a_u8 == 0))
    out_stats[tag]["m255"] += int(np.count_nonzero(a_u8 == 255))


# ----------------------------
# 3) clamp / requant 유틸
# ----------------------------
def clamp_u8(v: int) -> int:
    # ReLU 포함: 음수면 0
    if v < 0:
        return 0
    if v > 255:
        return 255
    return v

def requant_shift7(acc: int, tag: str) -> int:
    """
    out_u8 = clamp( round(acc/128) )
          = clamp( (acc + 64) >> 7 )
    - tag: "c1" / "c2" 통계용
    """
    tmp = (acc + 64) >> 7  # clamp 적용 전 "진짜 값"

    # ---- 통계 누적 (tmp 기준) ----
    sat_stats[tag]["total"] += 1
    if tmp < 0:
        sat_stats[tag]["relu0"] += 1
    elif tmp > 255:
        sat_stats[tag]["hi_clamp"] += 1

    # ---- clamp 적용 ----
    return clamp_u8(tmp)


# ----------------------------
# 4) Conv / Pool / Dense (RTL처럼 "기본 for-loop"로 작성)
# ----------------------------
def conv5x5_valid_u8_i8_to_u8(x_u8_hw_c: np.ndarray, W_i8: np.ndarray, tag: str) -> np.ndarray:
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
                acc = 0  # signed int32 누산

                # 5x5xCin MAC
                for ky in range(5):
                    for kx in range(5):
                        for ic in range(Cin):
                            a = int(x_u8_hw_c[oy + ky, ox + kx, ic])  # 0..255
                            w = int(W_i8[ky, kx, ic, oc])             # -128..127
                            acc += a * w

                out[oy, ox, oc] = np.uint8(requant_shift7(acc, tag))

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
# 5) 전체 추론 (RTL 데이터 흐름 그대로) + 통계 누적
# ----------------------------
def infer_one_with_stats(img_u8_28x28: np.ndarray) -> int:
    # 입력 (28,28) u8 -> (28,28,1)
    a0 = img_u8_28x28.reshape(28, 28, 1)

    # conv1 -> u8
    c1 = conv5x5_valid_u8_i8_to_u8(a0, W1, "c1")  # (24,24,3)
    update_out_stats("c1", c1)

    # pool1 -> u8
    p1 = maxpool2x2_u8(c1)                        # (12,12,3)
    update_out_stats("p1", p1)

    # conv2 -> u8
    c2 = conv5x5_valid_u8_i8_to_u8(p1, W2, "c2")  # (8,8,3)
    update_out_stats("c2", c2)

    # pool2 -> u8
    p2 = maxpool2x2_u8(c2)                        # (4,4,3)
    update_out_stats("p2", p2)

    # flatten
    flat = p2.reshape(48)

    # dense logits(q15) -> argmax
    logits = dense_u8_i8_logits_q15(flat, Wd, bd_q15)
    return int(np.argmax(logits))


# ----------------------------
# 6) 정확도 + 통계 출력
# ----------------------------
# 너무 느리면 200~1000 정도로 먼저 찍고,
# 값 괜찮으면 10000으로 늘려서 최종 확인해도 됨.
N_TEST = 1000     # <-- 여기 조절
PRINT_EVERY = 100

correct = 0
t0 = time.time()

for i in range(N_TEST):
    pred = infer_one_with_stats(x_test_u8[i])
    if pred == int(y_test[i]):
        correct += 1

    if (i + 1) % PRINT_EVERY == 0:
        print(f"[{i+1}/{N_TEST}] acc_so_far={correct/(i+1):.4f}")

acc = correct / N_TEST
elapsed = time.time() - t0

print("\n================ RESULT ================")
print(f"[SHIFT-ONLY INT + STATS] acc={acc:.4f} (N={N_TEST})")
print(f"elapsed = {elapsed:.1f} sec")
print("========================================\n")

# ---- tmp 기준(진짜 clamp) 통계 ----
print("========== SAT / CLAMP STATS (tmp 기준) ==========")
for k in ["c1", "c2"]:
    tot = sat_stats[k]["total"]
    if tot == 0:
        print(f"[{k}] total=0 (no data)")
        continue

    relu0 = sat_stats[k]["relu0"] / tot * 100.0
    hic  = sat_stats[k]["hi_clamp"] / tot * 100.0

    print(f"[{k}] total={tot}")
    print(f"  - relu0   (tmp < 0  → 0)    : {relu0:.2f}%")
    print(f"  - hi_clamp(tmp > 255 → 255) : {hic:.2f}%")

print("==================================================\n")

# ---- 출력 u8 배열 값 분포 통계 ----
print("========== OUTPUT VALUE STATS (u8 배열에서 값==0/255) ==========")
for k in ["c1", "p1", "c2", "p2"]:
    n = out_stats[k]["n"]
    if n == 0:
        print(f"[{k}] n=0 (no data)")
        continue

    z = out_stats[k]["z"] / n * 100.0
    m255 = out_stats[k]["m255"] / n * 100.0

    print(f"[{k}] n={n}")
    print(f"  - value==0   : {z:.2f}%")
    print(f"  - value==255 : {m255:.2f}%")

print("================================================================\n")

# ---- 해석 가이드(짧게) ----
print("[HOW TO READ]")
print("  1) c1/c2의 hi_clamp(tmp>255)가 높으면: '상단 포화로 정보가 잘림' 가능성 ↑")
print("  2) value==255 비율이 높아도, hi_clamp가 낮으면: '원래 255가 나온' 케이스일 수 있음")
print("  3) 판단은 hi_clamp를 우선으로 봐라. (그게 진짜 포화/손실)")
