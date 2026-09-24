import matplotlib.pyplot as plt
import numpy as np

# Set style for LaTeX look
plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["Computer Modern Roman", "Times New Roman", "serif"],
    "font.size": 12,
    "axes.grid": True,
    "grid.alpha": 0.3,
    "grid.linestyle": "--"
})

def plot_rys4():
    labels = ['Flesch-Kincaid', 'Coleman-Liau', 'SMOG', 'Gunning FOG', 'Linsear Write', 'Dale-Chall', 'FORCAST', 'Powers-S-K', 'SPACHE', 'ARI']
    fw = [14.80, 12.07, 13.40, 17.88, 7.43, 9.00, 9.40, 7.08, 7.82, 19.40]
    pd = [5.70, 6.59, 8.40, 8.39, 7.00, 5.39, 7.60, 4.77, 3.54, 5.80]

    x = np.arange(len(labels))
    width = 0.35

    fig, ax = plt.subplots(figsize=(10, 6))
    rects1 = ax.bar(x - width/2, pd, width, label='A Bear Called Paddington', color='#2ca02c')
    rects2 = ax.bar(x + width/2, fw, width, label='Finnegans Wake', color='#d62728')

    ax.set_ylabel('Poziom klasy (Grade Level)')
    ax.set_title('Wyniki indeksów w poziomach klas szkoły amerykańskiej')
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=45, ha='right')
    ax.legend()
    plt.tight_layout()
    plt.savefig('rys4_wykres_wyniki.png', dpi=300)

def plot_rys5():
    labels = ['A Bear Called Paddington', 'Finnegans Wake']
    values = [6.3, 22.8]

    fig, ax = plt.subplots(figsize=(6, 5))
    ax.bar(labels, values, color=['#2ca02c', '#d62728'], width=0.5)
    
    ax.set_ylabel('Odsetek trudnych słów [%]')
    ax.set_title('Porównanie odsetka trudnych słów')
    for i, v in enumerate(values):
        ax.text(i, v + 0.5, f"{v}%", ha='center', fontweight='bold')
    plt.tight_layout()
    plt.savefig('rys5_wykres_trudne_slowa.png', dpi=300)

def plot_rys6():
    labels = ['A Bear Called Paddington', 'Finnegans Wake']
    values = [15.3, 35.6]

    fig, ax = plt.subplots(figsize=(6, 5))
    ax.bar(labels, values, color=['#1f77b4', '#ff7f0e'], width=0.5)
    
    ax.set_ylabel('Średnia długość zdania [liczba słów]')
    ax.set_title('Porównanie średniej długości zdania (ASL)')
    for i, v in enumerate(values):
        ax.text(i, v + 0.5, str(v), ha='center', fontweight='bold')
    plt.tight_layout()
    plt.savefig('rys6_wykres_dlugosc_zdan.png', dpi=300)

def plot_rys9():
    labels = ['1. Bajka', '2. Lit. dziecięca', '3. Klasyka', '4. Pow. przygodowa', '5. Art. popularnonauk.', 
              '6. Esej', '7. Proza społeczna', '8. Hasło encykl.', '9. Tekst prawny', '10. Art. naukowy']
    
    fk = [5.2, 7.3, 9.1, 34.5, 15.9, 24.1, 12.7, 22.4, 37.2, 27.1]
    fog = [6.7, 9.0, 11.2, 37.9, 20.5, 27.8, 16.5, 24.7, 41.7, 35.3]
    cl = [6.5, 7.1, 11.7, 9.5, 19.2, 24.5, 8.4, 24.9, 15.1, 33.8]

    x = np.arange(len(labels))
    width = 0.25

    fig, ax = plt.subplots(figsize=(12, 6))
    ax.bar(x - width, fk, width, label='Flesch-Kincaid (sylabowy)', color='#1f77b4')
    ax.bar(x, fog, width, label='Gunning FOG (sylabowy)', color='#ff7f0e')
    ax.bar(x + width, cl, width, label='Coleman-Liau (znakowy)', color='#2ca02c')

    ax.set_ylabel('Poziom trudności (Grade Level)')
    ax.set_title('Wartości metryk czytelności na korpusie 10 tekstów testowych')
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=45, ha='right')
    ax.legend()
    plt.tight_layout()
    plt.savefig('rys9_korpus_walidacja.png', dpi=300)

plot_rys4()
plot_rys5()
plot_rys6()
plot_rys9()
print("All plots generated.")
