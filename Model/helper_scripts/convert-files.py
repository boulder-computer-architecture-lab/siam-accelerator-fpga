import os
import numpy as np
import scipy.io as sio

DTYPE = np.float64
DATA_DIR = "../Data_Country"

def _load_mat_any(path):
    try:
        return sio.loadmat(path)
    except NotImplementedError:
        import h5py

        out = {}
        with h5py.File(path, 'r') as f:
            for k in f.keys():
                out[k] = np.array(f[k])
        return out

def _load_mat_var(path, var_name=None):
    d = _load_mat_any(path)
    if var_name is not None:
        if var_name not in d:
            raise KeyError(f"Variable '{var_name}' not found in {path}. Keys: {list(d.keys())}")
        return d[var_name]

    keys = [k for k in d.keys() if not k.startswith('__')]
    if len(keys) != 1:
        raise KeyError(f"Expected exactly one variable in {path}; found keys: {keys}")
    return d[keys[0]]

def _load_txt_flat(path):
    arr = np.loadtxt(path, delimiter=',')
    return np.asarray(arr, dtype=DTYPE).reshape(-1)

for fname in os.listdir(DATA_DIR):

    full_path = os.path.join(DATA_DIR, fname)

    if fname.endswith(".npy"):
        continue

    if fname.endswith(".mat"):
        arr = _load_mat_var(full_path)
        arr = np.asarray(arr, dtype=DTYPE)
        out_path = full_path.replace(".mat", ".npy")
        np.save(out_path, arr)
        print("Converted MAT:", fname)

    elif fname.endswith(".csv"):
        arr = _load_txt_flat(full_path)
        out_path = full_path.replace(".csv", ".npy")
        np.save(out_path, arr)
        print("Converted CSV:", fname)

print("Done.")
