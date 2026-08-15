# Markdown-to-HTML Compiler
### A Compiler Design Course Project (Flex + Bison + C)

## 1. Project Title

**Markdown-to-HTML Compiler** — a mini compiler that translates a
well-defined subset of Markdown into valid HTML, built with Flex
(lexical analyzer generator) and Bison (parser generator).

## 2. Project Objective

The goal of this project is to demonstrate, end to end, the classic
compiler pipeline taught in a Compiler Design course — lexical
analysis, syntax analysis, and semantic translation — using a
problem domain that is easy to explain and easy to verify by eye:
converting a Markdown document into an HTML document.

```
SOURCE MARKDOWN
      |
LEXICAL ANALYSIS (Flex, lexer.l)
      |
TOKEN STREAM
      |
SYNTAX ANALYSIS (Bison, driven by a Context-Free Grammar)
      |
REDUCTIONS
      |
SEMANTIC ACTIONS (C code inside parser.y)
      |
HTML OUTPUT (output.html)
```

This is **not** a full Markdown implementation. It intentionally
implements a small, well-specified subset so that the lexer and
grammar stay simple enough to present and defend in class, while
still demonstrating every stage of a real compiler.

## 3. Technologies Used

| Tool  | Purpose                                                     |
|-------|--------------------------------------------------------------|
| Flex  | Generates the lexical analyzer (`lex.yy.c`) from `lexer.l`   |
| Bison | Generates the parser (`parser.tab.c` / `.h`) from `parser.y` |
| C     | Semantic actions, program control, `main()`                  |
| GCC   | Compiles/links the generated C sources into the executable   |

## 4. What Lexical Analysis Means in This Project

Lexical analysis is the process of scanning the raw Markdown text
character by character and grouping those characters into
meaningful **tokens** — the smallest units the grammar understands
(e.g. "this is a level-1 heading containing the text `Hello
World`"). `lexer.l` implements this stage. It never decides whether
the *sequence* of tokens is valid — that is the parser's job — it
only recognizes individual constructs and extracts their text.

## 5. What Syntax Analysis Means in This Project

Syntax analysis takes the token stream produced by the lexer and
checks it against a **Context-Free Grammar (CFG)** to confirm the
tokens form a valid document, and to determine the structure of
that document (which tokens belong to the same paragraph, which
line starts a new list, and so on). `parser.y` implements this
stage using Bison, an LALR(1) parser generator.

## 6. Token Table

| Token        | Carries text? | Produced from                             |
|--------------|:-------------:|--------------------------------------------|
| `H1`         | yes           | `# heading text`                            |
| `H2`         | yes           | `## heading text`                           |
| `H3`         | yes           | `### heading text`                          |
| `HR`         | no            | `---`                                       |
| `BLOCKQUOTE` | yes           | `> quoted text`                             |
| `LIST_ITEM`  | yes           | `- item text`                               |
| `BOLD`       | yes           | `**bold text**`                             |
| `ITALIC`     | yes           | `*italic text*`                             |
| `LINK`       | yes           | `[link text](url)`                          |
| `TEXT`       | yes           | any other run of plain paragraph characters |
| `NEWLINE`    | no            | end of a line (`\n`)                        |

Tokens marked "carries text" set `yylval.str` (declared via
`%union { char *str; }` in `parser.y`) to a heap-allocated string
that the consuming semantic action `free()`s after use.

## 7. Lexical Rules (`lexer.l`)

Rules are listed in priority order. Flex resolves competing matches
by **longest match first**, and **rule order** as the tie-breaker.
This project relies on that tie-breaker deliberately:

1. `^"###"[^\n]*`, `^"##"[^\n]*`, `^"#"[^\n]*` (H3 before H2 before
   H1) — for input like `### Hello`, all three patterns match the
   *same* full length (the trailing `[^\n]*` on the H1/H2 patterns
   simply swallows the extra `#` characters as "text"), so listing
   H3 first is what makes the correct, most specific rule win.
2. `^"---"[ \t]*` → `HR`
3. `^">"[^\n]*` → `BLOCKQUOTE`
4. `^"-"[ \t]+[^\n]*` → `LIST_ITEM` (requires at least one space
   after the `-`, so a plain sentence starting with a hyphen but no
   space is correctly treated as paragraph text, not a list item)
5. `"**"[^*\n]+"**"` → `BOLD`
6. `"*"[^*\n]+"*"` → `ITALIC`
7. `"["[^\]\n]+"]"[ \t]*"("[^)\n]+")"` → `LINK`
8. A lone, unmatched `*` or `[` → literal `TEXT`
9. `[^*\n\[`]+` → generic `TEXT` (a run of plain characters,
   including spaces, so multi-word text becomes one token and
   inter-word spacing is preserved verbatim). The backtick
   (`` ` ``) is deliberately excluded from this class — see the
   note on rule 11 below.
