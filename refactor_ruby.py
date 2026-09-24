import sys

def r(path, old, new):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

p = '/Users/kupolak/Desktop/praca_inzynierska_tex/ch6_implementacja.tex'

rix_old = """def self.rix(text)
  sentences = sentence_count(text)
  return 0.0 if sentences.zero?
  long_words = lexicon_count(text, remove_punctuation: true) { |w| w.length >= 7 }
  rix = long_words.to_f / sentences
  rix.round(2)
end"""

rix_new = """def self.rix(text)
  sentences = sentence_count(text)
  return 0.0 if sentences.zero?
 
  words = word_list(text)
  long_words = words.count { |word| word.gsub(/[^\p{L}]/, '').length >= 7 }
  rix = long_words.to_f / sentences
  rix.round(2)
end"""

pisarek_old = """def self.pisarek(text)
  ts = avg_sentence_length(text)
  return 0.0 if ts.zero?
  words = lexicon_count(text, remove_punctuation: true)
  return 0.0 if words.zero?
  
  hard_words = lexicon_count(text, remove_punctuation: true) { |w| syllable_count(w) >= 4 }
  tw = (hard_words.to_f / words) * 100.0
  t = Math.sqrt(ts**2 + tw**2) / 2.0
  t.round(2)
end"""

pisarek_new = """def self.pisarek(text)
  ts = avg_sentence_length(text)
  return 0.0 if ts.zero?
 
  words = word_list(text)
  return 0.0 if words.empty?
 
  hard_words = words.count { |word| syllable_count(word) >= 4 }
  tw = 100.0 * hard_words / words.count
  t = Math.sqrt(ts**2 + tw**2) / 2.0
  t.round(2)
end"""

r(p, rix_old, rix_new)
r(p, pisarek_old, pisarek_new)
print("Ruby code refactored.")
