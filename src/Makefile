clean:
	rm -f gmc lex.yy.c new_grammar.tab.c new_grammar.tab.h

bison:
	bison -d -v new_grammar.y --debug -g

flex: bison
	flex lexer.l

create: flex
	g++ -g -o gmc lex.yy.c new_grammar.tab.c asm.cpp -lfl

test: create
	./gmc --input tests/final_tests/bitsum.py -v

test_asm: test
	g++ -c -g asm_code.s -o test.o
	g++ -g test.o -o test
	./test

test_only_asm: 
	g++ -c -g asm_code.s -o test.o
	g++ -g test.o -o test
	./test