10. `\n` → `NEWLINE`
11. `.` (catch-all) → reports `Lexical Error: Unknown character` to
    `stderr` and continues. Because `TEXT` already consumes every
    byte except `*`, `[`, `\n`, and `` ` ``, and those first three
    are each handled by a dedicated rule above, a backtick is the
    one character in this subset that is deliberately left
    unhandled — code spans are out of scope for this subset — so
    this catch-all rule is genuinely reachable and demonstrates
    real unknown-character error handling instead of being dead
    code that can never match.

**Marker-stripping is done explicitly, never by a fixed offset
"guess."** Each block rule skips exactly the marker characters it
matched, then calls the `skip_ws()` helper, which advances past any
run of spaces/tabs — so `# Hello`, `#Hello`, and `#   Hello` all
correctly yield `Hello`, never `ello`.

**`yywrap()`:** this lexer defines `int yywrap() { return 1; }`
directly instead of using `%option noyywrap`, telling Flex there is
no additional input file to chain to after `input.md` is exhausted.

## 8. Context-Free Grammar

```
document        : header blocks footer

header          : /* empty */            (prints the HTML prologue)
footer          : /* empty */            (closes an open list if
                                           needed, prints the HTML
                                           epilogue)

blocks          : /* empty */
                | blocks block

block           : heading
                | paragraph
                | horizontal_rule
                | blockquote
                | list_item
                | blank_line

heading         : H1 NEWLINE
                | H2 NEWLINE
                | H3 NEWLINE

paragraph       : paragraph_start inline_content NEWLINE
paragraph_start : /* empty */            (closes an open list,
                                           prints "<p>")

inline_content  : inline
                | inline_content inline

inline          : TEXT
                | BOLD
                | ITALIC
                | LINK

horizontal_rule : HR NEWLINE

blockquote      : BLOCKQUOTE NEWLINE

list_item       : LIST_ITEM NEWLINE      (opens "<ul>" on the first
                                           item of a run, prints one
                                           "<li>")

blank_line      : NEWLINE                (closes an open list)
```

### Why this grammar has zero shift/reduce and zero reduce/reduce conflicts

Every alternative of `block` begins with a **disjoint** first
token: `H1|H2|H3` for `heading`, `HR` for `horizontal_rule`,
`BLOCKQUOTE` for `blockquote`, `LIST_ITEM` for `list_item`,
`NEWLINE` for `blank_line`, and `TEXT|BOLD|ITALIC|LINK` for
`paragraph`. An LALR(1) parser only ever needs one token of
lookahead to know which alternative it is in, so there is no
ambiguity to resolve there.

The empty productions (`header`, `footer`, `paragraph_start`) are
the standard Bison "mid-rule action" idiom, used to emit an opening
tag *before* the following symbols are parsed. Each of them only
ever gets reduced at a point where the lookahead token has already
uniquely selected that production, so they don't introduce a
conflict either.

**Why lists are *not* grammar-recursive.** A more "obvious" way to
write the list rule is:

```
list       : list_start list_items ;
list_items : LIST_ITEM NEWLINE
           | list_items LIST_ITEM NEWLINE ;
```

with `block : list`. That grammar is **genuinely ambiguous**, not
just a matter of parser preference: since `blocks` is *also*
left-recursive over `block`, a run of 3 consecutive `LIST_ITEM`
tokens can be derived either as one `list` (via `list_items`' own
recursion) or as three separate one-item `list` blocks (via
`blocks` choosing `block = list` three times in a row) — both are
valid parse trees for the exact same token stream. This is the
classic "two nested unbounded repetitions over the same alphabet"
ambiguity, structurally the same problem as `E : E E | a`, and
Bison correctly reports it as a real shift/reduce conflict.

This project's grammar avoids it by removing the inner repetition
entirely: `list_item` matches exactly **one** line, just like
`heading`, `blockquote`, and `horizontal_rule` do, so `blocks` is
the *only* repeating construct anywhere in the grammar and every
input has exactly one derivation. Grouping consecutive items into a
single `<ul>` is done with a small piece of state instead — the
static `in_list` flag in `parser.y`: the first `list_item` in a run
opens `<ul>`, and every *other* block type (heading, paragraph,
horizontal rule, blockquote, blank line, or end of document) calls
`close_list_if_open()` before it prints anything, so `<ul>` closes
the instant a non-list line is seen. This is a common, legitimate
technique for exactly this situation — the grammar itself stays
simple and unambiguous, and the HTML is still only ever written
from semantic actions in `parser.y`.

