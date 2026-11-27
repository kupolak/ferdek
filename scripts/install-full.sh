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

REPO_URL="https://github.com/kupolak/ferdek"
TEMP_DIR="/tmp/ferdek-install-$$"
rm -rf "$TEMP_DIR"

# ---------------------------------------------------------
# ETAP 0: Gotowa binarka (bez OCamla), jeśli jest dla tego systemu
# ---------------------------------------------------------
# FERDEK_ZE_ZRODEL=1 pomija binarkę i buduje ze źródeł.

BIN=""
case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) PACZKA="linux-x86_64" ;;
    Darwin-arm64) PACZKA="macos-arm64" ;;
    *) PACZKA="" ;;
esac

if [ -n "$PACZKA" ] && [ -z "$FERDEK_ZE_ZRODEL" ]; then
    echo -e "${CYAN}Pobieram gotową binarkę ($PACZKA)...${NC}"
    mkdir -p "$TEMP_DIR"
    # Binarka musi się też uruchomić: na innej libc (np. Alpine) nie ruszy i wtedy budujemy ze źródeł
    if curl -fsSL "$REPO_URL/releases/download/latest/ferdek-$PACZKA.tar.gz" | tar -xz -C "$TEMP_DIR" 2>/dev/null \
       && "$TEMP_DIR/ferdek" --help > /dev/null 2>&1; then
        BIN="$TEMP_DIR/ferdek"
        echo -e "${GREEN}✓ Jest binarka. OCaml niepotrzebny.${NC}"
    else
        echo -e "${YELLOW}Binarki nie ma albo nie działa na tym systemie. Buduję ze źródeł.${NC}"
        rm -rf "$TEMP_DIR"
    fi
    echo ""
fi

if [ -z "$BIN" ]; then
    # ---------------------------------------------------------
    # ETAP 0: Instalacja zależności (dla Alpine Linux)
    # ---------------------------------------------------------

    echo "Instaluję narzędzia... (jak w warsztacie Boczka)"

    # Sprawdź czy to Alpine Linux
    if command -v apk &> /dev/null; then
        echo -e "${CYAN}Alpine Linux wykryty! Instaluję pakiety...${NC}"
        echo -e "${YELLOW}Ferdek:${NC} 'W tym kraju trzeba mieć wszystko na miejscu!'"
    
        apk add --no-cache \
            git \
            make \
            gcc \
            g++ \
            musl-dev \
            ocaml \
            ocaml-compiler-libs \
            ocaml-runtime \
            opam \
            libx11-dev \
            m4 \
            patch \
            unzip \
            bubblewrap \
            rsync
    
        echo -e "${GREEN}✓ Pakiety zainstalowane!${NC}"
        echo ""
    
        # Inicjalizacja opam dla Alpine
        echo -e "${CYAN}Inicjalizuję opam...${NC}"
        echo -e "${YELLOW}Walduś:${NC} 'Tato, co to jest opam?'"
        echo -e "${GREEN}Ferdek:${NC} 'To jak sklepik z narzędziami, synu!'"
    
        export OPAMROOT=/root/.opam
        opam init --disable-sandboxing -y -a
        eval $(opam env)
    
        echo -e "${CYAN}Instaluję menhir...${NC}"
        opam install menhir menhirLib yojson -y
        eval $(opam env)
    
        echo -e "${GREEN}✓ Opam i menhir zainstalowane!${NC}"
        echo ""
    fi

    echo -e "${GREEN}✓ Wszystkie narzędzia są. Można zaczynać robotę.${NC}"
    echo ""

    # ---------------------------------------------------------
    # ETAP 1: Pobieranie z GitHuba (INTERNETY!)
    # ---------------------------------------------------------

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

    BIN="$TEMP_DIR/_build/default/src/ferdek.exe"
fi

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
        # Przy "curl | bash" wejściem jest sam skrypt, więc pytamy tylko w terminalu
        REPLY=n
        if [ -t 0 ]; then
            read -p "Dodać automatycznie? (t/n) " -n 1 -r
            echo
        fi
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
    sudo cp "$BIN" "$INSTALL_DIR/ferdek"
    sudo chmod +x "$INSTALL_DIR/ferdek"
else
    cp "$BIN" "$INSTALL_DIR/ferdek"
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
rm -rf "$STDLIB_DIR/KLAMOTY"
cp -r "$TEMP_DIR/stdlib/KLAMOTY" "$STDLIB_DIR/"

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
