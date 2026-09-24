# Makefile dla języka Ferdek
# Updated to use dune build system

FERDEK_ROOT = $(shell pwd)

all: build

# Build using dune (handles C stubs, graphics, etc.)
build:
	dune build
	@mkdir -p .build
	@ln -sf _build/default/src/ferdek.exe .build/ferdek 2>/dev/null || true

# Create local symlinks to executables (convenience)
link: build
	@mkdir -p .build
	@ln -sf _build/default/src/ferdek.exe .build/ferdek 2>/dev/null || true

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
	rm -f test_lexer test_ast test_parser ferdek
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
	fizzbuzz framebuffer function_pointers hello io macros_demo makra_ferdek memory operations pointers \
	selection_sort simple_compile structs types unions variadic variadic_simple)
ALL_TESTS = $(STDLIB_TESTS) $(FEATURE_TESTS) $(EXAMPLE_TESTS)

# Testy, które kompilator do C musi przejść z identycznym wyjściem
COMPILED_TESTS = $(addprefix examples/,advanced_features arrays2d bitwise bubble_sort classes enums fizzbuzz framebuffer function_pointers hello io memory operations pointers selection_sort simple_compile structs types unions variadic variadic_simple) \
	$(FEATURE_TESTS) \
	$(addprefix tests/integration/stdlib/,test_bez_ogonkow test_dodaj_inline test_kanapa test_kanapa_brzegi test_kanapa_litery test_kanapa_utf8 test_kibel test_klatka_bezpieczna test_losowanie test_simple_skrzynka test_skrzynka test_skrzynka_matma test_stdlib test_szafka test_szafka_pelna test_wersalka test_wersalka_funkcje) \
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
test: test-unit test-repl test-errors test-check test-docs test-runner test-fmt test-lsp test-tutorial test-debug test-dap test-runtime
	$(call run_ferdek,$(ALL_TESTS))
	$(call run_compiled,$(COMPILED_TESTS))

# Czas: interpreter vs skompilowany C (bench/*.ferdek), wyniki muszą się zgadzać
bench: build
	python3 scripts/bench.py

# Losowe programy: interpreter i skompilowany C muszą dać identyczne wyjście (make test-fuzz FUZZ_COUNT=100)
FUZZ_COUNT ?= 20
FUZZ_SEED ?= 2026
test-fuzz: build
	python3 scripts/fuzz_parity.py $(FUZZ_COUNT) $(FUZZ_SEED)

# ferdek --fmt: dla każdego programu w repo formatowanie nie zmienia AST i jest stabilne
FMT_FILES = $(wildcard examples/*.ferdek tests/integration/*/*.ferdek tests/integration/features/moduly/*.ferdek \
	stdlib/KLAMOTY/*.ferdek stdlib/KLAMOTY/BABKA/*.ferdek tests/errors/*.ferdek tests/check/*.ferdek tests/ferdek_test/*/*.ferdek)
test-fmt: build
	@fail=0; for f in $(FMT_FILES); do $(FERDEK) --fmt-check $$f || fail=$$((fail+1)); done; \
	[ $$fail -eq 0 ] && echo "--- ferdek --fmt: OK" || { echo "Padło testów formattera: $$fail"; exit 1; }

# ferdek test: katalog z dobrymi testami przechodzi, z oblanym - kończy się błędem
test-runner: build
	@$(FERDEK) test tests/ferdek_test/dobre > _build/ferdek_runner.log 2>&1 || { cat _build/ferdek_runner.log; exit 1; }
	@! $(FERDEK) test tests/ferdek_test/zle > _build/ferdek_runner.log 2>&1 || { echo "ferdek test nie wykrył oblanego testu"; exit 1; }
	@echo "--- ferdek test: OK"
	@rm -rf _build/nowy_projekt && cd _build && $(FERDEK_ROOT)/$(FERDEK) nowy nowy_projekt > /dev/null \
	  && cd nowy_projekt && $(FERDEK_ROOT)/$(FERDEK) nowy_projekt.ferdek | grep -q "to jest Ferdek" \
	  && $(FERDEK_ROOT)/$(FERDEK) test > /dev/null && echo "--- ferdek nowy: OK"

# docs/JEZYK.md i opisy słów muszą nadążać za lekserem
test-docs:
	@python3 scripts/gen_keywords.py --check && echo "--- docs/JEZYK.md: OK"

# Słownik języka + gramatyka i podpowiedzi dla VS Code (jeśli obok leży ferdek-vscode)
docs: build
	python3 scripts/gen_keywords.py $(wildcard ferdek-vscode)

