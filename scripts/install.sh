#!/bin/bash
# Installer dla języka Ferdek
# Wersja: Ostateczna (chyba że Halina każe poprawić)

set -e

# Kolory - jak w telewizorze Rubin
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (Szaro, buro i ponuro)

echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}🍺  Instalator 'Ferdek' - Język Programowania Przyszłości  🍺${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "${YELLOW}Ferdek: 'W tym kraju nie ma pracy dla ludzi z moim wykształceniem... to chociaż se zainstaluję.'${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 1: Sprawdzenie pliku (PAŹDZIOCH i WALDUŚ)
# ---------------------------------------------------------

if [ ! -f ".build/main" ]; then
    echo -e "${RED}A NIECH TO DUNDER ŚWIŚNIE! BŁĄD!${NC}"
    echo "Nie ma pliku '.build/main'!"
    echo -e "${YELLOW}Paździoch:${NC} 'Panie Kiepski, ja nic nie brałem! To pomówienia!'"
    echo -e "${GREEN}Ferdek:${NC} 'Menda jedna... na pewno ukradł i opchnął na bazarze!'"
    echo -e "${CYAN}Walduś:${NC} 'Tato, a po co w ogóle jest ten plik?'"
    echo -e "${GREEN}Ferdek:${NC} 'Nie zadawaj głupich pytań, cycu! Odpalaj MAKE i nie denerwuj ojca!'"
    exit 1
fi

# ---------------------------------------------------------
# ETAP 2: Wybór katalogu (WALKA KLAS: SUDO vs LOCAL)
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
    # Jeśli nie ma praw do /usr/local/bin
    INSTALL_DIR="$HOME/.local/bin"
    NEED_SUDO=false
    
    # ---------------------------------------------------------
    # ETAP 3: Tworzenie katalogu (BOCZEK)
    # ---------------------------------------------------------
    
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Tworzę katalog: $INSTALL_DIR${NC}"
        echo -e "${CYAN}Boczek:${NC} 'Panie Ferdku, a można tu schować słoik z ogórkami?'"
        echo -e "${GREEN}Ferdek:${NC} 'Wypierdzielaj Pan z tym bębenem! Tu się buduje infrastrukturę!'"
        mkdir -p "$INSTALL_DIR"
    fi

    # Sprawdź czy ~/.local/bin jest w PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo -e "${YELLOW}Uwaga, Kurde! Ścieżka nie jest w PATH!${NC}"
        echo "Dodaj to Pan do ~/.zshrc albo ~/.bashrc, bo nic z tego nie będzie."
        echo ""
        echo " export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        read -p "Dodać to automatycznie? (t/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[TtYy]$ ]]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
            echo -e "${GREEN}Dopisano! Halina będzie zadowolona.${NC}"
        fi
    fi
fi

echo -e "Docelowa melina instalacji: ${CYAN}$INSTALL_DIR${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 4: Instalacja (CIĘŻKA PRACA)
# ---------------------------------------------------------

echo "Kopiowanie plików... (Fizyczna robota, brzydzę się tym)"

if [ "$NEED_SUDO" = true ]; then
    echo -e "${YELLOW}Wymagane sudo... Halinka, pożycz uprawnienia!${NC}"
    sudo cp .build/main "$INSTALL_DIR/ferdek"
    sudo chmod +x "$INSTALL_DIR/ferdek"
else
    cp .build/main "$INSTALL_DIR/ferdek"
    chmod +x "$INSTALL_DIR/ferdek"
fi

echo -e "${GREEN}✓ Zainstalowano: $INSTALL_DIR/ferdek${NC}"
echo ""

# ---------------------------------------------------------
# ETAP 5: Weryfikacja (BABKA KIEPSKA)
# ---------------------------------------------------------

if command -v ferdek &> /dev/null; then
    echo -e "${GREEN}✓ ELEGANCJA FRANCJA! Komenda 'ferdek' działa!${NC}"
    echo ""
    echo -e "${YELLOW}Babka:${NC} 'A co wy tam robicie, darmozjady?'"
    echo -e "${GREEN}Ferdek:${NC} 'Babka śpi, kod działa! Można iść na browara.'"
    echo ""
    echo "Spróbuj Pan:"
    echo " ferdek examples/hello.ferdek"
else
    echo -e "${RED}Uwaga! Komenda 'ferdek' nie jest widoczna!${NC}"
    echo ""
    echo -e "${YELLOW}Babka:${NC} 'To wina Koziołka Matołka! A żeby was pokręciło!'"
    echo -e "${GREEN}Ferdek:${NC} 'Cicho bądź, Babka! Trzeba tylko odświeżyć terminal.'"
    echo ""
    echo "Uruchom Pan: source ~/.zshrc (albo otwórz nowe okno, jak Panu wygodniej)"
fi

echo ""
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}   KONIEC ROBOTY. Pora na 'Mocnego Fulla'.   ${NC}"
echo -e "${CYAN}======================================================${NC}"
