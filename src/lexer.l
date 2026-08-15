%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"

static char *skip_ws(char *s) {
    while (*s == ' ' || *s == '\t') {
        s++;
    }
    return s;
}
%}

%%

^"###"[^\n]* {
    char *text = yytext + 3;
    text = skip_ws(text);
    yylval.str = strdup(text);
    return H3;
}

^"##"[^\n]* {
    char *text = yytext + 2;
    text = skip_ws(text);
    yylval.str = strdup(text);
    return H2;
}

^"#"[^\n]* {
    char *text = yytext + 1;
    text = skip_ws(text);
    yylval.str = strdup(text);
    return H1;
}

^"---"[ \t]* {
    return HR;
}

^">"[^\n]* {
    char *text = yytext + 1;
    text = skip_ws(text);
    yylval.str = strdup(text);
    return BLOCKQUOTE;
}

^"-"[ \t]+[^\n]* {
    char *text = yytext + 1;
    text = skip_ws(text);
    yylval.str = strdup(text);
    return LIST_ITEM;
}

"**"[^*\n]+"**" {
    int len = yyleng - 4;
    char *buf = (char *)malloc(len + 1);
    memcpy(buf, yytext + 2, len);
    buf[len] = '\0';
    yylval.str = buf;
    return BOLD;
}

"*"[^*\n]+"*" {
    int len = yyleng - 2;
    char *buf = (char *)malloc(len + 1);
    memcpy(buf, yytext + 1, len);
    buf[len] = '\0';
    yylval.str = buf;
    return ITALIC;
}

"["[^\]\n]+"]"[ \t]*"("[^)\n]+")" {
    char *raw = strdup(yytext);
    char *close_bracket = strchr(raw, ']');
    *close_bracket = '\0';
    char *link_text = raw + 1;

    char *open_paren = strchr(close_bracket + 1, '(');
    char *url_start = open_paren + 1;
    char *close_paren = strrchr(url_start, ')');
    *close_paren = '\0';

    size_t total = strlen(link_text) + 1 + strlen(url_start) + 1;
    char *combined = (char *)malloc(total);
    snprintf(combined, total, "%s\x01%s", link_text, url_start);

    free(raw);
    yylval.str = combined;
    return LINK;
}

"*" {
    yylval.str = strdup("*");
    return TEXT;
}

"[" {
    yylval.str = strdup("[");
    return TEXT;
}

[^*\n\[`]+ {
    yylval.str = strdup(yytext);
    return TEXT;
}

\n {
    return NEWLINE;
}

. {
    fprintf(stderr, "Lexical Error: Unknown character: %s\n", yytext);
}

%%

int yywrap() {
    return 1;
}