package lexers

import (
	. "github.com/alecthomas/chroma/v2" // nolint
)

// Gemtext lexer.
var Gemtext = Register(MustNewLexer(
	&Config{
		Name:      "Gemtext",
		Aliases:   []string{"gemtext", "gmi", "gmni", "gemini"},
		Filenames: []string{"*.gmi", "*.gmni", "*.gemini"},
		MimeTypes: []string{"text/gemini"},
	},
	gemtextRules,
))

func gemtextRules() Rules {
	return Rules{
		"root": {
			{Pattern: `^(#[^#].+\r?\n)`, Type: ByGroups(GenericHeading), Mutator: nil},
			{Pattern: `^(#{2,3}.+\r?\n)`, Type: ByGroups(GenericSubheading), Mutator: nil},
			{Pattern: `^(\* )(.+\r?\n)`, Type: ByGroups(Keyword, Text), Mutator: nil},
			{Pattern: `^(>)(.+\r?\n)`, Type: ByGroups(Keyword, GenericEmph), Mutator: nil},
			{Pattern: "^(```\\r?\\n)([\\w\\W]*?)(^```)(.+\\r?\\n)?", Type: ByGroups(String, Text, String, Comment), Mutator: nil},
			{
				Pattern: "^(```)(\\w+)(\\r?\\n)([\\w\\W]*?)(^```)(.+\\r?\\n)?",
				Type:    UsingByGroup(2, 4, String, String, String, Text, String, Comment),
				Mutator: nil,
			},
			{Pattern: "^(```)(.+\\r?\\n)([\\w\\W]*?)(^```)(.+\\r?\\n)?", Type: ByGroups(String, String, Text, String, Comment), Mutator: nil},
			{Pattern: `^(=>)(\s*)([^\s]+)(\s*)$`, Type: ByGroups(Keyword, Text, NameAttribute, Text), Mutator: nil},
			{Pattern: `^(=>)(\s*)([^\s]+)(\s+)(.+)$`, Type: ByGroups(Keyword, Text, NameAttribute, Text, NameTag), Mutator: nil},
			{Pattern: `(.|(?:\r?\n))`, Type: ByGroups(Text), Mutator: nil},
		},
	}
}
