import numpy as np
import os
import urllib.request

def generate_verilog_rom():
    # ---------------------------------------------------------
    # 1. MNIST 데이터셋 직접 다운로드 (TensorFlow 없어도 됨)
    # ---------------------------------------------------------
    mnist_url = "https://storage.googleapis.com/tensorflow/tf-keras-datasets/mnist.npz"
    local_file = "mnist.npz"

    print(f"1. MNIST 데이터 다운로드 중... ({mnist_url})")
    
    try:
        if not os.path.exists(local_file):
            urllib.request.urlretrieve(mnist_url, local_file)
            print("   -> 다운로드 완료!")
        else:
            print("   -> 이미 파일이 있습니다. (Skip)")
            
        # 데이터 로드
        data = np.load(local_file)
        x_test = data['x_test'] # 원본은 소문자 x_test 입니다
        y_test = data['y_test']
        
    except Exception as e:
        print(f"\n[치명적 오류] 데이터를 가져오지 못했습니다: {e}")
        return

    # ---------------------------------------------------------
    # 2. 데이터 추출 (16장)
    # ---------------------------------------------------------
    # 스위치 4개(0~15)에 맞춰 16개만 뽑습니다.
    num_imgs = 16
    images = x_test[:num_imgs]
    labels = y_test[:num_imgs]
    
    print("\n---------------------------------------------------")
    print(f"★ 정답 라벨 (스위치 0000 ~ 1111 순서):")
    print(f"   {labels}")
    print("---------------------------------------------------\n")

    # ---------------------------------------------------------
    # 3. Verilog 파일 작성 (rom_16_images.v)
    # ---------------------------------------------------------
    print("2. Verilog 파일 생성 중...")
    
    with open("rom_16_images.v", "w") as f:
        f.write("module rom_16_images (\n")
        f.write("    input wire [3:0]  img_idx,   // 스위치 4개 (0~15)\n")
        f.write("    input wire [9:0]  pixel_idx, // 0~783 픽셀 위치\n")
        f.write("    output reg [7:0]  data_out   // 픽셀 값\n")
        f.write(");\n\n")
        f.write("    always @(*) begin\n")
        f.write("        case ({img_idx, pixel_idx})\n")
        
        for i in range(num_imgs):
            img = images[i].reshape(784)
            for p in range(784):
                val = int(img[p])
                # 0이 아닌 값만 기록 (파일 용량 최적화)
                if val > 10: # 노이즈 제거를 위해 10보다 큰 값만
                    addr = (i << 10) | p
                    f.write(f"            14'd{addr}: data_out = 8'h{val:02X};\n")
        
        f.write("            default: data_out = 8'h00;\n")
        f.write("        endcase\n")
        f.write("    end\n")
        f.write("endmodule\n")

    print("[완료] 'rom_16_images.v' 파일이 생성되었습니다!")
    print("-> Vivado 프로젝트에 이 파일을 Add Sources 하세요.")
    print("-> 콘솔에 출력된 [정답 라벨]을 꼭 적어두세요!")

if __name__ == "__main__":
    generate_verilog_rom()