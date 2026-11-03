# 웹용 ONNX의 가중치를 줄인다 (docs/DESIGN.md 3.3). 80MB → 20MB.
#
#   uvx --python 3.12 --with onnx --with numpy python -I scripts/quantize_onnx.py pillbox.onnx pillbox-w8.onnx
#
# Conv 가중치는 출력 채널별 int8로, 나머지 가중치는 fp16으로 저장하고 불러올 때 fp32로 되돌린다
# (DequantizeLinear, Cast). 계산은 fp32 그대로라 onnxruntime-web의 wasm에서도 돈다.
import sys

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

src, dst = sys.argv[1:3]
model = onnx.load(src)
graph = model.graph
conv_weights = {n.input[1] for n in graph.node if n.op_type == "Conv"}

initializers, restore = [], []
for init in graph.initializer:
    # 작은 상수(모양, 축 등)는 그대로 둔다.
    if init.data_type != TensorProto.FLOAT or np.prod(init.dims) <= 16:
        initializers.append(init)
        continue
    weights = numpy_helper.to_array(init)
    if init.name in conv_weights and weights.ndim == 4:
        scale = np.abs(weights).reshape(weights.shape[0], -1).max(1) / 127
        scale[scale == 0] = 1e-8
        q = np.clip(np.round(weights / scale[:, None, None, None]), -127, 127)
        initializers += [
            numpy_helper.from_array(q.astype(np.int8), init.name + "_q"),
            numpy_helper.from_array(scale.astype(np.float32), init.name + "_scale"),
            numpy_helper.from_array(np.zeros(weights.shape[0], np.int8), init.name + "_zero"),
        ]
        restore.append(
            helper.make_node(
                "DequantizeLinear",
                [init.name + "_q", init.name + "_scale", init.name + "_zero"],
                [init.name],
                axis=0,
            )
        )
    else:
        initializers.append(numpy_helper.from_array(weights.astype(np.float16), init.name + "_fp16"))
        restore.append(helper.make_node("Cast", [init.name + "_fp16"], [init.name], to=TensorProto.FLOAT))

del graph.initializer[:]
graph.initializer.extend(initializers)
nodes = list(graph.node)
del graph.node[:]
graph.node.extend(restore + nodes)
onnx.checker.check_model(model)
onnx.save(model, dst)
