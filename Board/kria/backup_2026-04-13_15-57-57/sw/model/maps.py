import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from pathlib import Path

def maps(series1, series2, series3, series4, t, earth_indices=None):
    """
    Creates 4 maps at time t.
    The series must be in order: 
    - series1: l(t)
    - series2: u(t)
    - series3: prod(t)
    - series4: realgdp(t)
    """
    if earth_indices is None:
        from init import earth_indices as _earth_indices
        earth_indices = _earth_indices

    # Take logs of variables
    series1 = np.log(series1)
    series2 = np.log(series2)
    series3 = np.log(series3)
    series4 = np.log(series4)

    # Define titles for the plots
    titles = [
        'Log population density, time {}'.format(t),
        'Log utility, time {}'.format(t),
        'Log productivity, time {}'.format(t),
        'Log real GDP per capita, time {}'.format(t)
    ]
    
    # Define title names for saving files
    title_names = ['PD', 'U', 'PR', 'RO']

    # Plot each figure
    for i, (series, title, title_name) in enumerate(zip([series1, series2, series3, series4], titles, title_names), start=1):
        plt.figure()
        
        # Create the map array
        varm = np.full((180, 360), -np.inf)
        varm.flat[earth_indices] = series
        
        # Set color limits based on the series and time
        if i == 1:
            vmin, vmax = -10, 21
        elif i == 3:
            if t == 1:
                vmin, vmax = -3, 7
            elif t == 600:
                vmin, vmax = 11, 21
            else:
                vmin, vmax = None, None
        elif i == 4:
            if t == 1:
                vmin, vmax = -4, 3
            else:
                vmin, vmax = None, None
        else:
            vmin, vmax = None, None

        # Plot the map
        plt.imshow(varm, cmap='jet', vmin=vmin, vmax=vmax)
        plt.colorbar(label='Value', orientation='vertical')
        plt.title(title)
        
        # Save the output to disk
        Path('Maps').mkdir(parents=True, exist_ok=True)
        filename = 'Maps/{}_NF_{}_1000.png'.format(title_name, t)
        plt.savefig(filename)
        plt.close()  # Close the figure to avoid memory issues
