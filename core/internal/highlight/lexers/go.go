package lexers

import (
	"strings"

	. "github.com/alecthomas/chroma/v2" // nolint
)

// Go lexer.
var Go = Register(MustNewLexer(
	&Config{
		Name:      "Go",
		Aliases:   []string{"go", "golang"},
		Filenames: []string{"*.go"},
		MimeTypes: []string{"text/x-gosrc"},
	},
	goRules,
).SetAnalyser(func(text string) float32 {
	if strings.Contains(text, "fmt.") && strings.Contains(text, "package ") {
		return 0.5
	}
	if strings.Contains(text, "package ") {
		return 0.1
	}
	return 0.0
}))

func goRules() Rules {
	return Rules{
		"root": {
			{Pattern: `\n`, Type: TextWhitespace, Mutator: nil},
			{Pattern: `\s+`, Type: TextWhitespace, Mutator: nil},
			{Pattern: `//[^\s\n\r][^\n\r]*`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `//[^\n\r]*`, Type: CommentSingle, Mutator: nil},
			{Pattern: `/(\\\n)?[*](.|\n)*?[*](\\\n)?/`, Type: CommentMultiline, Mutator: nil},
			{Pattern: `(import|package)\b`, Type: KeywordNamespace, Mutator: nil},
			{Pattern: `(var|func|struct|map|chan|type|interface|const)\b`, Type: KeywordDeclaration, Mutator: nil},
			{Pattern: Words(``, `\b`, `break`, `default`, `select`, `case`, `defer`, `go`, `else`, `goto`, `switch`, `fallthrough`, `if`, `range`, `continue`, `for`, `return`), Type: Keyword, Mutator: nil},
			{Pattern: `(true|false|iota|nil)\b`, Type: KeywordConstant, Mutator: nil},
			{Pattern: Words(``, `\b(\()`, `uint`, `uint8`, `uint16`, `uint32`, `uint64`, `int`, `int8`, `int16`, `int32`, `int64`, `float`, `float32`, `float64`, `complex64`, `complex128`, `byte`, `rune`, `string`, `bool`, `error`, `uintptr`, `print`, `println`, `panic`, `recover`, `close`, `complex`, `real`, `imag`, `len`, `cap`, `append`, `copy`, `delete`, `new`, `make`, `clear`, `min`, `max`), Type: ByGroups(NameBuiltin, Punctuation), Mutator: nil},
			{Pattern: Words(``, `\b`, `uint`, `uint8`, `uint16`, `uint32`, `uint64`, `int`, `int8`, `int16`, `int32`, `int64`, `float`, `float32`, `float64`, `complex64`, `complex128`, `byte`, `rune`, `string`, `bool`, `error`, `uintptr`, `any`), Type: KeywordType, Mutator: nil},
			{Pattern: `\d+i`, Type: LiteralNumber, Mutator: nil},
			{Pattern: `\d+\.\d*([Ee][-+]\d+)?i`, Type: LiteralNumber, Mutator: nil},
			{Pattern: `\.\d+([Ee][-+]\d+)?i`, Type: LiteralNumber, Mutator: nil},
			{Pattern: `\d+[Ee][-+]\d+i`, Type: LiteralNumber, Mutator: nil},
			{Pattern: `\d+(\.\d+[eE][+\-]?\d+|\.\d*|[eE][+\-]?\d+)`, Type: LiteralNumberFloat, Mutator: nil},
			{Pattern: `\.\d+([eE][+\-]?\d+)?`, Type: LiteralNumberFloat, Mutator: nil},
			{Pattern: `0[0-7]+`, Type: LiteralNumberOct, Mutator: nil},
			{Pattern: `0[xX][0-9a-fA-F_]+`, Type: LiteralNumberHex, Mutator: nil},
			{Pattern: `0b[01_]+`, Type: LiteralNumberBin, Mutator: nil},
			{Pattern: `(0|[1-9][0-9_]*)`, Type: LiteralNumberInteger, Mutator: nil},
			{Pattern: `'(\\['"\\abfnrtv]|\\x[0-9a-fA-F]{2}|\\[0-7]{1,3}|\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8}|[^\\])'`, Type: LiteralStringChar, Mutator: nil},
			{Pattern: "(`)([^`]*)(`)", Type: ByGroups(LiteralString, UsingLexer(TypeRemappingLexer(GoTextTemplate, TypeMapping{{Other, LiteralString, nil}})), LiteralString), Mutator: nil},
			{Pattern: `"(\\\\|\\"|[^"])*"`, Type: LiteralString, Mutator: nil},
			{Pattern: `(<<=|>>=|<<|>>|<=|>=|&\^=|&\^|\+=|-=|\*=|/=|%=|&=|\|=|&&|\|\||<-|\+\+|--|==|!=|:=|\.\.\.|[+\-*/%&])`, Type: Operator, Mutator: nil},
			{Pattern: `([a-zA-Z_]\w*)(\s*)(\()`, Type: ByGroups(NameFunction, UsingSelf("root"), Punctuation), Mutator: nil},
			{Pattern: `[|^<>=!()\[\]{}.,;:~]`, Type: Punctuation, Mutator: nil},
			{Pattern: `[^\W\d]\w*`, Type: NameOther, Mutator: nil},
		},
	}
}

var GoHTMLTemplate = Register(DelegatingLexer(HTML, MustNewXMLLexer(
	embedded,
	"embedded/go_template.xml",
).SetConfig(
	&Config{
		Name:    "Go HTML Template",
		Aliases: []string{"go-html-template"},
	},
)))

var GoTextTemplate = Register(MustNewXMLLexer(
	embedded,
	"embedded/go_template.xml",
).SetConfig(
	&Config{
		Name:    "Go Text Template",
		Aliases: []string{"go-text-template"},
	},
))
