import matplotlib.pyplot as plt
import numpy as np

# Set style for LaTeX look
plt.rcParams.update({
    "text.usetex": False,
    "font.family": "serif",
    "font.serif": ["Computer Modern Roman", "Times New Roman", "serif"],
    "font.size": 12
})

def draw_raygor():
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.set_xlim(0, 44)
    ax.set_ylim(3.2, 28)
    
    # Approximate lines for Raygor
    # Just draw some diagonal-ish lines that separate grades 3 to 17
    # For a realistic look, let's just make it a schematic
    x = np.linspace(0, 44, 100)
    
    # Just an approximation to look like the real graph
    ax.plot([6, 12], [28, 3.2], 'k-', lw=1)
    ax.plot([9, 16], [28, 3.2], 'k-', lw=1)
    ax.plot([12, 19], [28, 3.2], 'k-', lw=1)
    ax.plot([15, 24], [28, 3.2], 'k-', lw=1)
    ax.plot([19, 29], [28, 3.2], 'k-', lw=1)
    ax.plot([23, 34], [28, 3.2], 'k-', lw=1)
    ax.plot([28, 39], [28, 3.2], 'k-', lw=1)
    
    ax.set_xlabel("Liczba słów o 6 lub więcej literach na 100 słów")
    ax.set_ylabel("Liczba zdań na 100 słów")
    ax.set_title("Graf Raygora (Opracowanie własne)")
    plt.grid(True, linestyle='--', alpha=0.5)
    plt.savefig('raygor_approx.png', dpi=300, bbox_inches='tight')
    print("Generated raygor_approx.png")

draw_raygor()
