import numpy as np
from pathlib import Path

PREC = 64
SCALE = "reduced" if PREC != 16 else "scaled"

mat = np.load(f"Model/Data_Country/trmult_{SCALE}{PREC}_padded.npy")
assert mat.shape == (192, 192)

outdir = Path("mem_out")
outdir.mkdir(exist_ok=True)

rows_per_ch = 48

if PREC == 16:
    mat = mat.astype(np.float16)
    lane_bits = 16
elif PREC == 32:
    mat = mat.astype(np.float32)
    lane_bits = 32
elif PREC == 64:
    mat = mat.astype(np.float64)
    lane_bits = 64
else:
    raise ValueError(f"Unsupported PREC={PREC}")

lanes_per_word = 128 // lane_bits

if lane_bits == 16:
    raw = mat.view(np.uint16)
elif lane_bits == 32:
    raw = mat.view(np.uint32)
else:
    raw = mat.view(np.uint64)

for ch in range(4):
    chunk = raw[ch * rows_per_ch:(ch + 1) * rows_per_ch].reshape(-1, lanes_per_word)

    with open(outdir / f"a_ch{ch}.mem", "w") as f:
        for group in chunk:
            word = sum(int(x) << (lane_bits * i) for i, x in enumerate(group))
            f.write(f"{word:032x}\n")
