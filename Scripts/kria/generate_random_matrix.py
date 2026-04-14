#!/usr/bin/python3

import numpy as np
import argparse
import os

MTRX_DIR = "../../Board/kria"

def main():
    parser = argparse.ArgumentParser(description="Generate a random matrix and save to .npy")
    parser.add_argument("num_channels", type=int, help="Number of channels")
    parser.add_argument("rows_per_channel", type=int, help="Number of rows per channel")
    parser.add_argument("num_cols", type=int, help="Number of columns")
    parser.add_argument(
        "--dtype",
        choices=["fp16", "fp32", "fp64"],
        default="fp16",
        help="Floating-point precision to use (default: fp16)"
    )
    args = parser.parse_args()

    dtype_map = {
        "fp16": np.float16,
        "fp32": np.float32,
        "fp64": np.float64,
    }

    dtype = dtype_map[args.dtype]
    num_channels     = args.num_channels
    rows_per_channel = args.rows_per_channel
    num_cols         = args.num_cols

    precision   = args.dtype.replace("fp", "")
    matrix_path = os.path.join(MTRX_DIR, f"matrix{precision}_{num_cols}.npy")

    matrix_data = np.random.rand(num_channels, rows_per_channel, num_cols).astype(dtype) * 100.0
    np.save(matrix_path, matrix_data)
    print(f"Matrix saved to {os.path.abspath(matrix_path)}")

if __name__ == "__main__":
    main()

