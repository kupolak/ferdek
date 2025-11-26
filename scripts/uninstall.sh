#!/bin/bash
# Uninstaller dla języka Ferdek
# Operacja "Eksmisja" - czyli jak pozbyć się problemu z kamienicy

set -e

# Kolory (jak tapeta u Kiepskich - trochę wyblakłe, ale są)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}======================================================${NC}"
echo -e "${YELLOW}🗑️  Uninstaller Ferdek - Wielka Czystka w Kamienicy  🗑️${NC}"
echo -e "${RED}======================================================${NC}"
echo -e "${GREEN}Ferdek:${NC} 'No i po co to było instalować? Teraz trzeba to wywalić na zbity pysk!'"
echo -e "${CYAN}Walduś:${NC} 'Tato, ale może się jeszcze przyda?'"
echo -e "${GREEN}Ferdek:${NC} 'Walduś, nie dyskutuj z ojcem! Wynosimy śmieci!'"
echo ""

# Sprawdź możliwe lokalizacje - Gdzie ta menda się schowała?
LOCATIONS=(
    "/usr/local/bin/ferdek"
    "$HOME/.local/bin/ferdek"
)

FOUND=false

# Przeszukujemy zakamarki (jak Paździoch śmietnik)
for location in "${LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        FOUND=true
        echo -e "${YELLOW}Namierzyłem gada w: $location${NC}"
        
        # Sprawdzamy czy możemy usunąć bez krzyku
        if [ -w "$(dirname "$location")" ]; then
            rm "$location"
            echo -e "${GREEN}Ferdek:${NC} 'Wypad z baru! Usunięto: $location'"
            echo -e "${CYAN}Boczek:${NC} 'Panie Ferdku! Panie Ferdku! A mogę ja wziąć ten plik na pamiątkę?'"
            echo -e "${GREEN}Ferdek:${NC} 'Wypierdzielaj Pan mnie z tym plikiem!'"
        else
            # Jeśli trzeba sudo
            echo -e "${RED}Oho! Menda się zaparła! Trzeba wezwać posiłki (sudo)...${NC}"
            echo -e "${YELLOW}Paździoch:${NC} 'Panie! To jest bezprawie! Pan nie masz prawa mnie usuwać!'"
            sudo rm "$location"
            echo -e "${GREEN}✓ Wykopano siłą: $location${NC}"
        fi
    fi
done

# Jeśli nic nie znaleziono
if [ "$FOUND" = false ]; then
    echo ""
    echo -e "${RED}Błąd! Nie znaleziono komendy 'ferdek'.${NC}"
    echo -e "${YELLOW}Paździoch:${NC} 'Hahaha! Widzisz Pan, Panie Kiepski? Nic Pan na mnie nie masz!'"
    echo -e "${GREEN}Ferdek:${NC} 'A zasadził Panu ktoś kiedyś kopa w dupę? Nie ma pliku, to nie ma!'"
    exit 1
fi

echo ""
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}Deinstalacja zakończona! Teren czysty.${NC}"
echo -e "${YELLOW}Babka:${NC} 'I bardzo dobrze! Przynajmniej prąd nie będzie uciekał!'"
echo -e "${GREEN}Ferdek:${NC} 'No! To co, Walduś? Po browarku?'"
echo -e "${CYAN}======================================================${NC}"
