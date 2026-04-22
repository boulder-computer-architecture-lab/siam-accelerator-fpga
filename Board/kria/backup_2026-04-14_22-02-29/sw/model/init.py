import numpy as np
from state import ModelState
import os

def _load_npy(path, flat=False, mmap=False):
    arr = np.load(path, mmap_mode="r" if mmap else None)
    if flat: arr = np.asarray(arr).reshape(-1)
    return arr

def initialize(precision, data_dir="Data", prescale=True):
    global alpha, theta, earth_indices

    if   (data_dir == "Data"        ): N = 17048
    elif (data_dir == "Data_Country"): N = 168
    else: raise ValueError(f"Invalid data_dir: {data_dir}")

    DATA_DIR = os.path.join("/home/ubuntu/mvm-accelerator/sw/model", data_dir)

    H0   = _load_npy(os.path.join(DATA_DIR, "H0.npy"))
    a    = _load_npy(os.path.join(DATA_DIR, "a_H0.npy"), flat=True)
    tau0 = _load_npy(os.path.join(DATA_DIR, "tau_H0.npy"), flat=True)
    m2   = _load_npy(os.path.join(DATA_DIR, "m2.npy"), flat=True)

    a_norm = None

    pop0         = _load_npy(os.path.join(DATA_DIR, "l.npy"), flat=True)
    pop5         = _load_npy(os.path.join(DATA_DIR, "pop5.npy"), flat=True)
    popminus5    = _load_npy(os.path.join(DATA_DIR, "popminus5.npy"), flat=True)
    popminus10   = _load_npy(os.path.join(DATA_DIR, "popminus10.npy"), flat=True)
    pop5_fertadj = _load_npy(os.path.join(DATA_DIR, "pop5_fertadj.npy"), flat=True)

    H0_arr = np.asarray(H0)
    earth_indices = np.flatnonzero(H0_arr.reshape(-1) > 0)
    n = int(earth_indices.size)
    indicator_sea = (H0_arr == 0)

    ubar = _load_npy(os.path.join(DATA_DIR, "ubar.npy"), flat=True)
    ubar[np.isnan(ubar)] = 0
    ubar[np.isinf(ubar)] = 0

    scale_type = "reduced" if not prescale else "scaled"
    trmult_reduced_padded = _load_npy(os.path.join(DATA_DIR, f"trmult_{scale_type}{precision}_padded.npy"), mmap=True)
    trmult_reduced = trmult_reduced_padded[:N, :N]

    C = _load_npy(os.path.join(DATA_DIR, "C.npy"), flat=True)
    C_stock = C[earth_indices]
    indices = np.unique(C_stock)
    C_stock_2 = C_stock.copy()
    for i, idx in enumerate(indices, start=1):
        C_stock_2[C_stock == idx] = i
    C[earth_indices] = C_stock_2

    subs = C.reshape(-1) + 1
    C_vect = C[earth_indices]

    beta = 0.965
    tail_bands = 0.2
    alpha = 0.06
    theta = 6.5
    Omega = 0.5

    return ModelState(
        H0, a, a_norm, m2, C_vect, tau0,
        pop0, pop5, pop5_fertadj, popminus5, popminus10, ubar,
        trmult_reduced, trmult_reduced_padded, n, earth_indices, indicator_sea, subs, None,
        beta, tail_bands, None, alpha, theta, Omega, None, None
    )

