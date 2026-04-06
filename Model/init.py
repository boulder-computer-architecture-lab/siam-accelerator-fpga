import numpy as np
from state import ModelState

def _load_npy(path, flat=False, mmap=False):
    arr = np.load(path, mmap_mode="r" if mmap else None)
    if flat: arr = np.asarray(arr).reshape(-1)
    return arr


def initialize(N=17048, prescale=True):
    H0   = _load_npy("Data/H0.npy")
    a    = _load_npy("Data/a_H0.npy", flat=True)
    tau0 = _load_npy("Data/tau_H0.npy", flat=True)
    m2   = _load_npy("Data/m2.npy", flat=True)

    a_norm = None

    pop0         = _load_npy("Data/l.npy", flat=True)
    pop5         = _load_npy("Data/pop5.npy", flat=True)
    popminus5    = _load_npy("Data/popminus5.npy", flat=True)
    popminus10   = _load_npy("Data/popminus10.npy", flat=True)
    pop5_fertadj = _load_npy("Data/pop5_fertadj.npy", flat=True)

    H0_arr = np.asarray(H0)
    earth_indices = np.flatnonzero(H0_arr.reshape(-1) > 0)
    n = int(earth_indices.size)
    indicator_sea = (H0_arr == 0)

    ubar = _load_npy("Data/ubar.npy", flat=True)
    ubar[np.isnan(ubar)] = 0
    ubar[np.isinf(ubar)] = 0

    mat_file = "Data/trmult_scaled64.npy" if prescale else "Data/trmult_reduced64.npy"
    trmult_reduced = _load_npy(mat_file, mmap=True)

    C = _load_npy("Data/C.npy", flat=True)
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
        trmult_reduced, n, earth_indices, indicator_sea, subs, None,
        beta, tail_bands, None, alpha, theta, Omega
    )

