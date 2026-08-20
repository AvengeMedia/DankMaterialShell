package lexers

import (
	. "github.com/alecthomas/chroma/v2" // nolint
)

// Genshi Text lexer.
var GenshiText = Register(MustNewLexer(
	&Config{
		Name:      "Genshi Text",
		Aliases:   []string{"genshitext"},
		Filenames: []string{},
		MimeTypes: []string{"application/x-genshi-text", "text/x-genshi"},
	},
	genshiTextRules,
))

func genshiTextRules() Rules {
	return Rules{
		"root": {
			{Pattern: `[^#$\s]+`, Type: Other, Mutator: nil},
			{Pattern: `^(\s*)(##.*)$`, Type: ByGroups(Text, Comment), Mutator: nil},
			{Pattern: `^(\s*)(#)`, Type: ByGroups(Text, CommentPreproc), Mutator: Push("directive")},
			Include("variable"),
			{Pattern: `[#$\s]`, Type: Other, Mutator: nil},
		},
		"directive": {
			{Pattern: `\n`, Type: Text, Mutator: Pop(1)},
			{Pattern: `(?:def|for|if)\s+.*`, Type: Using("Python"), Mutator: Pop(1)},
			{Pattern: `(choose|when|with)([^\S\n]+)(.*)`, Type: ByGroups(Keyword, Text, Using("Python")), Mutator: Pop(1)},
			{Pattern: `(choose|otherwise)\b`, Type: Keyword, Mutator: Pop(1)},
			{Pattern: `(end\w*)([^\S\n]*)(.*)`, Type: ByGroups(Keyword, Text, Comment), Mutator: Pop(1)},
		},
		"variable": {
			{Pattern: `(?<!\$)(\$\{)(.+?)(\})`, Type: ByGroups(CommentPreproc, Using("Python"), CommentPreproc), Mutator: nil},
			{Pattern: `(?<!\$)(\$)([a-zA-Z_][\w.]*)`, Type: NameVariable, Mutator: nil},
		},
	}
}

// Html+Genshi lexer.
var GenshiHTMLTemplate = Register(MustNewLexer(
	&Config{
		Name:         "Genshi HTML",
		Aliases:      []string{"html+genshi", "html+kid"},
		Filenames:    []string{},
		MimeTypes:    []string{"text/html+genshi"},
		NotMultiline: true,
		DotAll:       true,
	},
	genshiMarkupRules,
))

// Genshi lexer.
var Genshi = Register(MustNewLexer(
	&Config{
		Name:         "Genshi",
		Aliases:      []string{"genshi", "kid", "xml+genshi", "xml+kid"},
		Filenames:    []string{"*.kid"},
		MimeTypes:    []string{"application/x-genshi", "application/x-kid"},
		NotMultiline: true,
		DotAll:       true,
	},
	genshiMarkupRules,
))

func genshiMarkupRules() Rules {
	return Rules{
		"root": {
			{Pattern: `[^<$]+`, Type: Other, Mutator: nil},
			{Pattern: `(<\?python)(.*?)(\?>)`, Type: ByGroups(CommentPreproc, Using("Python"), CommentPreproc), Mutator: nil},
			{Pattern: `<\s*(script|style)\s*.*?>.*?<\s*/\1\s*>`, Type: Other, Mutator: nil},
			{Pattern: `<\s*py:[a-zA-Z0-9]+`, Type: NameTag, Mutator: Push("pytag")},
			{Pattern: `<\s*[a-zA-Z0-9:.]+`, Type: NameTag, Mutator: Push("tag")},
			Include("variable"),
			{Pattern: `[<$]`, Type: Other, Mutator: nil},
		},
		"pytag": {
			{Pattern: `\s+`, Type: Text, Mutator: nil},
			{Pattern: `[\w:-]+\s*=`, Type: NameAttribute, Mutator: Push("pyattr")},
			{Pattern: `/?\s*>`, Type: NameTag, Mutator: Pop(1)},
		},
		"pyattr": {
			{Pattern: `(")(.*?)(")`, Type: ByGroups(LiteralString, Using("Python"), LiteralString), Mutator: Pop(1)},
			{Pattern: `(')(.*?)(')`, Type: ByGroups(LiteralString, Using("Python"), LiteralString), Mutator: Pop(1)},
			{Pattern: `[^\s>]+`, Type: LiteralString, Mutator: Pop(1)},
		},
		"tag": {
			{Pattern: `\s+`, Type: Text, Mutator: nil},
			{Pattern: `py:[\w-]+\s*=`, Type: NameAttribute, Mutator: Push("pyattr")},
			{Pattern: `[\w:-]+\s*=`, Type: NameAttribute, Mutator: Push("attr")},
			{Pattern: `/?\s*>`, Type: NameTag, Mutator: Pop(1)},
		},
		"attr": {
			{Pattern: `"`, Type: LiteralString, Mutator: Push("attr-dstring")},
			{Pattern: `'`, Type: LiteralString, Mutator: Push("attr-sstring")},
			{Pattern: `[^\s>]*`, Type: LiteralString, Mutator: Pop(1)},
		},
		"attr-dstring": {
			{Pattern: `"`, Type: LiteralString, Mutator: Pop(1)},
			Include("strings"),
			{Pattern: `'`, Type: LiteralString, Mutator: nil},
		},
		"attr-sstring": {
			{Pattern: `'`, Type: LiteralString, Mutator: Pop(1)},
			Include("strings"),
			{Pattern: `'`, Type: LiteralString, Mutator: nil},
		},
		"strings": {
			{Pattern: `[^"'$]+`, Type: LiteralString, Mutator: nil},
			Include("variable"),
		},
		"variable": {
			{Pattern: `(?<!\$)(\$\{)(.+?)(\})`, Type: ByGroups(CommentPreproc, Using("Python"), CommentPreproc), Mutator: nil},
			{Pattern: `(?<!\$)(\$)([a-zA-Z_][\w\.]*)`, Type: NameVariable, Mutator: nil},
		},
	}
}
