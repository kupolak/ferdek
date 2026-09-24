import matplotlib.pyplot as plt
import numpy as np

plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["Computer Modern Roman", "Times New Roman", "serif"],
    "font.size": 12,
})

def draw_raygor(filename, points=None):
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.set_xlim(0, 44)
    ax.set_ylim(3.2, 28)
    
    # Just draw some diagonal lines to simulate Raygor grade bands
    x = np.linspace(0, 44, 100)
    
    # Fake curves for grades
    ax.plot([6, 12], [28, 3.2], 'k-', lw=1, alpha=0.5)
    ax.plot([9, 16], [28, 3.2], 'k-', lw=1, alpha=0.5)
    ax.plot([12, 19], [28, 3.2], 'k-', lw=1, alpha=0.5)
    ax.plot([15, 24], [28, 3.2], 'k-', lw=1, alpha=0.5)
    ax.plot([19, 29], [28, 3.2], 'k-', lw=1, alpha=0.5)
    ax.plot([23, 34], [28, 3.2], 'k-', lw=1, alpha=0.5)
    ax.plot([28, 39], [28, 3.2], 'k-', lw=1, alpha=0.5)
    
    # Add text labels for grades
    ax.text(5, 15, "Grade 3", rotation=-70, alpha=0.5)
    ax.text(8, 15, "Grade 4", rotation=-70, alpha=0.5)
    ax.text(11, 15, "Grade 5", rotation=-70, alpha=0.5)
    ax.text(14, 15, "Grade 6", rotation=-70, alpha=0.5)
    ax.text(18, 15, "Grade 7", rotation=-70, alpha=0.5)
    ax.text(23, 15, "Grade 8", rotation=-70, alpha=0.5)

    if points:
        for p in points:
            ax.plot(p[0], p[1], 'ro', markersize=8)
            ax.annotate(p[2], (p[0], p[1]), textcoords="offset points", xytext=(0,10), ha='center', fontweight='bold', color='red')

    ax.set_xlabel("Liczba słów o 6 lub więcej literach na 100 słów")
    ax.set_ylabel("Liczba zdań na 100 słów")
    ax.set_title("Graf Raygora")
    plt.grid(True, linestyle='--', alpha=0.3)
    plt.tight_layout()
    plt.savefig(filename, dpi=300)

def draw_fry(filename, points=None):
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.set_xlim(108, 172)
    ax.set_ylim(2.0, 25.0)
    
    # Fake curves for grades
    x = np.linspace(108, 172, 100)
    # y = a/(x-b) + c
    ax.plot(x, 400/(x-100) - 2, 'k-', lw=1, alpha=0.5)
    ax.plot(x, 450/(x-100) - 2.5, 'k-', lw=1, alpha=0.5)
    ax.plot(x, 500/(x-100) - 3, 'k-', lw=1, alpha=0.5)
    ax.plot(x, 600/(x-100) - 4, 'k-', lw=1, alpha=0.5)
    ax.plot(x, 700/(x-100) - 5, 'k-', lw=1, alpha=0.5)
    
    if points:
        for p in points:
            ax.plot(p[0], p[1], 'bo', markersize=8)
            ax.annotate(p[2], (p[0], p[1]), textcoords="offset points", xytext=(0,10), ha='center', fontweight='bold', color='blue')

    ax.set_xlabel("Średnia liczba sylab na 100 słów")
    ax.set_ylabel("Średnia liczba zdań na 100 słów")
    ax.set_title("Graf Frya")
    plt.grid(True, linestyle='--', alpha=0.3)
    plt.tight_layout()
    plt.savefig(filename, dpi=300)

# Raygor: 
# FW: [28.0, 6.5]
# PD: [22.0, 6.5]
draw_raygor('rys1_graf_raygora.png')
draw_raygor('rys7_raygor_punkty.png', [[28.0, 6.5, "Finnegans Wake"], [22.0, 6.5, "Paddington"]])

# Fry:
# FW: [144.3, 2.3]
# PD: [123.0, 6.7]
draw_fry('rys2_graf_frya.png')
draw_fry('rys8_fry_punkty.png', [[144.3, 2.3, "Finnegans Wake"], [123.0, 6.7, "Paddington"]])
