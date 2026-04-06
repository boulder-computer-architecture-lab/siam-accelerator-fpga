import numpy as np
import os

DATA_DIR    = "../Data_Country"
TRMULT_BASE = "trmult_reduced64.npy"

# OG
trmult64 = np.load(os.path.join(DATA_DIR, TRMULT_BASE))

# Precision
trmult32 = trmult64.astype(np.float32).copy(); np.save(os.path.join(DATA_DIR, "trmult_reduced32.npy"), trmult32)
trmult16 = trmult64.astype(np.float16).copy(); np.save(os.path.join(DATA_DIR, "trmult_reduced16.npy"), trmult16)

# Scaled
trmult64_scaled = trmult64 * 100.0; np.save(os.path.join(DATA_DIR, "trmult_scaled64.npy"), trmult64_scaled)
trmult32_scaled = trmult32 * 100.0; np.save(os.path.join(DATA_DIR, "trmult_scaled32.npy"), trmult32_scaled)
trmult16_scaled = trmult16 * 100.0; np.save(os.path.join(DATA_DIR, "trmult_scaled16.npy"), trmult16_scaled)

# Padded
N = trmult64.shape[0]
N_pad = ((N + 63) // 64) * 64

trmult64_padded = np.zeros((N_pad, N_pad), dtype=trmult64.dtype); trmult64_padded[:N, :N] = trmult64; np.save(os.path.join(DATA_DIR, "trmult_reduced64_padded.npy"), trmult64_padded)
trmult32_padded = np.zeros((N_pad, N_pad), dtype=trmult32.dtype); trmult32_padded[:N, :N] = trmult32; np.save(os.path.join(DATA_DIR, "trmult_reduced32_padded.npy"), trmult32_padded)
trmult16_padded = np.zeros((N_pad, N_pad), dtype=trmult16.dtype); trmult16_padded[:N, :N] = trmult16; np.save(os.path.join(DATA_DIR, "trmult_reduced16_padded.npy"), trmult16_padded)

trmult64_padded_scaled = np.zeros((N_pad, N_pad), dtype=trmult64_scaled.dtype); trmult64_padded_scaled[:N, :N] = trmult64_scaled; np.save(os.path.join(DATA_DIR, "trmult_scaled64_padded.npy"), trmult64_padded_scaled)
trmult32_padded_scaled = np.zeros((N_pad, N_pad), dtype=trmult32_scaled.dtype); trmult32_padded_scaled[:N, :N] = trmult32_scaled; np.save(os.path.join(DATA_DIR, "trmult_scaled32_padded.npy"), trmult32_padded_scaled)
trmult16_padded_scaled = np.zeros((N_pad, N_pad), dtype=trmult16_scaled.dtype); trmult16_padded_scaled[:N, :N] = trmult16_scaled; np.save(os.path.join(DATA_DIR, "trmult_scaled16_padded.npy"), trmult16_padded_scaled)

