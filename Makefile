# Makefile dla języka Ferdek

OCAMLC = ocamlc
OCAMLLEX = ocamllex
MENHIR = menhir
BUILD_DIR = .build

all: $(BUILD_DIR)/ferdek $(BUILD_DIR)/ferdecc $(BUILD_DIR)/main $(BUILD_DIR)/test_lexer $(BUILD_DIR)/test_ast $(BUILD_DIR)/test_parser

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Generowanie lexera z .mll
$(BUILD_DIR)/lexer.ml: src/lexer.mll $(BUILD_DIR)/parser.cmi | $(BUILD_DIR)
	$(OCAMLLEX) -o $(BUILD_DIR)/lexer.ml src/lexer.mll

# Generowanie parsera z .mly
$(BUILD_DIR)/parser.ml $(BUILD_DIR)/parser.mli: src/parser.mly $(BUILD_DIR)/ast.cmi | $(BUILD_DIR)
	cp $(BUILD_DIR)/ast.cmi src/ && cd src && $(MENHIR) --base ../$(BUILD_DIR)/parser --infer -la 1 parser.mly && rm -f ast.cmi

# Kompilacja modułu AST
$(BUILD_DIR)/ast.cmi: src/ast.mli | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/ast.cmi -c src/ast.mli

$(BUILD_DIR)/ast.cmo: src/ast.ml $(BUILD_DIR)/ast.cmi | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/ast.cmo -c src/ast.ml

# Kompilacja interpretera
$(BUILD_DIR)/interpreter.cmi: src/interpreter.mli $(BUILD_DIR)/ast.cmi | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/interpreter.cmi -c src/interpreter.mli

$(BUILD_DIR)/interpreter.cmo: src/interpreter.ml $(BUILD_DIR)/interpreter.cmi $(BUILD_DIR)/ast.cmi | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/interpreter.cmo -c src/interpreter.ml

# Kompilacja kompilatora
$(BUILD_DIR)/compiler.cmi: src/compiler.mli $(BUILD_DIR)/ast.cmi | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/compiler.cmi -c src/compiler.mli

$(BUILD_DIR)/compiler.cmo: src/compiler.ml $(BUILD_DIR)/compiler.cmi $(BUILD_DIR)/ast.cmi | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/compiler.cmo -c src/compiler.ml

# Kompilacja interfejsu parsera
$(BUILD_DIR)/parser.cmi: $(BUILD_DIR)/parser.mli
	$(OCAMLC) -I src -I $(BUILD_DIR) -c $(BUILD_DIR)/parser.mli

# Kompilacja parsera
$(BUILD_DIR)/parser.cmo: $(BUILD_DIR)/parser.ml $(BUILD_DIR)/parser.cmi
	$(OCAMLC) -I src -I $(BUILD_DIR) -c $(BUILD_DIR)/parser.ml

# Kompilacja lexera
$(BUILD_DIR)/lexer.cmo: $(BUILD_DIR)/lexer.ml $(BUILD_DIR)/parser.cmi
	$(OCAMLC) -I src -I $(BUILD_DIR) -c $(BUILD_DIR)/lexer.ml

# Kompilacja programu testowego lexera
$(BUILD_DIR)/test_lexer: $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo tests/test_lexer.ml | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/test_lexer $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo tests/test_lexer.ml

# Kompilacja programu testowego AST
$(BUILD_DIR)/test_ast: $(BUILD_DIR)/ast.cmo tests/test_ast.ml | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/test_ast $(BUILD_DIR)/ast.cmo tests/test_ast.ml

# Kompilacja programu testowego parsera
$(BUILD_DIR)/test_parser: $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo tests/test_parser.ml | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/test_parser $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo tests/test_parser.ml

# Kompilacja głównego interpretera
$(BUILD_DIR)/ferdek.cmo: src/ferdek.ml $(BUILD_DIR)/ast.cmi $(BUILD_DIR)/parser.cmi $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/interpreter.cmi | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/ferdek.cmo -c src/ferdek.ml

$(BUILD_DIR)/ferdek: $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/interpreter.cmo $(BUILD_DIR)/ferdek.cmo | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/ferdek $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/interpreter.cmo $(BUILD_DIR)/ferdek.cmo

# Kompilacja kompilatora Ferdek->C
$(BUILD_DIR)/ferdecc.cmo: src/ferdecc.ml $(BUILD_DIR)/ast.cmi $(BUILD_DIR)/parser.cmi $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/compiler.cmi | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/ferdecc.cmo -c src/ferdecc.ml

$(BUILD_DIR)/ferdecc: $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/compiler.cmo $(BUILD_DIR)/ferdecc.cmo | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/ferdecc $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/compiler.cmo $(BUILD_DIR)/ferdecc.cmo

# Kompilacja głównej komendy CLI
$(BUILD_DIR)/main.cmo: src/main.ml $(BUILD_DIR)/ast.cmi $(BUILD_DIR)/parser.cmi $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/interpreter.cmi $(BUILD_DIR)/compiler.cmi | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/main.cmo -c src/main.ml

$(BUILD_DIR)/main: $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/interpreter.cmo $(BUILD_DIR)/compiler.cmo $(BUILD_DIR)/main.cmo | $(BUILD_DIR)
	$(OCAMLC) -I src -I $(BUILD_DIR) -o $(BUILD_DIR)/main $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/interpreter.cmo $(BUILD_DIR)/compiler.cmo $(BUILD_DIR)/main.cmo

# Czyszczenie plików pośrednich
clean:
	rm -rf $(BUILD_DIR)
	rm -f *.cmi *.cmo *.cmx *.o *.c
	rm -f src/*.cmi src/*.cmo src/*.cmx src/*.o
	rm -f tests/*.cmi tests/*.cmo tests/*.cmx tests/*.o
	rm -f test_lexer test_ast test_parser ferdek ferdecc
	rm -f examples/*.c examples/test_interpreter examples/functions examples/arrays examples/fizzbuzz examples/simple_compile
	rm -f pomysl pomysl.c

# Czyszczenie wszystkiego (włącznie z testami)
distclean: clean
	rm -f *.conflicts

# Test
test: $(BUILD_DIR)/test_lexer $(BUILD_DIR)/test_ast $(BUILD_DIR)/test_parser
	@echo "=== Test lexera ==="
	$(BUILD_DIR)/test_lexer
	@echo ""
	@echo "=== Test AST ==="
	$(BUILD_DIR)/test_ast
	@echo ""
	@echo "=== Test parsera ==="
	$(BUILD_DIR)/test_parser

# Test z przykładowymi plikami
test-examples: $(BUILD_DIR)/test_lexer
	@echo "=== Test: Hello World ==="
	@echo 'CO JEST KURDE\nPANIE SENSACJA REWELACJA "Cześć!"\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE' | $(BUILD_DIR)/test_lexer

.PHONY: all clean distclean test test-examples
