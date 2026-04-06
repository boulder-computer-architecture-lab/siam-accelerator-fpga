import numpy as np
from math import gamma

def backward(H, T, state):
    # Ensure global variables are available
    H0 = state.H0
    a = state.a
    a_norm = state.a_norm
    m2 = state.m2
    tau0 = state.tau0
    pop0 = state.pop0
    ubar = state.ubar
    trmult_reduced = state.trmult_reduced
    n = state.n
    earth_indices = state.earth_indices
    alpha = state.alpha
    theta = state.theta
    Omega = state.Omega
    
    # Initialize parameters and output
    # Normalize population to population density
    H0_arr = np.asarray(H0).reshape(-1)
    popdens = np.copy(pop0)
    popdens[earth_indices] = popdens[earth_indices] / H0_arr[earth_indices]
    popdens[np.isinf(popdens)] = 0
    popdens[np.isnan(popdens)] = 0

    if a_norm is None:
        psi = 1.8
        u0 = np.exp(psi * ubar[earth_indices])
        a_norm = np.asarray(a).reshape(-1) * u0

    # Parameter values
    lbar = 5.9174e+09
    lambda_ = 0.32
    gamma1 = 0.319
    gamma2 = 0.99246
    mu = 0.8
    nu = 0.15
    ksi = 125
    sigma = 4
    #rad = 6371
    khi = lambda_ - (alpha - 1 + (lambda_ + gamma1 / ksi - (1 - mu)) * theta) / (1 + 2 * theta)
    kappa1 = ((mu * ksi + gamma1) / ksi) ** (-(mu + gamma1 / ksi) * theta) * \
             mu ** (mu * theta) * (ksi * nu / gamma1) ** (-gamma1 / ksi * theta) * \
             gamma(1 - (sigma - 1) / theta) ** (theta / (sigma - 1))

    # Initialize output variables
    dtype = np.float32
    l = np.zeros((n, T), dtype=dtype)
    u = np.zeros((n, T), dtype=dtype)
    w = np.zeros((n, T), dtype=dtype)
    phi = np.zeros((n, T), dtype=dtype)
    tau = np.zeros((n, T), dtype=dtype)
    realgdp = np.zeros((n, T), dtype=dtype)

    # 2. Simulate the model backwards

    # Initial guess for Lhat
    l_loop = np.copy(popdens[earth_indices])

    # Outer loop
    for t in range(T):
        print(f't={-t - 1}')

        # Next period's productivity
        if t > 0:
            taunext = tau[:, t - 1]
        else:
            taunext = tau0

        eps_val = 1e-12
        eps_pos = 1e-300
        taunext = np.asarray(taunext)
        taunext = np.maximum(taunext, eps_pos)
        taunext = np.minimum(taunext, 1e300)

        # Solve for Lhat
        error = 1e+10
        
        # Pre-computed quantities used in the while loop
        aa = a_norm ** (theta ** 2 / (1 + 2 * theta))
        aa2 = a_norm ** ((1 + theta) / ((khi + Omega * (1 + theta) / (1 + 2 * theta) + theta / (1 + 2 * theta) * gamma1 / (ksi * gamma2)) * (1 + 2 * theta)))
        exponent_l = (1 - lambda_ * theta + (1 + theta) / (1 + 2 * theta) * (alpha - 1 + (lambda_ + gamma1 / ksi - (1 - mu)) * theta))
        input_integral_outer = aa * H ** ((theta - theta ** 2 * Omega) / (1 + 2 * theta)) * \
                               taunext ** ((1 + theta) / (gamma2 * (1 + 2 * theta))) * \
                               m2 ** (-theta ** 2 / (1 + 2 * theta))
        input_integral_outer[~np.isfinite(input_integral_outer)] = 0
        denom_inner = (khi + Omega * (1 + theta) / (1 + 2 * theta) + theta / (1 + 2 * theta) * gamma1 / (ksi * gamma2))
        input_l_inner = H ** (-(1 + Omega * (1 + theta)) / (denom_inner * (1 + 2 * theta))) * \
                        taunext ** (1 / (denom_inner * gamma2 * (1 + 2 * theta))) * \
                        m2 ** (-(1 + theta) / (denom_inner * (1 + 2 * theta)))
        input_l_inner[H == 0] = 0
        input_l_inner[~np.isfinite(input_l_inner)] = 0
        input_l_inner = np.maximum(input_l_inner, 0)
        input_l_inner = np.minimum(input_l_inner, 1e300)
        
        # Inner loop - solve for l using equation (40)
        it = 0
        max_it = 2000
        while error >= 1:
            l_old = np.copy(l_loop)

            l_loop = np.maximum(l_loop, eps_pos)
            l_loop = np.minimum(l_loop, 1e300)

            input_integral_inner = input_integral_outer * \
                                   l_loop ** (exponent_l - Omega * theta ** 2 / (1 + 2 * theta) - theta * (1 + theta) / (1 + 2 * theta) * gamma1 / (ksi * gamma2))
            input_integral_inner[l_loop == 0] = 0
            input_integral_inner[~np.isfinite(input_integral_inner)] = 0
            
            # Matrix product
            rhs = state.mvm(input_integral_inner)
            rhs = np.maximum(rhs, eps_val)
            
            l_loop = aa2 * input_l_inner * rhs ** (1 / ((khi + Omega * (1 + theta) / (1 + 2 * theta) + theta / (1 + 2 * theta) * gamma1 / (ksi * gamma2)) * theta))
            l_loop[~np.isfinite(l_loop)] = eps_pos
            l_loop = np.minimum(l_loop, 1e300)
            error = np.sum((l_loop - l_old) ** 2)
            if not np.isfinite(error):
                error = 0
            it += 1
            if it >= max_it:
                error = 0
        
        # Rescale L so that H * L sum to lbar
        denom = np.sum(H * l_loop)
        if (not np.isfinite(denom)) or denom <= eps_pos:
            denom = eps_pos
        l[:, t] = l_loop / denom * lbar
        
        # Back out productivity using equation (39)
        tau[:, t] = ((mu + gamma1 / ksi) / (gamma1 / ksi) * nu) ** (theta * gamma1 / (ksi * gamma2)) * \
                    taunext ** (1 / gamma2) * l[:, t] ** (-theta * gamma1 / (ksi * gamma2))
        avgprodtogamma2 = np.sum(tau[:, t]) / n
        tau[:, t] = avgprodtogamma2 ** (gamma2 - 1) * tau[:, t]
        tau[:, t] = np.maximum(tau[:, t], eps_pos)
        tau[:, t] = np.minimum(tau[:, t], 1e300)
        
        # Calculate utility
        u[:, t] = m2 * l[:, t] ** Omega * (kappa1 ** (1 / Omega) * \
                  ((mu + gamma1 / ksi) / (gamma1 / ksi) * nu) ** (gamma1 / (ksi * gamma2)) * \
                  (np.sum(tau[:, t]) / n) ** (1 / theta * (1 - 1 / gamma2)) * \
                  (lbar / denom) ** (1 / theta - 2 * lambda_ + (alpha - 1 + (lambda_ + gamma1 / ksi - (1 - mu)) * theta) / theta - Omega - gamma1 / (ksi * gamma2)))
        u[:, t][~np.isfinite(u[:, t])] = 0
        
        # Calculate real GDP per capita using equation (22)
        realgdp[:, t] = u[:, t] / a_norm * l[:, t] ** lambda_
        
        # Calculate innovation using equation (12) and (13)
        phi[:, t] = (gamma1 / (nu * (gamma1 + mu * ksi))) ** (1 / ksi) * l[:, t] ** (1 / ksi)
        
        # Calculate wage using equation (23)
        w[:, t] = a_norm ** (-theta / (1 + 2 * theta)) * u[:, t] ** (theta / (1 + 2 * theta)) * H ** (-1 / (1 + 2 * theta)) * \
                  tau[:, t] ** (1 / (1 + 2 * theta)) * l[:, t] ** ((alpha - 1 + (lambda_ + gamma1 / ksi - (1 - mu)) * theta) / (1 + 2 * theta))
        
        # Normalize wages relative to Princeton, NJ (Python index adjustment)
        w[:, t] = w[:, t] / w[3198, t]  # Adjust index as necessary for your data

    # Handle NaN values
    realgdp[np.isnan(realgdp)] = 0
    tau[np.isnan(tau)] = 0
    phi[np.isnan(phi)] = 0
    w[np.isnan(w)] = 0
    u[np.isnan(u)] = 0
    l[np.isnan(l)] = 0

    return l, u, w, tau, phi, realgdp
