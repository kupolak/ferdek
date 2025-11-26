# Makefile dla lexera języka Ferdek

OCAMLC = ocamlc
OCAMLLEX = ocamllex
MENHIR = menhir

all: test_lexer

# Generowanie lexera z .mll
lexer.ml: lexer.mll parser.cmi
	$(OCAMLLEX) lexer.mll

# Generowanie parsera z .mly
parser.ml parser.mli: parser.mly
	$(MENHIR) parser.mly

# Kompilacja interfejsu parsera
parser.cmi: parser.mli
	$(OCAMLC) -c parser.mli

# Kompilacja parsera
parser.cmo: parser.ml parser.cmi
	$(OCAMLC) -c parser.ml

# Kompilacja lexera
lexer.cmo: lexer.ml parser.cmi
	$(OCAMLC) -c lexer.ml

# Kompilacja programu testowego
test_lexer: parser.cmo lexer.cmo test_lexer.ml
	$(OCAMLC) -o test_lexer parser.cmo lexer.cmo test_lexer.ml

# Czyszczenie plików pośrednich
clean:
	rm -f *.cmi *.cmo *.cmx *.o
	rm -f lexer.ml parser.ml parser.mli
	rm -f test_lexer

# Czyszczenie wszystkiego (włącznie z testami)
distclean: clean
	rm -f *.conflicts

# Test
test: test_lexer
	./test_lexer

# Test z przykładowymi plikami
test-examples: test_lexer
	@echo "=== Test: Hello World ==="
	@echo 'CO JEST KURDE\nPANIE SENSACJA REWELACJA "Cześć!"\nMOJA NOGA JUŻ TUTAJ NIE POSTANIE' | ./test_lexer

.PHONY: all clean distclean test test-examples
