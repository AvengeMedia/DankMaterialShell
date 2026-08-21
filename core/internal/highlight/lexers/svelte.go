package lexers

import (
	. "github.com/alecthomas/chroma/v2" // nolint
)

// Svelte lexer.
var Svelte = Register(DelegatingLexer(HTML, MustNewLexer(
	&Config{
		Name:      "Svelte",
		Aliases:   []string{"svelte"},
		Filenames: []string{"*.svelte"},
		MimeTypes: []string{"application/x-svelte"},
		DotAll:    true,
	},
	svelteRules,
)))

func svelteRules() Rules {
	return Rules{
		"root": {
			// Let HTML handle the comments, including comments containing script and style tags
			{Pattern: `<!--`, Type: Other, Mutator: Push("comment")},
			{
				// Highlight script and style tags based on lang attribute
				// and allow attributes besides lang
				Pattern: `(<\s*(?:script|style).*?lang\s*=\s*['"])` +
					`(.+?)(['"].*?>)` +
					`(.+?)` +
					`(<\s*/\s*(?:script|style)\s*>)`,
				Type:    UsingByGroup(2, 4, Other, Other, Other, Other, Other),
				Mutator: nil,
			},
			{
				// Make sure `{` is not inside script or style tags
				Pattern: `(?<!<\s*(?:script|style)(?:(?!(?:script|style)\s*>).)*?)` +
					`{` +
					`(?!(?:(?!<\s*(?:script|style)).)*?(?:script|style)\s*>)`,
				Type:    Punctuation,
				Mutator: Push("templates"),
			},
			// on:submit|preventDefault
			{Pattern: `(?<=\s+on:\w+(?:\|\w+)*)\|(?=\w+)`, Type: Operator, Mutator: nil},
			{Pattern: `.+?`, Type: Other, Mutator: nil},
		},
		"comment": {
			{Pattern: `-->`, Type: Other, Mutator: Pop(1)},
			{Pattern: `.+?`, Type: Other, Mutator: nil},
		},
		"templates": {
			{Pattern: `}`, Type: Punctuation, Mutator: Pop(1)},
			// Let TypeScript handle strings and the curly braces inside them
			{Pattern: `(?<!(?<!\\)\\)(['"` + "`])" + `.*?(?<!(?<!\\)\\)\1`, Type: Using("TypeScript"), Mutator: nil},
			// If there is another opening curly brace push to templates again
			{Pattern: "{", Type: Punctuation, Mutator: Push("templates")},
			{Pattern: `@(debug|html)\b`, Type: Keyword, Mutator: nil},
			{
				Pattern: `(#await)(\s+)(\w+)(\s+)(then|catch)(\s+)(\w+)`,
				Type: ByGroups(Keyword, Text, Using("TypeScript"), Text,
					Keyword, Text, Using("TypeScript"),
				),
				Mutator: nil,
			},
			{Pattern: `(#|/)(await|each|if|key)\b`, Type: Keyword, Mutator: nil},
			{Pattern: `(:else)(\s+)(if)?\b`, Type: ByGroups(Keyword, Text, Keyword), Mutator: nil},
			{Pattern: `:(catch|then)\b`, Type: Keyword, Mutator: nil},
			{Pattern: `[^{}]+`, Type: Using("TypeScript"), Mutator: nil},
		},
	}
}
