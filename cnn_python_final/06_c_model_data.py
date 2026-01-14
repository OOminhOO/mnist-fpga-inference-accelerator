 # gen_header_for_vitis.py
import numpy as np
import os

# 데이터 로드 (경로 확인 필수!)
pack = np.load("export/mnist_shift_only_fpga_export.npz")
W1 = pack["W1_q"].astype(np.int8).flatten()
W2 = pack["W2_q"].astype(np.int8).flatten()
Wd = pack["Wd_q"].astype(np.int8).flatten()
bd = pack["bd_q15"].astype(np.int32).flatten()

# 검증용 이미지 1장 로드
with open("export/golden_data/input_img.txt", "r") as f:
    lines = f.readlines()
img_data = [int(x.strip(), 16) for x in lines]

def write_array(f, name, data, dtype):
    f.write(f"const {dtype} {name}[{len(data)}] = {{\n")
    for i, val in enumerate(data):
        f.write(f"{val}, ")
        if (i+1) % 16 == 0: f.write("\n")
    f.write("};\n\n")

with open("model_data.h", "w") as f:
    f.write("#ifndef MODEL_DATA_H\n#define MODEL_DATA_H\n\n")
    f.write("#include <stdint.h>\n\n")
    
    write_array(f, "img_in", img_data, "uint8_t")
    write_array(f, "w1", W1, "int8_t")
    write_array(f, "w2", W2, "int8_t")
    write_array(f, "wd", Wd, "int8_t")
    write_array(f, "bd", bd, "int32_t")
    
    f.write("#endif\n")

print("model_data.h 생성 완료! 내용을 복사해서 Vitis에 붙여넣으세요.")