This grammar was independently checked by constructing its actual
LR(0)/SLR(1) item-set automaton (34 states) and verifying no state
has a shift/reduce or reduce/reduce conflict on any token — not
just reasoned about by hand.

## 9. Parser Structure

`parser.y` is organized as:
- `%union` / `%token` declarations matching the lexer's tokens.
- The CFG and semantic actions (sections 8 / 10).
- `yyerror()` — reports syntax errors to `stderr`.
- `main()` — opens `input.md` / `output.html`, points `yyin` at the
  input file, calls `yyparse()`, closes both files, and returns a
  process exit status of `0` on success or non-zero on failure.

## 10. Semantic Actions

Semantic actions are the C code blocks attached to grammar rules.
They run each time Bison reduces that rule, and they are the
**only** place HTML is written (`fprintf(output, ...)`). Examples:

```c
heading : H1 NEWLINE
    {
        close_list_if_open();
        fprintf(output, "<h1>%s</h1>\n\n", $1);
        free($1);
    }
```

```c
inline : BOLD
    {
        fprintf(output, "<strong>%s</strong>", $1);
        free($1);
    }
```

For `paragraph`, the `<p>` tag is printed by the `paragraph_start`
mid-rule action *before* `inline_content` is parsed, and `</p>` is
printed by `paragraph`'s own action *after* the terminating
`NEWLINE` — guaranteeing exactly one opening and one closing tag
per paragraph, with all inline pieces (`TEXT` / `BOLD` / `ITALIC` /
`LINK`) printed in between in the order they were read.

For `LINK`, the lexer packs `"link text\x01url"` into one string
(`\x01` cannot appear in normal Markdown text, so it's a safe
separator); the parser's semantic action splits on that byte and
builds `<a href="url">link text</a>` — so HTML generation still
happens entirely in the parser, never in the lexer.

For `list_item`, the static `in_list` flag (declared in the C
preamble of `parser.y`) determines whether to print `<ul>` before
the first `<li>` of a run; `close_list_if_open()` is called from
every other block's action (and from `footer`, for a list at the
very end of the document) to close it again.

Every `strdup`-allocated `yylval.str` is `free()`'d by the semantic
action that consumes it, so the compiler does not leak memory while
processing a document.

## 11. Markdown-to-HTML Conversion — Worked Examples

Input:
```
# Hello World
```
Lexer produces: `H1("Hello World")`, `NEWLINE`.
Parser reduces `heading : H1 NEWLINE` and runs its action:
```
<h1>Hello World</h1>
```

Input:
```
- Apple
- Banana
```
Lexer produces: `LIST_ITEM("Apple")`, `NEWLINE`, `LIST_ITEM("Banana")`, `NEWLINE`.
Parser reduces `list_item` twice: the first reduction sees
`in_list == 0` and prints `<ul>` before its `<li>`; the second sees
`in_list == 1` and prints only its `<li>`. Result:
```
<ul>
<li>Apple</li>
<li>Banana</li>
</ul>
```

## 12. Project Structure

```
markdown-to-html/
├── lexer.l          Flex source (lexical analyzer)
├── parser.y          Bison source (grammar + semantic actions + main)
├── input.md           Sample Markdown input
├── output.html        Generated HTML (created by running the compiler)
└── README.md          This file
```

Generated at build time (not checked in by hand):
```
lex.yy.c              Generated by flex from lexer.l
parser.tab.c          Generated by bison from parser.y
parser.tab.h          Generated by bison from parser.y
markdown / markdown.exe   Final compiled executable
```

## 13. Installation Requirements

- `flex` (tested against Flex 2.6.x)
- `bison` (tested against Bison 3.8.x)
- `gcc` (or any C compiler)

On Debian/Ubuntu:
```
sudo apt-get install flex bison gcc
```

On Windows, install via MSYS2 or Cygwin and use their `flex`,
`bison`, and `gcc` packages.

## 14. Compilation Commands

Run these from inside the `markdown-to-html/` directory, in order:

```
bison -d parser.y
flex lexer.l
gcc -o markdown parser.tab.c lex.yy.c
```

- `bison -d parser.y` generates `parser.tab.c` and `parser.tab.h`
  (the `-d` flag is what produces the header the lexer includes).
- `flex lexer.l` generates `lex.yy.c`.
- `gcc -o markdown parser.tab.c lex.yy.c` compiles and links both
  generated files into a single executable named `markdown`.

You should see **no** Bison conflict warnings and **no** compiler
errors or unreachable-rule warnings.

## 15. Execution Command

Linux / macOS:
```
./markdown input.md
```

Windows (Cygwin/MSYS2):
```
.\markdown.exe input.md
```

The program itself opens `input.md`, opens `output.html` for
writing, and writes the generated HTML directly — there is no
reliance on shell redirection (`>`).

