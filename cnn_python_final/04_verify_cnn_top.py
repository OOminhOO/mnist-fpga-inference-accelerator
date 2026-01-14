import os
import numpy as np

# =============================================================================
# [FPGA 최종 검증용 파이썬 스크립트]
# - 입력: input_image.txt (RTL 시뮬레이션에 쓴 것과 동일한 파일)
# - 모델: mnist_shift_only_fpga_export.npz (가중치 원본)
# - 출력: 각 클래스별 점수(Logit) 및 최종 예측값
# =============================================================================

def load_hex_image(filepath):
    """ input_image.txt (Hex string)을 읽어서 (28,28) uint8 배열로 변환 """
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # 빈 줄 제거 및 16진수 변환
    vals = [int(line.strip(), 16) for line in lines if line.strip()]
    
    if len(vals) != 784:
        raise ValueError(f"Image file size mismatch! Expected 784, got {len(vals)}")
        
    return np.array(vals, dtype=np.uint8).reshape(28, 28)

def clamp_u8(v):
    return max(0, min(255, v))

def requant_shift7(acc):
    """ (acc + 64) >> 7 """
    return clamp_u8((acc + 64) >> 7)

# ----------------------------
# 레이어 연산 함수 (RTL 동작과 100% 동일)
# ----------------------------
def conv5x5_valid(x, W):
    H, Ww, Cin = x.shape
    Kh, Kw, _, Cout = W.shape
    Hout, Wout = H - 4, Ww - 4
    out = np.zeros((Hout, Wout, Cout), dtype=np.uint8)

    for r in range(Hout):
        for c in range(Wout):
            for k in range(Cout):
                acc = 0
                for i in range(5):
                    for j in range(5):
                        for ch in range(Cin):
                            acc += int(x[r+i, c+j, ch]) * int(W[i, j, ch, k])
                out[r, c, k] = requant_shift7(acc)
    return out

def maxpool2x2(x):
    H, W, C = x.shape
    out = np.zeros((H//2, W//2, C), dtype=np.uint8)
    for r in range(H//2):
        for c in range(W//2):
            for k in range(C):
                patch = x[r*2:r*2+2, c*2:c*2+2, k]
                out[r, c, k] = np.max(patch)
    return out

def dense_fc(flat_x, Wd, bd):
    # Wd shape: (48, 10), bd shape: (10,)
    logits = np.zeros(10, dtype=np.int32)
    for cls in range(10):
        acc = 0
        for i in range(48):
            acc += int(flat_x[i]) * int(Wd[i, cls])
        logits[cls] = acc + int(bd[cls])
    return logits

# ----------------------------
# 메인 실행
# ----------------------------
def main():
    base_dir = os.getcwd()
    
    # 1. 파일 경로 설정
    npz_path = os.path.join(base_dir, "export", "mnist_shift_only_fpga_export.npz")
    # 수정 (우리가 만든 파일명에 맞춤)
    img_path = os.path.join(base_dir, "export", "golden_data", "input_img.txt")

    if not os.path.exists(npz_path):
        print(f"[Error] NPZ file not found: {npz_path}")
        return
    if not os.path.exists(img_path):
        print(f"[Error] Image file not found: {img_path}")
        print(" -> gen_maxpool2_golden.py 등을 실행해서 input_image.txt를 먼저 만드세요.")
        return

    # 2. 가중치 로드
    pack = np.load(npz_path)
    W1 = pack["W1_q"].astype(np.int8)
    W2 = pack["W2_q"].astype(np.int8)
    Wd = pack["Wd_q"].astype(np.int8)
    bd = pack["bd_q15"].astype(np.int32)

    # 3. 이미지 로드
    img_u8 = load_hex_image(img_path)
    print(f"Loaded input image from {img_path}")

    # 4. 추론 (Forward Pass)
    # [Input] (28, 28) -> (28, 28, 1)
    x = img_u8.reshape(28, 28, 1)

    # [Conv1]
    c1 = conv5x5_valid(x, W1)
    p1 = maxpool2x2(c1)
    
    # [Conv2]
    c2 = conv5x5_valid(p1, W2)
    p2 = maxpool2x2(c2)

    # [Flatten]
    flat = p2.flatten() # (48,)

    # [FC]
    logits = dense_fc(flat, Wd, bd)
    prediction = np.argmax(logits)

    # 5. 결과 출력
    print("\n" + "="*40)
    print(" [Python Verification Result]")
    print("="*40)
    for i, score in enumerate(logits):
        mark = " <--- WINNER" if i == prediction else ""
        print(f" Class {i}: Logit = {score:>10} {mark}")
    
    print("-" * 40)
    print(f" 🎯 Predicted Class: {prediction}")
    print("="*40)

if __name__ == "__main__":
    main()