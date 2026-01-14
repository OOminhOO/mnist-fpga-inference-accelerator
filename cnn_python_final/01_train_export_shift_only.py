# train_export_shift_only.py
import os
import numpy as np
import tensorflow as tf

# =============================================================================
# [목표: FPGA와 1:1로 맞는 "Shift-only" CNN 학습 + Export]
#
# ====== 세계관(스케일) 정의 ======
# 1) activation(중간 feature)은 항상 u8로 저장한다고 가정
#    - u8 의미: Q0.8
#    - real = u8 / 256
#
# 2) weight는 항상 int8로 저장한다고 가정
#    - int8 의미: Q1.7
#    - real = i8 / 128
#
# 3) Conv 누산(정수 관점)
#    - FPGA에서는 acc = Σ(u8 * i8) (signed int32 누산)
#    - real로 보면 acc_real = acc / (256*128) = acc / 32768
#
# 4) Conv output을 다시 u8(Q0.8)로 만들기(=rescale / requant)
#    - out_u8 = round(acc_real * 256) = round(acc / 128)
#    - => out_u8 = (acc + 64) >> 7   (rounding)
#    - 그리고 ReLU+clamp(0..255)
#
# 5) Dense
#    - acc = Σ(u8 * i8)  (signed int32)
#    - bias는 float로 학습되지만, FPGA에서 더하려면 같은 "정수 도메인"으로 저장해야 함
#      acc는 real 기준으로 1/32768 단위(Q15)로 볼 수 있음
#      => bias_q15 = round(bias_float * 32768)
#
# ====== 핵심 포인트 ======
# - 그냥 FP32로 학습하고 마지막에 >>7만 하면 정확도 망가질 수 있음
# - 그래서 학습 forward 중간중간 "fake-quant(라운딩+클리핑)"를 걸어
#   네트워크가 이 정수 세계관에 적응하게 만든다 (STE 사용)
#
# ====== 추가(최소 변경) ======
# - epoch <= 200에서 validation 기준으로 "최선 epoch" 자동 선택
#   * EarlyStopping(restore_best_weights=True)
#   * ReduceLROnPlateau(선택, 수렴 안정화)
# =============================================================================

# ----------------------------
# 0) 재현성(대충 고정)
# ----------------------------
SEED = 0
tf.keras.utils.set_random_seed(SEED)
np.random.seed(SEED)

# ----------------------------
# 1) MNIST 로드 (입력은 /256 세계관)
#    - FPGA: pixel u8(0..255)
#    - 학습: float지만 의미는 u8/256
# ----------------------------
mnist = tf.keras.datasets.mnist
(x_train_u8, y_train), (x_test_u8, y_test) = mnist.load_data()

x_train = (x_train_u8.astype(np.float32) / 256.0)[..., None]  # (N,28,28,1)
x_test  = (x_test_u8.astype(np.float32)  / 256.0)[..., None]

y_train = y_train.astype(np.int32)
y_test  = y_test.astype(np.int32)

# ----------------------------
# 2) STE(학습용 라운딩)
#    - forward: round
#    - backward: gradient는 identity로 흘림
# ----------------------------
def ste_round(x: tf.Tensor) -> tf.Tensor:
    return x + tf.stop_gradient(tf.round(x) - x)

def fake_quant_u8_q08(x: tf.Tensor) -> tf.Tensor:
    """
    activation을 u8(Q0.8) 격자에 '강제'하는 함수
      - real -> u8: u8 = round(real*256)
      - clamp 0..255
      - 다시 real로: u8/256
    """
    # ReLU 가정(음수는 0으로)
    x = tf.maximum(x, 0.0)

    q = ste_round(x * 256.0)           # u8 grid로 스냅
    q = tf.clip_by_value(q, 0.0, 255.0)
    return q / 256.0                   # 다시 real로(격자는 Q0.8)

def fake_quant_i8_q17(w: tf.Tensor) -> tf.Tensor:
    """
    weight를 int8(Q1.7) 격자에 '강제'
      - real -> i8: i8 = round(real*128)
      - clamp -128..127
      - 다시 real로: i8/128
    """
    q = ste_round(w * 128.0)
    q = tf.clip_by_value(q, -128.0, 127.0)
    return q / 128.0

# ----------------------------
# 3) QuantConv2D / QuantDense
#    - 내부 파라미터는 float로 학습
#    - forward에서만 fake-quant로 "정수 세계관"을 흉내냄
# ----------------------------
class QuantConv2D(tf.keras.layers.Layer):
    def __init__(self, filters, kernel_size, use_bias=False, name=None):
        super().__init__(name=name)
        self.filters = int(filters)
        self.kernel_size = tuple(kernel_size)
        self.use_bias = bool(use_bias)

    def build(self, input_shape):
        kh, kw = self.kernel_size
        cin = int(input_shape[-1])

        self.w = self.add_weight(
            name="kernel",
            shape=(kh, kw, cin, self.filters),
            initializer="glorot_uniform",
            trainable=True
        )
        if self.use_bias:
            self.b = self.add_weight(
                name="bias",
                shape=(self.filters,),
                initializer="zeros",
                trainable=True
            )
        else:
            self.b = None

    def call(self, x):
        # 입력 activation을 u8(Q0.8) 격자에 맞춤
        xq = fake_quant_u8_q08(x)

        # weight를 i8(Q1.7) 격자에 맞춤
        wq = fake_quant_i8_q17(self.w)

        # conv 연산(실제는 float지만, 값은 Q격자에 맞춰져 있음)
        y = tf.nn.conv2d(xq, wq, strides=1, padding="VALID")

        # conv bias는 FPGA에서 안 쓰는 게 목표(use_bias=False)라서 보통 없음
        if self.b is not None:
            y = y + self.b

        return y

