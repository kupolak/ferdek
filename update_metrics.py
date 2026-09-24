import sys

def r(path, old, new):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

# 1. Update frontmatter, intro, summary
f_path = '/Users/kupolak/Desktop/praca_inzynierska_tex/frontmatter.tex'
r(f_path, 'czternaście metryk', 'szesnaście metryk')
r(f_path, 'czternaście algorytmów', 'szesnaście algorytmów')
r(f_path, 'czternaście najważniejszych', 'szesnaście najważniejszych')
r(f_path, 'ARI, LIX oraz', 'ARI, LIX, RIX, Pisarka oraz')
r(f_path, 'fourteen text readability', 'sixteen text readability')
r(f_path, 'ARI and LIX', 'ARI, LIX, RIX and Pisarek')

ch1 = '/Users/kupolak/Desktop/praca_inzynierska_tex/ch1_wstep.tex'
r(ch1, 'czternaście algorytmów', 'szesnaście algorytmów')
r(ch1, 'ARI, LIX i~inne', 'ARI, LIX, RIX, Pisarka i~inne')

ch8 = '/Users/kupolak/Desktop/praca_inzynierska_tex/ch8_podsumowanie.tex'
r(ch8, 'czternaście najważniejszych', 'szesnaście najważniejszych')
r(ch8, 'trzynastu metryk', 'piętnastu metryk') # 15 because 16 - 1 (graphs are separate?) wait, "pełnym pakiecie trzynastu metryk" -> 15
r(ch8, 'czternaście', 'szesnaście')

# 2. Add to ch5 (Theory)
ch5_add = r"""
\section{Indeks czytelności RIX}\label{ch5_metryki_sec:indeks_czytelno_ci_rix}
Indeks RIX (ang. \textit{Readability Index}) to uproszczona wersja indeksu LIX opracowana przez Jonathana Andersona w~1983~roku. Mierzy on czytelność na podstawie stosunku liczby słów bardzo długich do całkowitej liczby zdań \cite{bib58}. 

Wzór:
\begin{equation}
\text{RIX} = \frac{\text{Liczba słów o 7 i~więcej literach}}{\text{Liczba zdań}}
\end{equation}

\section{Indeks czytelności Pisarka}\label{ch5_metryki_sec:indeks_pisarka}
Polski wskaźnik zrozumiałości tekstu opracowany przez Walerego Pisarka w~1969~roku. Jest to jedna z~pierwszych metryk kalibrowanych bezpośrednio na tekstach polskojęzycznych, uwzględniająca specyfikę polskiej fleksji \cite{bib50}. Pisarek za słowa trudne uznał wyrazy składające się z~czterech i~więcej sylab.

Wzór:
\begin{equation}
T = \frac{\sqrt{T_s^2 + T_w^2}}{2}
\end{equation}
gdzie: $T_s$~-- średnia długość zdania w~słowach, $T_w$~-- odsetek wyrazów trudnych (o~czterech i~więcej sylabach).
"""

r('/Users/kupolak/Desktop/praca_inzynierska_tex/ch5_metryki.tex', 
  r'\section{Podsumowanie}\label{ch5_metryki_sec:podsumowanie}', 
  ch5_add + r'\section{Podsumowanie}\label{ch5_metryki_sec:podsumowanie}')

# 3. Add to ch6 (Implementation)
ch6_add = r"""
\section{Indeks czytelności RIX}\label{ch6_implementacja_sec:indeks_czytelno_ci_rix}
\begin{lstlisting}[language=Ruby, caption={Metoda rix -- indeks RIX}, label={lst:ch6_rix}]
def self.rix(text)
  sentences = sentence_count(text)
  return 0.0 if sentences.zero?
  long_words = lexicon_count(text, remove_punctuation: true) { |w| w.length >= 7 }
  rix = long_words.to_f / sentences
  rix.round(2)
end
\end{lstlisting}

\section{Indeks czytelności Pisarka}\label{ch6_implementacja_sec:indeks_pisarka}
\begin{lstlisting}[language=Ruby, caption={Metoda pisarek -- indeks Pisarka}, label={lst:ch6_pisarek}]
def self.pisarek(text)
  ts = avg_sentence_length(text)
  return 0.0 if ts.zero?
  words = lexicon_count(text, remove_punctuation: true)
  return 0.0 if words.zero?
  
  hard_words = lexicon_count(text, remove_punctuation: true) { |w| syllable_count(w) >= 4 }
  tw = (hard_words.to_f / words) * 100.0
  t = Math.sqrt(ts**2 + tw**2) / 2.0
  t.round(2)
end
\end{lstlisting}
"""

r('/Users/kupolak/Desktop/praca_inzynierska_tex/ch6_implementacja.tex', 
  r'\section{Graf Raygora}\label{ch6_implementacja_sec:graf_raygora}', 
  ch6_add + r'\section{Graf Raygora}\label{ch6_implementacja_sec:graf_raygora}')

r('/Users/kupolak/Desktop/praca_inzynierska_tex/ch6_implementacja.tex', 
  r'automated\_readability\_index, lix', 
  r'automated\_readability\_index, lix, rix, pisarek')

# 4. Update Tables in ch7
ch7 = '/Users/kupolak/Desktop/praca_inzynierska_tex/ch7_testy.tex'
r(ch7, r'LIX & 56,76 & 27,06 \\', r'LIX & 56,76 & 27,06 \\' + '\n' + r'RIX & 7,53 & 1,80 \\')
r(ch7, r'LIX & 56,76 & 27,06 \\', r'LIX & 56,76 & 27,06 \\') # wait, I already replaced it above. I should be careful.

