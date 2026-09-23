# Makefile dla języka Ferdek
# Updated to use dune build system

FERDEK_ROOT = $(shell pwd)

all: build

# Build using dune (handles C stubs, graphics, etc.)
build:
	dune build
	@mkdir -p .build
	@ln -sf _build/default/src/ferdek.exe .build/ferdek 2>/dev/null || true
	@ln -sf _build/default/src/ferdecc.exe .build/ferdecc 2>/dev/null || true

# Create local symlinks to executables (convenience)
link: build
	@mkdir -p .build
	@ln -sf _build/default/src/ferdek.exe .build/ferdek 2>/dev/null || true
	@ln -sf _build/default/src/ferdecc.exe .build/ferdecc 2>/dev/null || true

# Install into user's PATH using the install script
install: build
	@./scripts/install.sh

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

FERDEK = _build/default/src/ferdek.exe

STDLIB_TESTS = $(addprefix tests/integration/stdlib/,test_stdlib test_kanapa test_klatka test_szafka test_wersalka test_kibel)
FEATURE_TESTS = $(addprefix tests/integration/features/,variables arrays conditional functions)
# ponytail: graphics_demo pominięte - wymaga X11/XQuartz
EXAMPLE_TESTS = $(addprefix examples/,hello fizzbuzz variadic_simple)

# Uruchamia pliki .ferdek, zlicza porażki, kończy się błędem jeśli któryś padł
run_ferdek = @fail=0; for t in $(1); do \
	  printf -- "--- %s: " $$t; \
	  if $(FERDEK) $$t.ferdek > _build/ferdek_test.log 2>&1; then echo OK; \
	  else echo FAIL; tail -3 _build/ferdek_test.log; fail=$$((fail+1)); fi; \
	done; [ $$fail -eq 0 ] || { echo "Padło testów: $$fail"; exit 1; }

# Testy jednostkowe
test-unit:
	dune build @runtest

test-stdlib: build
	$(call run_ferdek,$(STDLIB_TESTS))

test-features: build
	$(call run_ferdek,$(FEATURE_TESTS))

test-examples: build
	$(call run_ferdek,$(EXAMPLE_TESTS))

# Wszystkie testy
test: test-unit
	$(call run_ferdek,$(STDLIB_TESTS) $(FEATURE_TESTS) $(EXAMPLE_TESTS))

test-all: test

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

.PHONY: all build clean distclean test test-unit test-stdlib test-features test-examples test-all link install r reinstall
