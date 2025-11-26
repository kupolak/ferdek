# Skrypty Instalacyjne Ferdek

## Dostępne skrypty

### 1. `install.sh` - Instalacja lokalna
Instaluje Ferdek z już sklonowanego repozytorium.

**Użycie:**
```bash
cd ferdek
make
./scripts/install.sh
```

### 2. `install-remote.sh` - Instalacja zdalna
Pobiera najnowszą wersję z GitHuba, kompiluje i instaluje.

**Użycie:**
```bash
curl -fsSL https://raw.githubusercontent.com/kupolak/ferdek/main/scripts/install-remote.sh | bash
```

**Lub lokalnie (do testowania):**
```bash
./scripts/install-remote.sh
```

### 3. `quick-install.sh` - Szybka instalacja
Alias dla `install-remote.sh` - używany jako one-liner.

**Użycie:**
```bash
curl -fsSL https://raw.githubusercontent.com/kupolak/ferdek/main/scripts/quick-install.sh | bash
```

## Testowanie przed publishem

Przed wrzuceniem na GitHuba przetestuj instalator lokalnie:

```bash
# 1. Symuluj instalację zdalną (używa lokalnych plików)
cd /tmp
bash /path/to/ferdek/scripts/install-remote.sh

# 2. Sprawdź czy działa
ferdek --help

# 3. Usuń instalację
rm ~/.local/bin/ferdek  # lub /usr/local/bin/ferdek
rm -rf ~/.ferdek
```

## Co robi instalator?

1. ✅ Sprawdza wymagane narzędzia (git, make, ocaml)
2. 📦 Klonuje repozytorium do `/tmp/ferdek-install-$$`
3. 🔨 Kompiluje projekt (`make clean && make`)
4. 📁 Wybiera katalog instalacji:
   - `/usr/local/bin` jeśli masz uprawnienia
   - `~/.local/bin` w przeciwnym razie
5. 📚 Kopiuje stdlib do `~/.ferdek/stdlib/`
6. 🗑️ Sprząta pliki tymczasowe
7. ✅ Weryfikuje instalację

## Lokalizacje plików

Po instalacji:
- **Binary**: `~/.local/bin/ferdek` lub `/usr/local/bin/ferdek`
- **Stdlib**: `~/.ferdek/stdlib/KLAMOTY/`

## Troubleshooting

### "Command not found: ferdek"
Dodaj do `~/.zshrc` lub `~/.bashrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### "git: command not found"
```bash
# macOS
brew install git

# Linux
sudo apt-get install git
```

### "ocamlc: command not found"
```bash
# macOS
brew install opam
opam init
opam switch create 4.14.0
opam install menhir

# Linux
sudo apt-get install opam
opam init
opam switch create 4.14.0
opam install menhir
```

## Rozwój

Jeśli chcesz modyfikować skrypty instalacyjne:

1. Edytuj lokalne pliki w `scripts/`
2. Testuj lokalnie (bez GitHub)
3. Commituj i pushuj na GitHub
4. Testuj zdalną instalację

**Ważne:** URL do raw skryptów:
```
https://raw.githubusercontent.com/kupolak/ferdek/main/scripts/install-remote.sh
https://raw.githubusercontent.com/kupolak/ferdek/main/scripts/quick-install.sh
```

Pamiętaj że GitHub może cache'ować raw files przez kilka minut!
