#!/bin/bash
# Instalator zdalny dla języka Ferdek
# Pobiera z GitHub i instaluje od razu
# Wersja: GitHub Edition (bo Ferdek w XXI wieku!)

set -e

# Kolory - jak w telewizorze Rubin
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}🍺  Instalator 'Ferdek' z GitHuba  🍺${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "${YELLOW}Ferdek: 'W tym kraju trzeba mieć znajomości... albo GitHuba.'${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 0: Sprawdzenie narzędzi
# ---------------------------------------------------------

echo "Sprawdzam czy są narzędzia... (jak Boczek narzędzia sprawdza)"

# Sprawdź git
if ! command -v git &> /dev/null; then
    echo -e "${RED}A NIECH TO DUNDER ŚWIŚNIE! Nie ma gita!${NC}"
    echo -e "${YELLOW}Paździoch:${NC} 'Panie Kiepski, ja go widziałem na bazarze!'"
    echo -e "${GREEN}Ferdek:${NC} 'Nie ten git, cycu! Zainstaluj Pan: brew install git'"
    exit 1
fi

# Sprawdź make
if ! command -v make &> /dev/null; then
    echo -e "${RED}Nie ma make! Co to za gospodarstwo?!${NC}"
    echo -e "${GREEN}Ferdek:${NC} 'Zainstaluj Pan Xcode Command Line Tools!'"
    echo "  xcode-select --install"
    exit 1
fi

# Sprawdź ocamlc
if ! command -v ocamlc &> /dev/null; then
    echo -e "${RED}Nie ma OCamla! Bez tego to ja nie zacznę!${NC}"
    echo -e "${CYAN}Walduś:${NC} 'Tato, a co to jest OCaml?'"
    echo -e "${GREEN}Ferdek:${NC} 'Nie zadawaj głupich pytań! Zainstaluj opam!'"
    echo ""
    echo "Instrukcje:"
    echo "  1. Zainstaluj opam: brew install opam"
    echo "  2. Zainicjuj opam: opam init"
    echo "  3. Zainstaluj OCaml: opam switch create 4.14.0"
    echo "  4. Zainstaluj menhir: opam install menhir"
    exit 1
fi

echo -e "${GREEN}✓ Wszystkie narzędzia są. Można zaczynać robotę.${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 1: Pobieranie z GitHuba (INTERNETY!)
# ---------------------------------------------------------

REPO_URL="https://github.com/kupolak/ferdek"
TEMP_DIR="/tmp/ferdek-install-$$"

echo -e "${CYAN}Pobieram z GitHuba: $REPO_URL${NC}"
echo -e "${YELLOW}Babka:${NC} 'A co to za internety?'"
echo -e "${GREEN}Ferdek:${NC} 'Cicho bądź, Babka! XXI wiek na dworze!'"
echo ""

# Usuń poprzedni katalog tymczasowy jeśli istnieje
rm -rf "$TEMP_DIR"

# Sklonuj repozytorium
git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}Nie udało się pobrać! Internet się zepsuł!${NC}"
    echo -e "${YELLOW}Paździoch:${NC} 'Może Koziołek Matołek kabel przeciął?'"
    exit 1
fi

echo -e "${GREEN}✓ Pobrano z GitHuba!${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 2: Kompilacja (CIĘŻKA PRACA)
# ---------------------------------------------------------

echo -e "${CYAN}Kompilacja... (robota jak w kopalni)${NC}"
echo -e "${GREEN}Ferdek:${NC} 'Walduś, przynieś ojcu piwo, bo będzie się męczył!'"
echo ""

cd "$TEMP_DIR"

# Kompiluj projekt
make clean
make

