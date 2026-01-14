import os
import numpy as np
import tensorflow as tf

# =============================================================================
# [FPGA 대규모 검증용 데이터 생성기]
#
# 목적: MNIST Testset 중 앞선 1,000장을 추출하여
#       RTL 시뮬레이션용 연속 입력 파일 생성
# =============================================================================

# 경로 설정
BASE = os.getcwd()
OUT_DIR = os.path.join(BASE, "export", "golden_data")
os.makedirs(OUT_DIR, exist_ok=True)

# MNIST 로드 (Test set)
(_, _), (x_test_u8, y_test) = tf.keras.datasets.mnist.load_data()

# 1,000장만 선택
N_TEST = 1000
x_sel = x_test_u8[:N_TEST]  # (1000, 28, 28)
y_sel = y_test[:N_TEST]     # (1000,)

print(f"=== {N_TEST}장 데이터 생성 시작 ===")

# ---------------------------------------------------------
# 1. 입력 데이터 병합 (input_1k.txt)
#    - 구조: 이미지 0(784줄) -> 이미지 1(784줄) ... 순서대로 쭉 이어서 저장
# ---------------------------------------------------------
input_file = os.path.join(OUT_DIR, "input_1k.txt")
print(f"Generating inputs: {input_file} ...")

with open(input_file, "w") as f:
    for i in range(N_TEST):
        # (28, 28) -> (784,)
        flat_img = x_sel[i].flatten()
        for pixel in flat_img:
            f.write(f"{pixel:02X}\n")

# ---------------------------------------------------------
# 2. 정답 라벨 저장 (label_1k.txt)
# ---------------------------------------------------------
label_file = os.path.join(OUT_DIR, "label_1k.txt")
print(f"Generating labels: {label_file} ...")

with open(label_file, "w") as f:
    for label in y_sel:
        f.write(f"{label}\n")

print("\n=== 생성 완료 ===")
print(f"Input Lines: {N_TEST * 784}")
print(f"Label Lines: {N_TEST}")