import numpy as np
import matplotlib.pyplot as plt
from maps import maps
import init
from pathlib import Path

def plots(H, realgdp_w, u_w, u2_w, prod_w, l, u, tau, realgdp):
    global m2, earth_indices, tail_bands, alpha, theta, Omega
    alpha = init.alpha
    theta = init.theta
    
    T = int(len(realgdp_w))

    # Calculate world productivity and real GDP, correlations
    prworld = prod_w
    rgdpworld = realgdp_w
    uworld = u_w
    u2world = u2_w
    prgrowth = np.zeros(T)
    rgdpgrowth = np.zeros(T)
    ugrowth = np.zeros(T)
    u2growth = np.zeros(T)
    corr_rgdppop = np.zeros((T, 2, 2))
    corr_prpop = np.zeros((T, 2, 2))
    corr_prrgdp = np.zeros((T, 2, 2))
    
    for t in range(T):
        if t > 0:
            prgrowth[t] = prworld[t] / prworld[t - 1]
            rgdpgrowth[t] = rgdpworld[t] / rgdpworld[t - 1]
            ugrowth[t] = uworld[t] / uworld[t - 1]
            u2growth[t] = u2world[t] / u2world[t - 1]

        rgdp_vector = realgdp[:, t]
        pop_vector = l[:, t]
        pr_vector = (tau[:, t] * l[:, t] ** alpha) ** (1 / theta)
        
        rgdp_vector = rgdp_vector[H > 0]
        pop_vector = pop_vector[H > 0]
        pr_vector = pr_vector[H > 0]

        corr_rgdppop[t, :, :] = np.corrcoef(np.log(rgdp_vector), np.log(pop_vector))
        corr_prpop[t, :, :] = np.corrcoef(np.log(pr_vector), np.log(pop_vector))
        corr_prrgdp[t, :, :] = np.corrcoef(np.log(pr_vector), np.log(rgdp_vector))

    # Time series plots
    fig, axs = plt.subplots(2, 3, figsize=(15, 10))

    axs[0, 0].plot(range(1, T), prgrowth[1:T])
    axs[0, 0].set_title('Growth rate of productivity')
    axs[0, 0].set_xlabel('Time')

    axs[0, 1].plot(range(1, T), rgdpgrowth[1:T])
    axs[0, 1].set_title('Growth rate of real GDP')
    axs[0, 1].set_xlabel('Time')

    axs[0, 2].plot(range(1, T), ugrowth[1:T])
    axs[0, 2].set_title('Growth rate of utility (u)')
    axs[0, 2].set_xlabel('Time')

    axs[1, 0].plot(range(T), np.log(prworld[:T]))
    axs[1, 0].set_title('Ln world average productivity')
    axs[1, 0].set_xlabel('Time')

    axs[1, 1].plot(range(T), np.log(rgdpworld[:T]))
    axs[1, 1].set_title('Ln world average real GDP')
    axs[1, 1].set_xlabel('Time')

    axs[1, 2].plot(range(T), np.log(uworld[:T]))
    axs[1, 2].set_title('Ln world utility (u)')
    axs[1, 2].set_xlabel('Time')

    plt.tight_layout()
    Path('Output').mkdir(parents=True, exist_ok=True)
    plt.savefig('Output/world_aggregates.png')
    plt.close(fig)

    # Additional Time series plots
    fig, axs = plt.subplots(2, 2, figsize=(12, 8))

    axs[0, 0].plot(range(1, T), ugrowth[1:T])
    axs[0, 0].set_title('Growth rate of utility (u)')
    axs[0, 0].set_xlabel('Time')

    axs[0, 1].plot(range(2, T), u2growth[2:T])
    axs[0, 1].set_title('Growth rate of E(u*epsilon)')
    axs[0, 1].set_xlabel('Time')

    axs[1, 0].plot(range(T), np.log(uworld[:T]))
    axs[1, 0].set_title('Ln world utility (u)')
    axs[1, 0].set_xlabel('Time')

    axs[1, 1].plot(range(T), np.log(u2world[:T]))
    axs[1, 1].set_title('Ln E(u*epsilon)')
    axs[1, 1].set_xlabel('Time')

    plt.tight_layout()
    Path('Output').mkdir(parents=True, exist_ok=True)
    plt.savefig('Output/world_utility.png')
    plt.close(fig)

    # Correlation plots
    fig, axs = plt.subplots(1, 3, figsize=(15, 5))

    axs[0].plot(corr_rgdppop[:, 0, 1])
    axs[0].set_title('Corr (log real GDP per capita, log population density)')
    axs[0].set_xlabel('Time')

    axs[1].plot(corr_prpop[:, 0, 1])
    axs[1].set_title('Corr (log productivity, log population density)')
    axs[1].set_xlabel('Time')

    axs[2].plot(corr_prrgdp[:, 0, 1])
    axs[2].set_title('Corr (log productivity, log real GDP per capita)')
    axs[2].set_xlabel('Time')

    plt.tight_layout()
    Path('Output').mkdir(parents=True, exist_ok=True)
    plt.savefig('Output/correlations.png')
    plt.close(fig)

    # Cell-level maps
    if T >= 1:
        maps(l[:, 0], u[:, 0], (tau[:, 0] * l[:, 0] ** alpha) ** (1 / theta), realgdp[:, 0], 1)
    if T >= 200:
        maps(l[:, 199], u[:, 199], (tau[:, 199] * l[:, 199] ** alpha) ** (1 / theta), realgdp[:, 199], 200)
    if T >= 600:
        maps(l[:, 599], u[:, 599], (tau[:, 599] * l[:, 599] ** alpha) ** (1 / theta), realgdp[:, 599], 600)
