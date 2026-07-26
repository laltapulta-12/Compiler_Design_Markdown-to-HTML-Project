%{
#include <stdio.h>
%}

%%

"###"[ \t]*.*         { printf("H3\n"); }
"##"[ \t]*.*          { printf("H2\n"); }
"#"[ \t]*.*           { printf("H1\n"); }
"---"                 { printf("HR\n"); }
">".*                 { printf("BLOCKQUOTE\n"); }
"-".*                 { printf("LIST_ITEM\n"); }
"**"[^\n]+"**"        { printf("BOLD\n"); }
"*"[^\n]+"*"          { printf("ITALIC\n"); }
"["[^\]]+"]("[^)]+")" { printf("LINK\n"); }
\n                    { /* ignore newline */ }
[ \t]+                { /* ignore whitespace */ }
[a-zA-Z0-9.,!? ]+     { printf("TEXT\n"); }
.                     { /* ignore other characters */ }

%%

int yywrap() {
    return 1;
}

int main() {
    yylex();
    return 0;
}
