import numpy as np
import time

trmult16        = np.load("Data/trmult_reduced16.npy")
trmult16_scaled = np.load("Data/trmult_scaled16.npy" )
trmult64        = np.load("Data/trmult_reduced64.npy")

vec64 = np.random.rand(17048) * 100
vec16 = vec64.astype(np.float16)

result64 = np.dot(trmult64, vec64)

start = time.perf_counter()
result16 = np.dot(trmult16, vec16)
end = time.perf_counter()
print(f"--- No scale ---")
print(f"time: {end - start:.4g}")
print(f"result16 dtype: {result16.dtype}")
print(f"avg_err: {np.mean(np.abs(result64 - result16.astype(np.float64)))}")
print(f"res_avg: {np.mean(result16)}")

print(f"--- Scaled ---")
start = time.perf_counter()
result16_scaled = np.dot(trmult16_scaled, vec16)
end = time.perf_counter()
print(f"time: {end - start:.4g}")
print(f"result16 dtype: {result16_scaled.dtype}")
print(f"avg_err: {np.mean(np.abs( result64 - (result16_scaled.astype(np.float64) / 100.0) ))}")
print(f"res_avg: {np.mean(result16_scaled / 100.0)}")
