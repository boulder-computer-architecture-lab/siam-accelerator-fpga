import numpy as np
#from scipy.special import gamma

def model(H, T, state):
    # Global variables (make sure these are initialized or imported correctly)
    H0 = state.H0
    a = state.a
    a_norm = state.a_norm
    m2 = state.m2
    C_vect = state.C_vect
    tau0 = state.tau0
    pop0 = state.pop0
    ubar = state.ubar
    trmult_reduced = state.trmult_reduced
    earth_indices = state.earth_indices
    n = state.n
    alpha = state.alpha
    theta = state.theta
    Omega = state.Omega
    
    # Initialize parameters and output
    # Normalize population to population density
    H0_arr = np.asarray(H0).reshape(-1)
    popdens = pop0.copy()
    popdens[earth_indices] = popdens[earth_indices] / H0_arr[earth_indices]
    popdens[np.isinf(popdens)] = 0
    popdens[np.isnan(popdens)] = 0

    # Parameter values
    lbar = 5.9174e+09  # Total population
    lambda_ = 0.32     # Congestion externalities
    gamma1 = 0.319    # Elasticity of tomorrow's productivity w.r.t. today's innovation
    gamma2 = 0.99246  # Elasticity of tomorrow's productivity w.r.t. today's productivity
    eta = 1           # Parameter driving scale of technology diffusion
    mu = 0.8          # Labor share in production
    nu = 0.15         # Intercept parameter in innovation cost function
    ksi = 125         # Elasticity of innovation costs w.r.t. innovation
    sigma = 4         # Elasticity of substitution
    #rad = 6371        # Radius of Earth
    psi = 1.8         # Subjective wellbeing parameter
    khi = lambda_ - (alpha - 1 + (lambda_ + gamma1 / ksi - (1 - mu)) * theta) / (1 + 2 * theta)
    #kappa1 = ((mu * ksi + gamma1) / ksi) ** (-(mu + gamma1 / ksi) * theta) * mu ** (mu * theta) * \
    #         (ksi * nu / gamma1) ** (-gamma1 / ksi * theta) * gamma(1 - (sigma - 1) / theta) ** (theta / (sigma - 1))

    # Calculate utility from subjective wellbeing
    u0 = np.exp(psi * ubar[earth_indices])

    # Back out amenities
    a_norm = a * u0

    # Initialize output variables
    dtype = np.float32
    l = np.zeros((n, T), dtype=dtype)
    w = np.zeros((n, T), dtype=dtype)
    phi = np.zeros((n, T), dtype=dtype)
    realgdp = np.zeros((n, T), dtype=dtype)
    tau = np.zeros((n, T), dtype=dtype)
    u = np.zeros((n, T), dtype=dtype)
    uhat = np.zeros((n, T), dtype=dtype)

    # 2. Simulate the model

    # Update productivity from period 0 to period 1 levels according to equations (8), (12), and (13)
    avgprod = np.sum(tau0) / n
    tau[:, 0] = eta * tau0 ** gamma2 * avgprod ** (1 - gamma2) * \
                (gamma1 / (nu * (gamma1 + mu * ksi)) * popdens[earth_indices]) ** (gamma1 * theta / ksi)

    # Initial guess for uhat
    uhat_loop = np.ones(n) / n

    # Calculate equilibrium distribution for each period
    for t in range(T):
        print(f't={t + 1}')

        # Solve for uhat using equation (51)
        error = 1e+10

        # Pre-computed quantities used in the while loop
        aa = a_norm ** (theta ** 2 / (1 + 2 * theta))
        aa2 = a_norm ** ((1 + theta) / ((khi / Omega + (1 + theta) / (1 + 2 * theta)) * (1 + 2 * theta)))
        exponent_l = (1 - lambda_ * theta + (1 + theta) / (1 + 2 * theta) * (alpha - 1 + (lambda_ + gamma1 / ksi - (1 - mu)) * theta))
        input_integral_outer = aa * (H ** (theta / (1 + 2 * theta) - 1 + lambda_ * theta - (1 + theta) / (1 + 2 * theta) * (alpha - 1 + (lambda_ + gamma1 / ksi - (1 - mu)) * theta))) * \
                               tau[:, t] ** ((1 + theta) / (1 + 2 * theta)) * m2 ** (-exponent_l / Omega)
        
        input_integral_outer[np.isnan(input_integral_outer)] = 0
        input_uhat_inner = H ** ((lambda_ - (alpha + (lambda_ + gamma1 / ksi - (1 - mu)) * theta) / (1 + 2 * theta)) / (khi / Omega + (1 + theta) / (1 + 2 * theta))) * \
                            tau[:, t] ** (1 / ((khi / Omega + (1 + theta) / (1 + 2 * theta)) * (1 + 2 * theta))) * \
                            m2 ** (khi / (Omega * (khi / Omega + (1 + theta) / (1 + 2 * theta))))
        input_uhat_inner[H == 0] = 0

        i_exp = exponent_l / Omega - theta ** 2 / (1 + 2 * theta)
        u_exp = 1 / (khi * theta / Omega + theta * (1 + theta) / (1 + 2 * theta))

        print(f"i_exp: {i_exp}")
        print(f"u_exp: {u_exp}")
        
        # Inner loop
        while error >= 1e-2:
            uhat_old = uhat_loop.copy()
            input_integral_inner = input_integral_outer * uhat_loop ** i_exp
            input_integral_inner[uhat_loop == 0] = 0
            
            # Matrix product
            print(input_integral_inner)
            rhs = np.dot(trmult_reduced, input_integral_inner)
            eps_val = 1e-12
            rhs = np.maximum(rhs, eps_val)
            
            uhat_loop = aa2 * input_uhat_inner * rhs ** u_exp
            error = np.sum((uhat_loop - uhat_old) ** 2)
        
        uhat[:, t] = uhat_loop

        # Solve for u using equation (53)
        u[:, t] = uhat[:, t] / (lbar / np.sum(uhat[:, t] ** (1 / Omega) * m2 ** (-1 / Omega))) ** \
                  (Omega * (((1 / Omega) * (((lambda_ + (1 - mu) - gamma1 / ksi) * theta) - alpha) + theta) / theta - 1))

        # Solve for population using equation (7)
        l[:, t] = H ** -1 * u[:, t] ** (1 / Omega) * m2 ** (-1 / Omega)

        # Rescale L so that H * L sums to lbar
        l[:, t] = l[:, t] / np.sum(H * l[:, t]) * lbar
        
        # Calculate other quantities
        phi[:, t] = (gamma1 / (nu * (gamma1 + mu * ksi))) ** (1 / ksi) * l[:, t] ** (1 / ksi)
        w[:, t] = a_norm ** (-theta / (1 + 2 * theta)) * u[:, t] ** (theta / (1 + 2 * theta)) * H ** (-1 / (1 + 2 * theta)) * \
                  tau[:, t] ** (1 / (1 + 2 * theta)) * l[:, t] ** ((alpha - 1 + (lambda_ + gamma1 / ksi - (1 - mu)) * theta) / (1 + 2 * theta))
        
        # Normalize wages relative to Princeton, NJ
        w[:, t] = w[:, t] / w[3198, t]  # 3198 is the Python index for Princeton, NJ

        # Calculate real GDP per capita using equation (22)
        realgdp[:, t] = u[:, t] / a_norm * l[:, t] ** lambda_

        # Calculate trade to GDP ratio in periods 1 and T
        if t == 0 or t == T - 1:
            print('TOTAL IMPORTS TO WORLD GDP')
            trsharesum = np.dot(trmult_reduced, (tau[:, t] * l[:, t] ** (alpha - (1 - mu - gamma1 / ksi) * theta) * w[:, t] ** (-theta)))
            eps_val = 1e-12
            trsharesum = np.maximum(trsharesum, eps_val)
            domtrade = 0
            for i in range(n):
                for j in range(n):
                    if C_vect[i] == C_vect[j]:
                        domtrade += (tau[j, t] * l[j, t] ** (alpha - (1 - mu - gamma1 / ksi) * theta) * w[j, t] ** (-theta) *
                                     trmult_reduced[i, j] / trsharesum[i] * w[i, t] * H[i] * l[i, t])
            print(1 - domtrade / np.sum(w[:, t] * H * l[:, t]))
        
        # Update productivity according to equation (8)
        if t < T - 1:
            avgprod = np.sum(tau[:, t]) / n
            tau[:, t + 1] = eta * tau[:, t] ** gamma2 * avgprod ** (1 - gamma2) * phi[:, t] ** (gamma1 * theta)
    
    # Handle NaN values
    realgdp[np.isnan(realgdp)] = 0
    tau[np.isnan(tau)] = 0
    phi[np.isnan(phi)] = 0
    w[np.isnan(w)] = 0
    l[np.isnan(l)] = 0

    return l, w, u, tau, phi, realgdp
