from dataclasses import dataclass
import numpy as np
from typing import Any, Optional

@dataclass
class ModelState:
    H0: Any
    a: np.ndarray
    a_norm: Any
    m2: np.ndarray
    C_vect: np.ndarray
    tau0: np.ndarray
    pop0: np.ndarray
    pop5: np.ndarray
    pop5_fertadj: np.ndarray
    popminus5: np.ndarray
    popminus10: np.ndarray
    ubar: np.ndarray
    trmult_reduced: Any
    trmult_reduced_padded: Any
    n: int
    earth_indices: np.ndarray
    indicator_sea: Any
    subs: np.ndarray
    subs_vect: Any
    beta: float
    tail_bands: float
    ind_islands: Any
    alpha: float
    theta: float
    Omega: float
    kernel: Optional[Any] = None
    Npad: Optional[int] = None

    def mvm(self, x: np.ndarray) -> np.ndarray:
        if self.kernel is None:
            return self.trmult_reduced @ x

        # Set data type
        k_dtype = self.kernel.vector.dtype
        _x = np.clip(x, np.finfo(k_dtype).tiny, np.finfo(k_dtype).max)
        _x = np.asarray(_x, dtype=k_dtype)

        # Pad + partition vec
        N = _x.shape[0]
        flat = self.kernel.vector.reshape(-1)
        flat.fill(0)
        flat[:N] = _x

        y = self.kernel.matvec()

        # Construct result
        y = y.reshape(-1).astype(x.dtype)
        y[np.isinf(y)] = np.finfo(k_dtype).max

        return y[:N].copy()

