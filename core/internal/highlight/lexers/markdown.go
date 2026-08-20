package lexers

import (
	"strings"

	. "github.com/alecthomas/chroma/v2" // nolint
)

// Markdown lexer with YAML frontmatter and HTML comment support.
var Markdown = Register(&markdownLexer{Lexer: MustNewLexer(
	&Config{
		Name:      "markdown",
		Aliases:   []string{"md", "mkd"},
		Filenames: []string{"*.md", "*.mkd", "*.markdown"},
		MimeTypes: []string{"text/x-markdown"},
	},
	markdownRules,
)})

// markdownLexer wraps the base Markdown lexer to highlight top-of-file YAML frontmatter.
type markdownLexer struct {
	Lexer
}

// Lexes Markdown, highlighting a leading YAML frontmatter block before delegating to Markdown rules.
func (m *markdownLexer) Tokenise(options *TokeniseOptions, text string) (Iterator, error) {
	frontmatter, rest, ok := splitFrontmatter(text)
	if !ok {
		return m.Lexer.Tokenise(options, text)
	}

	yamlLexer := Get("YAML")
	if yamlLexer == nil {
		return m.Lexer.Tokenise(options, text)
	}

	yamlTokens, err := yamlLexer.Tokenise(options, frontmatter)
	if err != nil {
		return nil, err
	}
	markdownTokens, err := m.Lexer.Tokenise(options, rest)
	if err != nil {
		return nil, err
	}
	return Concaterator(yamlTokens, markdownTokens), nil
}

// Extracts a leading YAML frontmatter block if the document starts with one.
func splitFrontmatter(text string) (frontmatter string, rest string, ok bool) {
	if !strings.HasPrefix(text, "---\n") && !strings.HasPrefix(text, "---\r\n") {
		return "", text, false
	}

	lineEnd := strings.IndexByte(text, '\n')
	if lineEnd < 0 {
		return "", text, false
	}
	if strings.TrimSuffix(text[:lineEnd], "\r") != "---" {
		return "", text, false
	}

	for pos := lineEnd + 1; pos < len(text); {
		next := strings.IndexByte(text[pos:], '\n')
		if next < 0 {
			break
		}
		lineEnd = pos + next
		line := strings.TrimSuffix(text[pos:lineEnd], "\r")
		if line == "---" {
			return text[:lineEnd+1], text[lineEnd+1:], true
		}
		pos = lineEnd + 1
	}
	return "", text, false
}

func markdownRules() Rules {
	return Rules{
		"root": {
			{Pattern: `<!--[\w\W]*?-->`, Type: CommentMultiline, Mutator: nil},
			{Pattern: `^(#[^#].+\n)`, Type: ByGroups(GenericHeading), Mutator: nil},
			{Pattern: `^(#{2,6}.+\n)`, Type: ByGroups(GenericSubheading), Mutator: nil},
			{Pattern: `^(\s*)([*-] )(\[[ xX]\])( .+\n)`, Type: ByGroups(Text, Keyword, Keyword, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^(\s*)([*-])(\s)(.+\n)`, Type: ByGroups(Text, Keyword, Text, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^(\s*)([0-9]+\.)( .+\n)`, Type: ByGroups(Text, Keyword, UsingSelf("inline")), Mutator: nil},
			{Pattern: `^(\s*>\s)(.+\n)`, Type: ByGroups(Keyword, GenericEmph), Mutator: nil},
			{Pattern: "^(```\\n)([\\w\\W]*?)(^```$)", Type: ByGroups(String, Text, String), Mutator: nil},
			{
				Pattern: "^(```)(\\w+)(\\n)([\\w\\W]*?)(^```$)",
				Type:    UsingByGroup(2, 4, String, String, String, Text, String),
				Mutator: nil,
			},
			Include("inline"),
		},
		"inline": {
			{Pattern: `<!--[\w\W]*?-->`, Type: CommentMultiline, Mutator: nil},
			{Pattern: `\\.`, Type: Text, Mutator: nil},
			{Pattern: `(\s)(\*|_)((?:(?!\2).)*)(\2)((?=\W|\n))`, Type: ByGroups(Text, GenericEmph, GenericEmph, GenericEmph, Text), Mutator: nil},
			{Pattern: `(\s)((\*\*|__).*?)\3((?=\W|\n))`, Type: ByGroups(Text, GenericStrong, GenericStrong, Text), Mutator: nil},
			{Pattern: `(\s)(~~[^~]+~~)((?=\W|\n))`, Type: ByGroups(Text, GenericDeleted, Text), Mutator: nil},
			{Pattern: "`[^`]+`", Type: LiteralStringBacktick, Mutator: nil},
			{Pattern: `[@#][\w/:]+`, Type: NameEntity, Mutator: nil},
			{Pattern: `(!?\[)([^]]+)(\])(\()([^)]+)(\))`, Type: ByGroups(Text, NameTag, Text, Text, NameAttribute, Text), Mutator: nil},
			{Pattern: `.|\n`, Type: Text, Mutator: nil},
		},
	}
}