# Update tab:korpus_wyniki
r(ch7, r'\textbf{Tekst (Próbka)} & \textbf{Ranga} & \textbf{ASL} & \textbf{ASW} & \textbf{FRE} & \textbf{FK} & \textbf{FOG} & \textbf{SMOG} & \textbf{CL} & \textbf{ARI} & \textbf{LIX} \\',
       r'\textbf{Tekst} & \textbf{R.} & \textbf{ASL} & \textbf{ASW} & \textbf{FRE} & \textbf{FK} & \textbf{FOG} & \textbf{SMOG} & \textbf{CL} & \textbf{ARI} & \textbf{LIX} & \textbf{RIX} \\')
r(ch7, r'\begin{tabularx}{\textwidth}{>{\raggedright\arraybackslash\small}X c ccccccccc}', 
       r'\begin{tabularx}{\textwidth}{>{\raggedright\arraybackslash\small}X c cccccccccc}')

# Replace each row in tab:korpus_wyniki
r(ch7, r'Bajka dla najmłodszych & 1 & 11,0 & 1,40 & 77,2 & 5,2 & 6,7 & 7,6 & 6,5 & 4,0 & 22,4 \\',
       r'Bajka dla najmłodszych & 1 & 11,0 & 1,40 & 77,2 & 5,2 & 6,7 & 7,6 & 6,5 & 4,0 & 22,4 & 1,3 \\')
r(ch7, r'Literatura dziecięca & 2 & 19,4 & 1,30 & 77,2 & 7,3 & 9,0 & 7,6 & 7,1 & 7,8 & 28,7 \\',
       r'Literatura dziecięca & 2 & 19,4 & 1,30 & 77,2 & 7,3 & 9,0 & 7,6 & 7,1 & 7,8 & 28,7 & 1,8 \\')
r(ch7, r'Klasyka młodzieżowa & 3 & 17,8 & 1,50 & 61,9 & 9,1 & 11,2 & 10,8 & 11,7 & 10,9 & 40,3 \\',
       r'Klasyka młodzieżowa & 3 & 17,8 & 1,50 & 61,9 & 9,1 & 11,2 & 10,8 & 11,7 & 10,9 & 40,3 & 4,0 \\')
r(ch7, r'Powieść przygodowa & 4 & 89,0 & 1,30 & 6,5 & 34,5 & 37,9 & 0,0 & 9,5 & 43,6 & 104,7 \\',
       r'Powieść przygodowa & 4 & 89,0 & 1,30 & 6,5 & 34,5 & 37,9 & 0,0 & 9,5 & 43,6 & 104,7 & 14,0 \\')
r(ch7, r'Artykuł popularnonaukowy & 5 & 20,3 & 2,00 & 17,0 & 15,9 & 20,5 & 17,4 & 19,2 & 17,9 & 64,7 \\',
       r'Artykuł popularnonaukowy & 5 & 20,3 & 2,00 & 17,0 & 15,9 & 20,5 & 17,4 & 19,2 & 17,9 & 64,7 & 9,0 \\')
r(ch7, r'Esej historyczny / publicystyka & 6 & 23,0 & 2,60 & $-36{,}5$ & 24,1 & 27,8 & 21,8 & 24,5 & 23,3 & 79,5 \\',
       r'Esej historyczny / publicystyka & 6 & 23,0 & 2,60 & $-36{,}5$ & 24,1 & 27,8 & 21,8 & 24,5 & 23,3 & 79,5 & 13,0 \\')
r(ch7, r'Klasyczna proza społeczna & 7 & 30,3 & 1,40 & 57,6 & 12,7 & 16,5 & 13,6 & 8,4 & 13,8 & 46,8 \\',
       r'Klasyczna proza społeczna & 7 & 30,3 & 1,40 & 57,6 & 12,7 & 16,5 & 13,6 & 8,4 & 13,8 & 46,8 & 5,0 \\')
r(ch7, r'Hasło encyklopedyczne & 8 & 21,7 & 2,50 & $-26{,}7$ & 22,4 & 24,7 & 19,9 & 24,9 & 23,2 & 74,0 \\',
       r'Hasło encyklopedyczne & 8 & 21,7 & 2,50 & $-26{,}7$ & 22,4 & 24,7 & 19,9 & 24,9 & 23,2 & 74,0 & 11,4 \\')
r(ch7, r'Tekst prawny & 9 & 84,0 & 1,70 & $-22{,}2$ & 37,2 & 41,7 & 0,0 & 15,1 & 45,6 & 115,0 \\',
       r'Tekst prawny & 9 & 84,0 & 1,70 & $-22{,}2$ & 37,2 & 41,7 & 0,0 & 15,1 & 45,6 & 115,0 & 26,0 \\')
r(ch7, r'Artykuł naukowy & 10 & 18,7 & 3,00 & $-66{,}0$ & 27,1 & 35,3 & 23,7 & 33,8 & 28,8 & 97,3 \\',
       r'Artykuł naukowy & 10 & 18,7 & 3,00 & $-66{,}0$ & 27,1 & 35,3 & 23,7 & 33,8 & 28,8 & 97,3 & 14,7 \\')

# Update tab:teksty_polskie
r(ch7, r'LIX & 45,73 & 71,96 \\', r'LIX & 45,73 & 71,96 \\' + '\n' + r'Indeks Pisarka & 8,71 & 14,67 \\')

print("Update completed.")
