#!/bin/bash
# Szybki instalator Ferdek - dla leniwych (jak Ferdek)
# Użycie: curl -fsSL https://raw.githubusercontent.com/kupolak/ferdek/main/scripts/quick-install.sh | bash

set -e

# Pobierz pełny skrypt instalacyjny
curl -fsSL https://raw.githubusercontent.com/kupolak/ferdek/main/scripts/install-remote.sh | bash
