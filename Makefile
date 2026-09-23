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

# ponytail: test_klatka pominięty - wymaga internetu (make test-network)
STDLIB_TESTS = $(filter-out %test_klatka,$(basename $(wildcard tests/integration/stdlib/*.ferdek))) stdlib/KLAMOTY/BABKA/przyklad_testow
FEATURE_TESTS = $(basename $(wildcard tests/integration/features/*.ferdek))
# Pominięte: graphics_* (X11), udp_* (porty sieciowe)
EXAMPLE_TESTS = $(addprefix examples/,advanced_features arrays2d bitwise bubble_sort classes enums \
	fizzbuzz function_pointers hello io macros_demo makra_ferdek memory operations pointers \
	selection_sort simple_compile structs types unions variadic variadic_simple)
ALL_TESTS = $(STDLIB_TESTS) $(FEATURE_TESTS) $(EXAMPLE_TESTS)

# Testy, które kompilator do C musi przejść z identycznym wyjściem
COMPILED_TESTS = $(addprefix examples/,arrays2d bitwise bubble_sort enums fizzbuzz hello operations selection_sort simple_compile types variadic variadic_simple) \
	$(addprefix tests/integration/features/,arrays conditional exceptions exceptions_nested function_values functions preprocessor scopes test_interpreter variables) \
	$(addprefix tests/integration/stdlib/,test_dodaj_inline test_kanapa test_kanapa_brzegi test_simple_skrzynka test_skrzynka test_stdlib test_wersalka) \
	stdlib/KLAMOTY/BABKA/przyklad_testow

# Oczekiwane wyjście: tests/expected/<ścieżka>.out (brak pliku = sprawdzamy tylko kod wyjścia)
# Uruchamia pliki .ferdek, zlicza porażki, kończy się błędem jeśli któryś padł
run_ferdek = @fail=0; for t in $(1); do \
	  printf -- "--- %s: " $$t; exp=tests/expected/$$t.out; \
	  if ! $(FERDEK) $$t.ferdek > _build/ferdek_test.log 2>&1 < /dev/null; then \
	    echo FAIL; tail -3 _build/ferdek_test.log; fail=$$((fail+1)); \
	  elif [ -f $$exp ] && ! diff -u $$exp _build/ferdek_test.log > _build/ferdek_test.diff; then \
	    echo "FAIL (inne wyjście)"; head -20 _build/ferdek_test.diff; fail=$$((fail+1)); \
	  else echo OK; fi; \
	done; [ $$fail -eq 0 ] || { echo "Padło testów: $$fail"; exit 1; }

# Kompiluje przez C, uruchamia i porównuje z tym samym .out co interpreter
# (bez linii "Piwo dla Pana" - drukuje ją tylko interpreter)
run_compiled = @fail=0; for t in $(1); do \
	  printf -- "--- [C] %s: " $$t; \
	  if ! $(FERDEK) -c $$t.ferdek -o _build/ferdek_ct > _build/ferdek_ct.log 2>&1; then \
	    echo "FAIL (kompilacja)"; tail -3 _build/ferdek_ct.log; fail=$$((fail+1)); \
	  elif ! _build/ferdek_ct > _build/ferdek_ct.out 2>&1 < /dev/null; then \
	    echo FAIL; tail -3 _build/ferdek_ct.out; fail=$$((fail+1)); \
	  elif ! grep -v "Piwo dla Pana" tests/expected/$$t.out | diff -u - _build/ferdek_ct.out > _build/ferdek_ct.diff; then \
	    echo "FAIL (inne wyjście)"; head -20 _build/ferdek_ct.diff; fail=$$((fail+1)); \
	  else echo OK; fi; \
	done; [ $$fail -eq 0 ] || { echo "Padło testów kompilatora: $$fail"; exit 1; }

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
test: test-unit test-repl
	$(call run_ferdek,$(ALL_TESTS))
	$(call run_compiled,$(COMPILED_TESTS))

# Sesja REPL: stan między liniami, instrukcje wieloliniowe, błędy nie kończą sesji
test-repl: build
	@$(FERDEK) --repl < tests/repl/session.in 2>&1 | diff -u tests/repl/session.out - && echo "--- REPL: OK"

test-compiled: build
	$(call run_compiled,$(COMPILED_TESTS))

test-network: build
	$(call run_ferdek,tests/integration/stdlib/test_klatka)

# Nadpisuje oczekiwane wyjścia bieżącymi - przejrzyj git diff przed commitem!
# ponytail: macros_demo/makra_ferdek bez .out - wyjście zależy od platformy
update-expected: build
	@for t in $(filter-out %macros_demo %makra_ferdek,$(ALL_TESTS)); do \
	  mkdir -p tests/expected/$$(dirname $$t); \
	  $(FERDEK) $$t.ferdek > tests/expected/$$t.out 2>&1 < /dev/null; \
	done

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

.PHONY: all build clean distclean test test-unit test-repl test-compiled test-network update-expected test-stdlib test-features test-examples test-all link install r reinstall
