%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
void yyerror(const char *s);
extern FILE *yyin;

FILE *output;

static int in_list = 0;

static void close_list_if_open(void) {
    if (in_list) {
        fprintf(output, "</ul>\n\n");
        in_list = 0;
    }
}
%}

%union {
    char *str;
}

%token <str> H1 H2 H3
%token HR
%token <str> BLOCKQUOTE LIST_ITEM
%token <str> BOLD ITALIC LINK
%token NEWLINE
%token <str> TEXT

%%

document
    : header blocks footer
    ;

header
    : 
      {
          fprintf(output,
              "<!DOCTYPE html>\n"
              "<html>\n"
              "<head>\n"
              "<title>Markdown Document</title>\n"
              "</head>\n"
              "<body>\n\n");
      }
    ;

footer
    :
      {
          close_list_if_open();
          fprintf(output, "</body>\n</html>\n");
      }
    ;

blocks
    :
    | blocks block
    ;

block
    : heading
    | paragraph
    | horizontal_rule
    | blockquote
    | list_item
    | blank_line
    ;

heading
    : H1 NEWLINE
      {
          close_list_if_open();
          fprintf(output, "<h1>%s</h1>\n\n", $1);
          free($1);
      }
    | H2 NEWLINE
      {
          close_list_if_open();
          fprintf(output, "<h2>%s</h2>\n\n", $1);
          free($1);
      }
    | H3 NEWLINE
      {
          close_list_if_open();
          fprintf(output, "<h3>%s</h3>\n\n", $1);
          free($1);
      }
    ;

paragraph
    : paragraph_start inline_content NEWLINE
      {
          fprintf(output, "</p>\n\n");
      }
    ;

paragraph_start
    :
      {
          close_list_if_open();
          fprintf(output, "<p>");
      }
    ;

inline_content
    : inline
    | inline_content inline
    ;

inline
    : TEXT
      {
          fprintf(output, "%s", $1);
          free($1);
      }
    | BOLD
      {
          fprintf(output, "<strong>%s</strong>", $1);
          free($1);
      }
    | ITALIC
      {
          fprintf(output, "<em>%s</em>", $1);
          free($1);
      }
    | LINK
      {

          char *sep = strchr($1, '\x01');
          if (sep != NULL) {
              *sep = '\0';
              char *link_text = $1;
              char *link_url = sep + 1;
              fprintf(output, "<a href=\"%s\">%s</a>", link_url, link_text);
          }
          free($1);
      }
    ;


horizontal_rule
    : HR NEWLINE
      {
          close_list_if_open();
          fprintf(output, "<hr>\n\n");
      }
    ;

blockquote
    : BLOCKQUOTE NEWLINE
      {
          close_list_if_open();
          fprintf(output, "<blockquote>%s</blockquote>\n\n", $1);
          free($1);
      }
    ;

list_item
    : LIST_ITEM NEWLINE
      {
          if (!in_list) {
              fprintf(output, "<ul>\n");
              in_list = 1;
          }
          fprintf(output, "<li>%s</li>\n", $1);
          free($1);
      }
    ;

blank_line
    : NEWLINE
      {
          close_list_if_open();
      }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Parser Error: %s\n", s);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s input.md\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Error opening input file");
        return 1;
    }

    output = fopen("output.html", "w");
    if (!output) {
        perror("Error creating output.html");
        fclose(yyin);
        return 1;
    }

    int result = yyparse();

    fclose(yyin);
    fclose(output);

    if (result == 0) {
        printf("Compilation successful: output.html generated.\n");
    } else {
        printf("Compilation failed.\n");
    }

    return result;
}
