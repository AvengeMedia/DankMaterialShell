package lexers

import (
	"strings"

	. "github.com/alecthomas/chroma/v2" // nolint
)

// Restructuredtext lexer.
var Restructuredtext = Register(MustNewLexer(
	&Config{
		Name:      "reStructuredText",
		Aliases:   []string{"rst", "rest", "restructuredtext"},
		Filenames: []string{"*.rst", "*.rest"},
		MimeTypes: []string{"text/x-rst", "text/prs.fallenstein.rst"},
	},
	restructuredtextRules,
))

func restructuredtextRules() Rules {
	return Rules{
		"root": {
			{Pattern: "^(=+|-+|`+|:+|\\.+|\\'+|\"+|~+|\\^+|_+|\\*+|\\++|#+)([ \\t]*\\n)(.+)(\\n)(\\1)(\\n)", Type: ByGroups(GenericHeading, Text, GenericHeading, Text, GenericHeading, Text), Mutator: nil},
			{Pattern: "^(\\S.*)(\\n)(={3,}|-{3,}|`{3,}|:{3,}|\\.{3,}|\\'{3,}|\"{3,}|~{3,}|\\^{3,}|_{3,}|\\*{3,}|\\+{3,}|#{3,})(\\n)", Type: ByGroups(GenericHeading, Text, GenericHeading, Text), Mutator: nil},
			{Pattern: `^(\s*)([-*+])( .+\n(?:\1  .+\n)*)`, Type: ByGroups(Text, LiteralNumber, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^(\s*)([0-9#ivxlcmIVXLCM]+\.)( .+\n(?:\1  .+\n)*)`, Type: ByGroups(Text, LiteralNumber, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^(\s*)(\(?[0-9#ivxlcmIVXLCM]+\))( .+\n(?:\1  .+\n)*)`, Type: ByGroups(Text, LiteralNumber, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^(\s*)([A-Z]+\.)( .+\n(?:\1  .+\n)+)`, Type: ByGroups(Text, LiteralNumber, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^(\s*)(\(?[A-Za-z]+\))( .+\n(?:\1  .+\n)+)`, Type: ByGroups(Text, LiteralNumber, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^(\s*)(\|)( .+\n(?:\|  .+\n)*)`, Type: ByGroups(Text, Operator, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^( *\.\.)(\s*)((?:source)?code(?:-block)?)(::)([ \t]*)([^\n]+)(\n[ \t]*\n)([ \t]+)(.*)(\n)((?:(?:\8.*|)\n)+)`, Type: EmitterFunc(rstCodeBlock), Mutator: nil},
			{Pattern: `^( *\.\.)(\s*)([\w:-]+?)(::)(?:([ \t]*)(.*))`, Type: ByGroups(Punctuation, Text, OperatorWord, Punctuation, Text, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^( *\.\.)(\s*)(_(?:[^:\\]|\\.)+:)(.*?)$`, Type: ByGroups(Punctuation, Text, NameTag, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^( *\.\.)(\s*)(\[.+\])(.*?)$`, Type: ByGroups(Punctuation, Text, NameTag, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^( *\.\.)(\s*)(\|.+\|)(\s*)([\w:-]+?)(::)(?:([ \t]*)(.*))`, Type: ByGroups(Punctuation, Text, NameTag, Text, OperatorWord, Punctuation, Text, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^ *\.\..*(\n( +.*\n|\n)+)?`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `^( *)(:[a-zA-Z-]+:)(\s*)$`, Type: ByGroups(Text, NameClass, Text), Mutator: nil},
			{Pattern: `^( *)(:.*?:)([ \t]+)(.*?)$`, Type: ByGroups(Text, NameClass, Text, NameFunction), Mutator: nil},
			{Pattern: `^(\S.*(?<!::)\n)((?:(?: +.*)\n)+)`, Type: ByGroups(UsingSelf("inline"), UsingSelf("inline")), Mutator: nil},
			{Pattern: `(::)(\n[ \t]*\n)([ \t]+)(.*)(\n)((?:(?:\3.*|)\n)+)`, Type: ByGroups(LiteralStringEscape, Text, LiteralString, LiteralString, Text, LiteralString), Mutator: nil},
			Include("inline"),
		},
		"inline": {
			{Pattern: `\\.`, Type: Text, Mutator: nil},
			{Pattern: "``", Type: LiteralString, Mutator: Push("literal")},
			{Pattern: "(`.+?)(<.+?>)(`__?)", Type: ByGroups(LiteralString, LiteralStringInterpol, LiteralString), Mutator: nil},
			{Pattern: "`.+?`__?", Type: LiteralString, Mutator: nil},
			{Pattern: "(`.+?`)(:[a-zA-Z0-9:-]+?:)?", Type: ByGroups(NameVariable, NameAttribute), Mutator: nil},
			{Pattern: "(:[a-zA-Z0-9:-]+?:)(`.+?`)", Type: ByGroups(NameAttribute, NameVariable), Mutator: nil},
			{Pattern: `\*\*.+?\*\*`, Type: GenericStrong, Mutator: nil},
			{Pattern: `\*.+?\*`, Type: GenericEmph, Mutator: nil},
			{Pattern: `\[.*?\]_`, Type: LiteralString, Mutator: nil},
			{Pattern: `<.+?>`, Type: NameTag, Mutator: nil},
			{Pattern: "[^\\\\\\n\\[*`:]+", Type: Text, Mutator: nil},
			{Pattern: `.`, Type: Text, Mutator: nil},
		},
		"literal": {
			{Pattern: "[^`]+", Type: LiteralString, Mutator: nil},
			{Pattern: "``((?=$)|(?=[-/:.,; \\n\\x00\\\u2010\\\u2011\\\u2012\\\u2013\\\u2014\\\u00a0\\'\\\"\\)\\]\\}\\>\\\u2019\\\u201d\\\u00bb\\!\\?]))", Type: LiteralString, Mutator: Pop(1)},
			{Pattern: "`", Type: LiteralString, Mutator: nil},
		},
	}
}

func rstCodeBlock(groups []string, state *LexerState) Iterator {
	iterators := []Iterator{}
	tokens := []Token{
		{Type: Punctuation, Value: groups[1]},
		{Type: Text, Value: groups[2]},
		{Type: OperatorWord, Value: groups[3]},
		{Type: Punctuation, Value: groups[4]},
		{Type: Text, Value: groups[5]},
		{Type: Keyword, Value: groups[6]},
		{Type: Text, Value: groups[7]},
	}
	code := strings.Join(groups[8:], "")
	lexer := Get(groups[6])
	if lexer == nil {
		tokens = append(tokens, Token{Type: String, Value: code})
		iterators = append(iterators, Literator(tokens...))
	} else {
		sub, err := lexer.Tokenise(nil, code)
		if err != nil {
			panic(err)
		}
		iterators = append(iterators, Literator(tokens...), sub)
	}
	return Concaterator(iterators...)
}