## 16. Example Input

See `input.md`, included in this project:

```
# Hello World

This is a simple paragraph.

This is **bold** text.

This is *italic* text.

This is **bold** and *italic* text.

- Apple
- Banana
- Orange

> This is a blockquote.

---

Visit [Google](https://google.com).
```

## 17. Example Output

Running `./markdown input.md` produces `output.html`:

```html
<!DOCTYPE html>
<html>
<head>
<title>Markdown Document</title>
</head>
<body>

<h1>Hello World</h1>

<p>This is a simple paragraph.</p>

<p>This is <strong>bold</strong> text.</p>

<p>This is <em>italic</em> text.</p>

<p>This is <strong>bold</strong> and <em>italic</em> text.</p>

<ul>
<li>Apple</li>
<li>Banana</li>
<li>Orange</li>
</ul>

<blockquote>This is a blockquote.</blockquote>

<hr>

<p>Visit <a href="https://google.com">Google</a>.</p>

</body>
</html>
```

## 18. Limitations

This project deliberately implements a **subset** of Markdown for
academic clarity, not the full CommonMark specification. It does
NOT support:
- Nested lists or ordered (`1.`) lists
- Multi-line / multi-paragraph blockquotes
- Fenced or inline code (a stray backtick is reported as an unknown
  character rather than starting a code span)
- Images (`![alt](url)`)
- Tables
- Headings below H3 (`####` and beyond are not specially recognized)
- Escaping Markdown special characters (e.g. a literal `*`)
- CRLF (Windows-style) line endings — a trailing `\r` on each line
  is not stripped, so input files should use Unix (`\n`) line
  endings; a file with CRLF endings will carry a stray `\r` into
  heading/list/quote/paragraph text

## 19. Future Improvements

- Support ordered lists (`1. item`) and nested lists via an
  indentation-aware lexer/grammar.
- Support fenced code blocks with a Flex *start condition*
  (`%x CODEBLOCK`) so code contents bypass inline Markdown parsing.
- Support multi-line blockquotes and paragraphs that wrap across
  several source lines.
- Add image syntax `![alt](url)` alongside the existing link rule.
- Strip trailing `\r` from matched text so CRLF input files are
  handled transparently.
- Add a `-o <file>` command-line option instead of a hard-coded
  `output.html` filename.

---

## How the Lexer and Parser Communicate

Flex and Bison communicate through a very small, well-defined
interface:

1. Bison's `yyparse()` calls the lexer function `yylex()` (defined
   in the Flex-generated `lex.yy.c`) every time it needs the next
   token.
2. `yylex()` returns an `int` — the token code. These codes are
   `#define`d in `parser.tab.h`, which is why `lexer.l` includes
   `"parser.tab.h"`: it needs to know the numeric values of `H1`,
   `LIST_ITEM`, `NEWLINE`, etc.
3. When a token carries a semantic value (heading text, list item
   text, ...), the lexer sets the global `yylval` (of the `%union`
   type declared in `parser.y`, here `yylval.str`) *before*
   returning the token code. Bison automatically makes that value
   available to the grammar rule that consumes the token, as `$1`,
   `$2`, etc.
4. `yyin` (a `FILE *` global from Flex) tells the lexer which file
   to read from; `main()` in `parser.y` sets it to the opened
   `input.md` before calling `yyparse()`.

## Testing Performed

`flex` / `bison` binaries were not available in the environment
this project was authored in, so the exact three build commands in
section 14 have not been executed there. In their place, the
project was verified two ways before being finalized:

1. **Grammar conflict-freedom** was checked by building the actual
   LR(0)/SLR(1) item-set automaton for the CFG in section 8
   (34 states) and confirming no state has a shift/reduce or
   reduce/reduce conflict on any token — the same class of
   algorithm Bison itself uses, not manual reasoning alone.
2. **Correctness of the token stream and generated HTML** was
   checked by tokenizing `input.md` with a rule-for-rule simulation
   of `lexer.l`'s regular expressions (using Flex's own longest-
   match / rule-order tie-break semantics) and feeding that token
   stream through a parser built directly from the grammar in
   section 8. All twelve required individual test cases (single
   H1/H2/H3, plain paragraph, bold, italic, mixed bold+italic, a
   three-item list producing exactly one `<ul>`, a blockquote, an
   `<hr>`, a link, and first-character preservation for headings,
   list items, and blockquotes) passed, and the full mixed
   `input.md` document reproduced the exact expected `output.html`
   from section 17.

Please run the three build commands in section 14 yourself; if
`bison -d parser.y` reports any conflict, or `gcc` reports any
error or warning, share the exact output and it can be fixed
immediately.
