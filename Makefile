CC = gcc
FLEX = flex
BISON = bison

TARGET = a
LEXER = lexer.l
PARSER = parser.y

all: $(TARGET)

$(TARGET): lex.yy.c parser.tab.c
	$(CC) -o $(TARGET) lex.yy.c parser.tab.c

parser.tab.c parser.tab.h: $(PARSER)
	$(BISON) -d $(PARSER)

lex.yy.c: $(LEXER) parser.tab.h
	$(FLEX) $(LEXER)

run: $(TARGET)
	./$(TARGET) input.md

clean:
	rm -f $(TARGET) lex.yy.c parser.tab.c parser.tab.h output.html

.PHONY: all run clean