class QuantDense(tf.keras.layers.Layer):
    def __init__(self, units, use_bias=True, name=None):
        super().__init__(name=name)
        self.units = int(units)
        self.use_bias = bool(use_bias)

    def build(self, input_shape):
        cin = int(input_shape[-1])
        self.w = self.add_weight(
            name="kernel",
            shape=(cin, self.units),
            initializer="glorot_uniform",
            trainable=True
        )
        if self.use_bias:
            self.b = self.add_weight(
                name="bias",
                shape=(self.units,),
                initializer="zeros",
                trainable=True
            )
        else:
            self.b = None

    def call(self, x):
        # 입력 activation u8(Q0.8)
        xq = fake_quant_u8_q08(x)
        # weight i8(Q1.7)
        wq = fake_quant_i8_q17(self.w)

        y = tf.matmul(xq, wq)
        if self.b is not None:
            # (선택) bias도 Q15로 fake-quant하면 더 1:1에 가까워짐
            # bq = ste_round(self.b * 32768.0) / 32768.0
            # y = y + bq
            y = y + self.b
        return y

# ----------------------------
# 4) 모델 구성 (Keras 기본 레이어로 형태는 동일)
#    - conv bias 없음(=FPGA 동일)
#    - loss에서 from_logits=True 사용 => 마지막 Dense는 softmax 없이 logits 출력
# ----------------------------
inp = tf.keras.Input(shape=(28, 28, 1), name="in")

# ---- conv1 ----
x = QuantConv2D(3, (5, 5), use_bias=False, name="qconv1")(inp)
x = tf.keras.layers.ReLU()(x)
# conv1 결과는 FPGA에서 u8로 저장된다고 가정 => Q0.8로 스냅
x = fake_quant_u8_q08(x)

# ---- pool1 ----
x = tf.keras.layers.MaxPooling2D((2, 2))(x)
# pool 출력도 FPGA에서 u8로 저장(단순화/안정)
x = fake_quant_u8_q08(x)

# ---- conv2 ----
x = QuantConv2D(3, (5, 5), use_bias=False, name="qconv2")(x)
x = tf.keras.layers.ReLU()(x)
x = fake_quant_u8_q08(x)

# ---- pool2 ----
x = tf.keras.layers.MaxPooling2D((2, 2))(x)
x = fake_quant_u8_q08(x)

# ---- flatten + dense ----
x = tf.keras.layers.Flatten()(x)            # 4*4*3 = 48
logits = QuantDense(10, use_bias=True, name="qdense")(x)

model = tf.keras.Model(inp, logits, name="shift_only_cnn")
model.summary()

# ----------------------------
# 5) 학습
# ----------------------------
model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-3),
    loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True),
    metrics=["accuracy"]
)

# ----------------------------
# 5-1) (추가) epoch <= 200에서 best epoch 자동 선택
#   - QAT는 val이 들쭉날쭉할 수 있어서 patience를 너무 짧게 두면 손해
# ----------------------------
early_stop = tf.keras.callbacks.EarlyStopping(
    monitor="val_accuracy",
    mode="max",
    patience=10,
    restore_best_weights=True,
    verbose=1
)

reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
    monitor="val_loss",
    factor=0.5,
    patience=5,
    min_lr=1e-5,
    verbose=1
)

EPOCHS = 200
history = model.fit(
    x_train, y_train,
    epochs=EPOCHS,
    batch_size=128,
    validation_split=0.1,
    callbacks=[early_stop, reduce_lr],
    verbose=1
)

# (추가) best epoch 로그(발표/리포트용)
best_epoch = int(np.argmax(history.history["val_accuracy"]) + 1)
best_val_acc = float(np.max(history.history["val_accuracy"]))
print(f"\n[Best Epoch by val_accuracy] epoch={best_epoch}, val_acc={best_val_acc:.4f}")

loss, acc = model.evaluate(x_test, y_test, verbose=0)
print(f"\n[Q-world Train/Eval] loss={loss:.4f}, acc={acc:.4f}")

# ----------------------------
# 6) Export: FPGA가 바로 먹을 형태
#    - weights: int8(Q1.7)
#    - dense bias: int32(Q15)
# ----------------------------
def float_to_i8_q17(w_float: np.ndarray) -> np.ndarray:
    q = np.round(w_float * 128.0)
    q = np.clip(q, -128, 127).astype(np.int8)
    return q

export_dir = "export"
os.makedirs(export_dir, exist_ok=True)

W1_f = model.get_layer("qconv1").w.numpy()         # (5,5,1,3)
W2_f = model.get_layer("qconv2").w.numpy()         # (5,5,3,3)
Wd_f = model.get_layer("qdense").w.numpy()         # (48,10)
bd_f = model.get_layer("qdense").b.numpy()         # (10,) float

W1_q = float_to_i8_q17(W1_f)
W2_q = float_to_i8_q17(W2_f)
Wd_q = float_to_i8_q17(Wd_f)

# Dense bias를 acc 도메인(Q15=1/32768)으로 저장
bd_q15 = np.round(bd_f * 32768.0).astype(np.int32)

EXPORT_PATH = os.path.join(export_dir, "mnist_shift_only_fpga_export.npz")
np.savez(
    EXPORT_PATH,
    W1_q=W1_q,
    W2_q=W2_q,
    Wd_q=Wd_q,
    bd_q15=bd_q15
)

print(f"\nSaved FPGA export: {EXPORT_PATH}")
print("  - weights: int8(Q1.7)")
print("  - dense bias: int32(Q15)")

