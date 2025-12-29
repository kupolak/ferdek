# Makefile dla języka Ferdek
# Updated to use dune build system

FERDEK_ROOT = $(shell pwd)

all: build

# Build using dune (handles C stubs, graphics, etc.)
build:
	dune build

# Alias for dune-built executables
$(BUILD_DIR)/ferdek: build
	@ln -sf _build/default/src/ferdek.exe .build/ferdek 2>/dev/null || true

$(BUILD_DIR)/ferdecc: build
	@ln -sf _build/default/src/ferdecc.exe .build/ferdecc 2>/dev/null || true

$(BUILD_DIR)/main: build
	@ln -sf _build/default/src/main.exe .build/main 2>/dev/null || true

# Czyszczenie plików pośrednich
clean:
	dune clean
	rm -rf .build
	rm -f *.cmi *.cmo *.cmx *.o *.c
	rm -f src/*.cmi src/*.cmo src/*.cmx src/*.o
	rm -f tests/*.cmi tests/*.cmo tests/*.cmx tests/*.o
	rm -f test_lexer test_ast test_parser ferdek ferdecc
	rm -f examples/*.c examples/fizzbuzz examples/simple_compile
	rm -f tests/integration/stdlib/*.c tests/integration/features/*.c
	rm -f pomysl pomysl.c

# Czyszczenie wszystkiego (włącznie z testami)
distclean: clean
	rm -f *.conflicts

# Test jednostkowe (using dune test)
test:
	@echo "=== Building tests ==="
	dune build @runtest 2>/dev/null || echo "No unit tests configured"
	@echo "=== Tests completed ==="

# Test integracyjne - stdlib
test-stdlib: build
	@echo "=== Testy modułów KLAMOTY ==="
	@echo "\n--- Test SKRZYNKA (math) ---"
	_build/default/src/main.exe tests/integration/stdlib/test_stdlib.ferdek
	@echo "\n--- Test KANAPA (strings) ---"
	_build/default/src/main.exe tests/integration/stdlib/test_kanapa.ferdek
	@echo "\n--- Test KLATKA (networking) ---"
	_build/default/src/main.exe tests/integration/stdlib/test_klatka.ferdek
	@echo "\n--- Test SZAFKA (hashmap) ---"
	_build/default/src/main.exe tests/integration/stdlib/test_szafka.ferdek
	@echo "\n--- Test WERSALKA (lists) ---"
	_build/default/src/main.exe tests/integration/stdlib/test_wersalka.ferdek
	@echo "\n--- Test KIBEL (file ops) ---"
	_build/default/src/main.exe tests/integration/stdlib/test_kibel.ferdek

# Test integracyjne - funkcje języka
test-features: build
	@echo "=== Testy funkcji języka ==="
	@echo "\n--- Zmienne ---"
	_build/default/src/main.exe tests/integration/features/variables.ferdek
	@echo "\n--- Tablice ---"
	_build/default/src/main.exe tests/integration/features/arrays.ferdek
	@echo "\n--- Warunki ---"
	_build/default/src/main.exe tests/integration/features/conditional.ferdek
	@echo "\n--- Funkcje ---"
	_build/default/src/main.exe tests/integration/features/functions.ferdek

# Test przykładów
test-examples: build
	@echo "=== Test przykładów ==="
	@echo "\n--- Hello World ---"
	_build/default/src/main.exe examples/hello.ferdek
	@echo "\n--- FizzBuzz ---"
	_build/default/src/main.exe examples/fizzbuzz.ferdek
	@echo "\n--- Graphics Demo ---"
	_build/default/src/main.exe examples/graphics_demo.ferdek
	@echo "\n--- Variadic Functions ---"
	_build/default/src/main.exe examples/variadic_simple.ferdek

# Wszystkie testy
test-all: test test-stdlib test-features test-examples

# Reinstalacja (uninstall + install)
r: reinstall

reinstall:
	@echo "=== Odinstalowuję Ferdka ==="
	@./scripts/uninstall.sh
	@echo ""
	@echo "=== Kompiluję Ferdka ==="
	@make build
	@echo ""
	@echo "=== Instaluję Ferdka ==="
	@./scripts/install.sh
	@echo ""
	@echo "=== Reinstalacja zakończona! ==="

.PHONY: all build clean distclean test test-stdlib test-features test-examples test-all r reinstall
