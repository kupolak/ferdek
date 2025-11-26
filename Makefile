# Makefile dla języka Ferdek

OCAMLC = ocamlc
OCAMLLEX = ocamllex
MENHIR = menhir

all: ferdek ferdecc test_lexer test_ast test_parser

# Generowanie lexera z .mll
src/lexer.ml: src/lexer.mll src/parser.cmi
	$(OCAMLLEX) src/lexer.mll

# Generowanie parsera z .mly
src/parser.ml src/parser.mli: src/parser.mly src/ast.cmi
	cd src && $(MENHIR) --infer -la 1 parser.mly

# Kompilacja modułu AST
src/ast.cmi: src/ast.mli
	$(OCAMLC) -I src -c src/ast.mli

src/ast.cmo: src/ast.ml src/ast.cmi
	$(OCAMLC) -I src -c src/ast.ml

# Kompilacja interpretera
src/interpreter.cmi: src/interpreter.mli src/ast.cmi
	$(OCAMLC) -I src -c src/interpreter.mli

src/interpreter.cmo: src/interpreter.ml src/interpreter.cmi src/ast.cmi
	$(OCAMLC) -I src -c src/interpreter.ml

# Kompilacja kompilatora
src/compiler.cmi: src/compiler.mli src/ast.cmi
	$(OCAMLC) -I src -c src/compiler.mli

src/compiler.cmo: src/compiler.ml src/compiler.cmi src/ast.cmi
	$(OCAMLC) -I src -c src/compiler.ml

# Kompilacja interfejsu parsera
src/parser.cmi: src/parser.mli
	$(OCAMLC) -I src -c src/parser.mli

# Kompilacja parsera
src/parser.cmo: src/parser.ml src/parser.cmi
	$(OCAMLC) -I src -c src/parser.ml

# Kompilacja lexera
src/lexer.cmo: src/lexer.ml src/parser.cmi
	$(OCAMLC) -I src -c src/lexer.ml

# Kompilacja programu testowego lexera
test_lexer: src/parser.cmo src/lexer.cmo tests/test_lexer.ml
	$(OCAMLC) -I src -o test_lexer src/parser.cmo src/lexer.cmo tests/test_lexer.ml

# Kompilacja programu testowego AST
test_ast: src/ast.cmo tests/test_ast.ml
	$(OCAMLC) -I src -o test_ast src/ast.cmo tests/test_ast.ml

# Kompilacja programu testowego parsera
test_parser: src/ast.cmo src/parser.cmo src/lexer.cmo tests/test_parser.ml
	$(OCAMLC) -I src -o test_parser src/ast.cmo src/parser.cmo src/lexer.cmo tests/test_parser.ml

# Kompilacja głównego interpretera
ferdek: src/ast.cmo src/parser.cmo src/lexer.cmo src/interpreter.cmo src/ferdek.ml
	$(OCAMLC) -I src -o ferdek src/ast.cmo src/parser.cmo src/lexer.cmo src/interpreter.cmo src/ferdek.ml

# Kompilacja kompilatora Ferdek->C
ferdecc: src/ast.cmo src/parser.cmo src/lexer.cmo src/compiler.cmo src/ferdecc.ml
	$(OCAMLC) -I src -o ferdecc src/ast.cmo src/parser.cmo src/lexer.cmo src/compiler.cmo src/ferdecc.ml

# Czyszczenie plików pośrednich
clean:
	rm -f *.cmi *.cmo *.cmx *.o *.c
	rm -f src/*.cmi src/*.cmo src/*.cmx src/*.o
	rm -f src/lexer.ml src/parser.ml src/parser.mli
	rm -f tests/*.cmi tests/*.cmo tests/*.cmx tests/*.o
	rm -f test_lexer test_ast test_parser ferdek ferdecc
	rm -f examples/*.c examples/test_interpreter examples/functions examples/arrays examples/fizzbuzz examples/simple_compile
	rm -f pomysl pomysl.c

# Czyszczenie wszystkiego (włącznie z testami)
distclean: clean
	rm -f *.conflicts

# Test
test: test_lexer test_ast test_parser
	@echo "=== Test lexera ==="
	./test_lexer
	@echo ""
	@echo "=== Test AST ==="
	./test_ast
	@echo ""
	@echo "=== Test parsera ==="
	./test_parser

# Test z przykładowymi plikami
test-examples: test_lexer
	@echo "=== Test: Hello World ==="
	@echo 'CO JEST KURDE\nPANIE SENSACJA REWELACJA "Cześć!"\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE' | ./test_lexer

.PHONY: all clean distclean test test-examples