# ferdek --check: poprawne programy przechodzą (pilnuje też rejestru builtinów),
# a tests/check/*.ferdek zgłaszają dokładnie oczekiwane problemy
test-check: build
	@fail=0; for t in $(ALL_TESTS) $(basename $(wildcard examples/*.ferdek)); do \
	  $(FERDEK) --check $$t.ferdek > _build/ferdek_chk.out 2>&1 || { echo "--- check $$t: FAIL"; cat _build/ferdek_chk.out; fail=$$((fail+1)); }; \
	done; \
	for t in $(basename $(wildcard tests/check/*.ferdek)); do \
	  printf -- "--- check %s: " $$t; \
	  if $(FERDEK) --check $$t.ferdek > _build/ferdek_chk.out 2>&1; then echo "FAIL (nic nie znalazł)"; fail=$$((fail+1)); \
	  elif ! diff -u $$t.out _build/ferdek_chk.out; then echo "FAIL (inne problemy)"; fail=$$((fail+1)); \
	  else echo OK; fi; \
	done; [ $$fail -eq 0 ] && echo "--- check wszystkich programów: OK" || { echo "Padło testów checkera: $$fail"; exit 1; }

# Programy, które MUSZĄ paść z konkretnym komunikatem i pozycją - w interpreterze i po kompilacji
test-errors: build
	@fail=0; for t in $(basename $(wildcard tests/errors/*.ferdek)); do \
	  for mode in "" "-r"; do \
	    printf -- "--- błąd %s %s: " "$$mode" $$t; \
	    if $(FERDEK) $$mode $$t.ferdek > _build/ferdek_err.out 2>&1; then echo "FAIL (nie padło)"; fail=$$((fail+1)); \
	    elif ! diff -u $$t.out _build/ferdek_err.out; then echo "FAIL (inny komunikat)"; fail=$$((fail+1)); \
	    else echo OK; fi; \
	  done; \
	done; [ $$fail -eq 0 ] || { echo "Padło testów błędów: $$fail"; exit 1; }

# Sesja REPL: stan między liniami, instrukcje wieloliniowe, błędy nie kończą sesji
test-repl: build
	@$(FERDEK) --repl < tests/repl/session.in 2>&1 | diff -u tests/repl/session.out - && echo "--- REPL: OK"

# Runtime programów C (src/compiler/runtime/*.c, sklejone przez dune w runtime.c) kompiluje się bez ostrzeżeń; source_line dopisuje
# dopiero wygenerowany program - tu zaślepka
test-runtime:
	@dune build src/compiler/runtime.c && { cat _build/default/src/compiler/runtime.c; echo 'static const char* source_line(const char* f, int l) { (void)f; (void)l; return 0; }'; } > _build/runtime_check.c
	@cc -std=c99 -fsyntax-only -Wall -Wextra -Wno-unused-parameter -Werror _build/runtime_check.c && echo "--- runtime.c: bez ostrzeżeń"

# Debugger dla edytorów (DAP): punkt zatrzymania, stos, zmienne, krok, wyjście programu
test-dap: build
	python3 scripts/test_dap.py $(FERDEK)

# Debugger: zapisana sesja poleceń (krok, wejście do funkcji, zmienne, punkt zatrzymania...)
test-debug: build
	@$(FERDEK) --debug tests/debug/program.ferdek < tests/debug/session.in 2>&1 | diff -u tests/debug/session.out - && echo "--- debugger: OK"

test-compiled: build
	$(call run_compiled,$(COMPILED_TESTS))

# Samouczek: każdy program z docs/SAMOUCZEK.md daje wypisany pod nim wynik (w obu trybach)
test-tutorial: build
	python3 scripts/test_tutorial.py $(FERDEK)

# Serwer LSP: definicje, użycia, zmiana nazwy
test-lsp: build
	python3 scripts/test_lsp.py $(FERDEK)

# Plac zabaw w przeglądarce (wymaga: opam install js_of_ocaml js_of_ocaml-compiler).
# Gotowa strona w _build/playground/ - index.html + ferdek_web.js, wystarczy dowolny serwer plików.
playground:
	dune build --profile release ./playground/ferdek_web.bc.js
	rm -rf _build/playground && mkdir -p _build/playground
	cp _build/default/playground/ferdek_web.bc.js _build/playground/ferdek_web.js
	{ printf '<!doctype html>\n<html lang="pl">\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'; cat playground/index.html; } > _build/playground/index.html
	@echo "--- plac zabaw: _build/playground (np. python3 -m http.server -d _build/playground)"

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

.PHONY: playground all build clean distclean test test-unit test-repl test-errors test-check test-docs test-runner test-fmt test-lsp test-tutorial test-debug test-dap test-runtime docs test-compiled test-fuzz bench test-network update-expected test-stdlib test-features test-examples test-all link install r reinstall
