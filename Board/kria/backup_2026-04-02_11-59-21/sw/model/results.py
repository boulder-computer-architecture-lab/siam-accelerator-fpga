import numpy as np
#from scipy.stats import pearsonr
from model import model

def accumarray(indices, values, size):
    return np.bincount(indices.astype(int) - 1, weights=values, minlength=size)

def results(H, T, state, np_dtype, prescaled=True):
    # Global variables
    H0 = state.H0
    a = state.a
    a_norm = state.a_norm
    m2 = state.m2
    C_vect = state.C_vect
    pop0 = state.pop0
    pop5 = state.pop5
    pop5_fertadj = state.pop5_fertadj
    beta = state.beta
    n = state.n
    earth_indices = state.earth_indices
    alpha = state.alpha
    theta = state.theta
    Omega = state.Omega

    # Initialize output arrays
    realgdp_w = np.zeros(T, dtype=np_dtype)
    u_w = np.zeros(T, dtype=np_dtype)
    u2_w = np.zeros(T, dtype=np_dtype)
    prod_w = np.zeros(T, dtype=np_dtype)
    phi_w = np.zeros(T, dtype=np_dtype)
    PDV_u_w = 0
    PDV_u2_w = 0
    PDV_realgdp_w = 0

    # Simulate the model
    l, w, u, tau, phi, realgdp = model(H, T, state, np_dtype, prescaled=prescaled)

    # Calculate correlations - Cell Level
    print('CORRELATIONS - CELL LEVEL')
    #corr_pop5 = pearsonr(pop5[earth_indices], H * l[:, 4])
    #corr_log_pop5 = pearsonr(np.log(pop5[earth_indices]), np.log(H * l[:, 4]))
    #corr_pop5_diff = pearsonr(pop5[earth_indices] - pop0[earth_indices], H * l[:, 4] - pop0[earth_indices])
    #corr_log_pop5_diff = pearsonr(np.log(pop5[earth_indices]) - np.log(pop0[earth_indices]), np.log(H * l[:, 4]) - np.log(pop0[earth_indices]))

    print('CORRELATIONS - COUNTRY LEVEL')
    #pop5_ctry_d = accumarray(C_vect, pop5[earth_indices], 168)
    #pop5_ctry_m = accumarray(C_vect, H * l[:, 4], 168)
    pop0_ctry = accumarray(C_vect, pop0[earth_indices], 168)
    #corr_pop5_ctry_d = pearsonr(pop5_ctry_d, pop5_ctry_m)
    #corr_log_pop5_ctry_d = pearsonr(np.log(pop5_ctry_d), np.log(pop5_ctry_m))
    #corr_pop5_ctry_diff = pearsonr(pop5_ctry_d - pop0_ctry, pop5_ctry_m - pop0_ctry)
    #corr_log_pop5_ctry_diff = pearsonr(np.log(pop5_ctry_d) - np.log(pop0_ctry), np.log(pop5_ctry_m) - np.log(pop0_ctry))

    # Fertility-Adjusted Correlations - Cell Level
    print('CORRELATIONS (FERTILITY-ADJUSTED) - CELL LEVEL')
    #corr_pop5_fertadj = pearsonr(pop5_fertadj[earth_indices], H * l[:, 4])
    #corr_log_pop5_fertadj = pearsonr(np.log(pop5_fertadj[earth_indices]), np.log(H * l[:, 4]))
    #corr_pop5_fertadj_diff = pearsonr(pop5_fertadj[earth_indices] - pop0[earth_indices], H * l[:, 4] - pop0[earth_indices])
    #corr_log_pop5_fertadj_diff = pearsonr(np.log(pop5_fertadj[earth_indices]) - np.log(pop0[earth_indices]), np.log(H * l[:, 4]) - np.log(pop0[earth_indices]))

    print('CORRELATIONS (FERTILITY-ADJUSTED) - COUNTRY LEVEL')
    #pop5_fertadj_ctry = accumarray(C_vect, pop5_fertadj[earth_indices], 168)
    #corr_pop5_fertadj_ctry = pearsonr(pop5_fertadj_ctry, pop5_ctry_m)
    #corr_log_pop5_fertadj_ctry = pearsonr(np.log(pop5_fertadj_ctry), np.log(pop5_ctry_m))
    #corr_pop5_fertadj_ctry_diff = pearsonr(pop5_fertadj_ctry - pop0_ctry, pop5_ctry_m - pop0_ctry)
    #corr_log_pop5_fertadj_ctry_diff = pearsonr(np.log(pop5_fertadj_ctry) - np.log(pop0_ctry), np.log(pop5_ctry_m) - np.log(pop0_ctry))

    # Compute world aggregates
    u2 = np.zeros((n, T), dtype=np_dtype)
    #m1 = np.power(m2, -1)
    for t in range(T):
        u2[:, t] = np.sum(np.power(u[:, t], 1 / Omega) * np.power(m2, -1 / Omega)) ** Omega * m2
        u_w[t] = np.sum(u[:, t] * H * l[:, t])
        u2_w[t] = np.sum(u2[:, t] * H * l[:, t])
        realgdp_w[t] = np.sum(realgdp[:, t] * H * l[:, t])
        prod_w[t] = np.sum(np.power(tau[:, t] * H * np.power(l[:, t], 1 + alpha), 1 / theta))
        phi_w[t] = np.sum(phi[:, t] * H * l[:, t])
        PDV_u_w += beta ** t * u_w[t]
        PDV_u2_w += beta ** t * u2_w[t]
        PDV_realgdp_w += beta ** t * realgdp_w[t]

    if beta * u_w[-1] / u_w[-2] < 1:
        PDV_u_w += (beta ** T * u_w[-1] ** 2 / u_w[-2]) / (1 - beta * u_w[-1] / u_w[-2])
    else:
        PDV_u_w = np.nan

    if beta * u2_w[-1] / u2_w[-2] < 1:
        PDV_u2_w += (beta ** T * u2_w[-1] ** 2 / u2_w[-2]) / (1 - beta * u2_w[-1] / u2_w[-2])
    else:
        PDV_u2_w = np.nan

    if beta * realgdp_w[-1] / realgdp_w[-2] < 1:
        PDV_realgdp_w += (beta ** T * realgdp_w[-1] ** 2 / realgdp_w[-2]) / (1 - beta * realgdp_w[-1] / realgdp_w[-2])
    else:
        PDV_realgdp_w = np.nan

    # Share of migrants - Cell Level
    migr_cell = np.zeros(T, dtype=np_dtype)
    for t in range(T):
        summ = 0
        for j in range(n):
            if t == 0:
                if H[j] * l[j, 0] > pop0[earth_indices[j]]:
                    summ += H[j] * l[j, 0] - pop0[earth_indices[j]]
            else:
                if H[j] * l[j, t] > H[j] * l[j, t - 1]:
                    summ += H[j] * l[j, t] - H[j] * l[j, t - 1]
        migr_cell[t] = summ / np.sum(pop0)

    migr_ctry = np.zeros(T, dtype=np_dtype)
    pop_ctry_m = np.zeros((168, T), dtype=np_dtype)
    for t in range(T):
        pop_ctry_m[:, t] = accumarray(C_vect, H * l[:, t], 168)
        summ = 0
        for i in range(168):
            if t == 0:
                if pop_ctry_m[i, 0] > pop0_ctry[i]:
                    summ += pop_ctry_m[i, 0] - pop0_ctry[i]
            else:
                if pop_ctry_m[i, t] > pop_ctry_m[i, t - 1]:
                    summ += pop_ctry_m[i, t] - pop_ctry_m[i, t - 1]
        migr_ctry[t] = summ / np.sum(pop0_ctry)

    return realgdp_w, u_w, u2_w, prod_w, phi_w, PDV_u_w, PDV_u2_w, PDV_realgdp_w, migr_cell, migr_ctry, l, u, u2, tau, realgdp