if [ $? -ne 0 ]; then
    echo -e "${RED}Kompilacja się nie powiodła!${NC}"
    echo -e "${YELLOW}Boczek:${NC} 'Panie Ferdku, może ja coś zepsuł?'"
    echo -e "${GREEN}Ferdek:${NC} 'Ty zawsze coś psujesz, Boczek!'"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✓ Skompilowano!${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 3: Wybór katalogu instalacji
# ---------------------------------------------------------

if [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
    NEED_SUDO=false
    echo "Instalujemy w /usr/local/bin. Luksusowo, jak u Krawczyka."
elif [ "$EUID" -eq 0 ]; then
    INSTALL_DIR="/usr/local/bin"
    NEED_SUDO=false
    echo "Jesteś Pan rootem? No, to szacunek, Panie Prezesie."
else
    INSTALL_DIR="$HOME/.local/bin"
    NEED_SUDO=false

    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Tworzę katalog: $INSTALL_DIR${NC}"
        echo -e "${CYAN}Boczek:${NC} 'Panie Ferdku, a można tu schować słoik?'"
        echo -e "${GREEN}Ferdek:${NC} 'Wypierdzielaj Pan z tym!'"
        mkdir -p "$INSTALL_DIR"
    fi

    # Sprawdź PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo -e "${YELLOW}Uwaga! Ścieżka nie jest w PATH!${NC}"
        echo "Dodaj to Pan do ~/.zshrc albo ~/.bashrc:"
        echo ""
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        read -p "Dodać automatycznie? (t/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[TtYy]$ ]]; then
            # Sprawdź jaki shell
            if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
                echo -e "${GREEN}Dopisano do ~/.zshrc${NC}"
            else
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                echo -e "${GREEN}Dopisano do ~/.bashrc${NC}"
            fi
        fi
    fi
fi

echo -e "Katalog instalacji: ${CYAN}$INSTALL_DIR${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 4: Instalacja
# ---------------------------------------------------------

echo "Kopiowanie plików... (Fizyczna robota)"

if [ "$NEED_SUDO" = true ]; then
    echo -e "${YELLOW}Wymagane sudo...${NC}"
    sudo cp .build/main "$INSTALL_DIR/ferdek"
    sudo chmod +x "$INSTALL_DIR/ferdek"
else
    cp .build/main "$INSTALL_DIR/ferdek"
    chmod +x "$INSTALL_DIR/ferdek"
fi

echo -e "${GREEN}✓ Zainstalowano: $INSTALL_DIR/ferdek${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 5: Kopiowanie standardowej biblioteki (KLAMOTY!)
# ---------------------------------------------------------

STDLIB_DIR="$HOME/.ferdek/stdlib"

echo -e "${CYAN}Kopiowanie KLAMOTY (standardowa biblioteka)...${NC}"
echo -e "${GREEN}Ferdek:${NC} 'Bez KLAMOTY to ja nie żyję!'"

mkdir -p "$STDLIB_DIR"
cp -r "$TEMP_DIR/stdlib/"* "$STDLIB_DIR/"

echo -e "${GREEN}✓ KLAMOTY zainstalowane w: $STDLIB_DIR${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 6: Sprzątanie
# ---------------------------------------------------------

echo "Sprzątam bałagan..."
cd /
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✓ Posprzątane!${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 7: Weryfikacja
# ---------------------------------------------------------

if command -v ferdek &> /dev/null; then
    echo -e "${GREEN}✓ ELEGANCJA FRANCJA! Komenda 'ferdek' działa!${NC}"
    echo ""
    VERSION=$(ferdek --help 2>&1 | head -1 || echo "Ferdek")
    echo -e "${CYAN}Zainstalowano: $VERSION${NC}"
    echo ""
    echo -e "${YELLOW}Babka:${NC} 'A co wy tam robicie, darmozjady?'"
    echo -e "${GREEN}Ferdek:${NC} 'Babka śpi, kod działa! Można iść na browara.'"
    echo ""
    echo "Spróbuj Pan:"
    echo "  echo 'CO JEST KURDE"
    echo "  PANIE SENSACJA REWELACJA \"Cześć, tu Ferdek!\""
    echo "  MOJA NOGA JUŻ TUTAJ NIE POSTANIE' > hello.ferdek"
    echo ""
    echo "  ferdek hello.ferdek"
else
    echo -e "${RED}Uwaga! Komenda 'ferdek' nie jest widoczna!${NC}"
    echo ""
    echo -e "${YELLOW}Babka:${NC} 'To wina Koziołka Matołka!'"
    echo -e "${GREEN}Ferdek:${NC} 'Trzeba odświeżyć terminal.'"
    echo ""
    echo "Uruchom Pan: source ~/.zshrc  (albo source ~/.bashrc)"
    echo "Lub otwórz nowe okno terminala."
fi

echo ""
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}   KONIEC ROBOTY. Pora na 'Mocnego Fulla'.   ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo ""
echo -e "${YELLOW}Dokumentacja: https://github.com/kupolak/ferdek${NC}"
echo -e "${YELLOW}Problemy? Zgłoś Issue na GitHubie!${NC}"
echo ""
