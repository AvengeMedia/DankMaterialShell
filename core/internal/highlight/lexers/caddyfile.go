package lexers

import (
	. "github.com/alecthomas/chroma/v2" // nolint
)

// Matcher token stub for docs, or
// Named matcher: @name, or
// Path matcher: /foo, or
// Wildcard path matcher: *
// nolint: gosec
var caddyfileMatcherTokenRegexp = `(\[\<matcher\>\]|@[^\s]+|/[^\s]+|\*)`

// Comment at start of line, or
// Comment preceded by whitespace
var caddyfileCommentRegexp = `(^|\s+)#.*\n`

// caddyfileCommon are the rules common to both of the lexer variants
func caddyfileCommonRules() Rules {
	return Rules{
		"site_block_common": {
			Include("site_body"),
			// Any other directive
			{Pattern: `[^\s#]+`, Type: Keyword, Mutator: Push("directive")},
			Include("base"),
		},
		"site_body": {
			// Import keyword
			{Pattern: `\b(import|invoke)\b( [^\s#]+)`, Type: ByGroups(Keyword, Text), Mutator: Push("subdirective")},
			// Matcher definition
			{Pattern: `@[^\s]+(?=\s)`, Type: NameDecorator, Mutator: Push("matcher")},
			// Matcher token stub for docs
			{Pattern: `\[\<matcher\>\]`, Type: NameDecorator, Mutator: Push("matcher")},
			// These cannot have matchers but may have things that look like
			// matchers in their arguments, so we just parse as a subdirective.
			{Pattern: `\b(try_files|tls|log|bind)\b`, Type: Keyword, Mutator: Push("subdirective")},
			// These are special, they can nest more directives
			{Pattern: `\b(handle_errors|handle_path|handle_response|replace_status|handle|route)\b`, Type: Keyword, Mutator: Push("nested_directive")},
			// uri directive has special syntax
			{Pattern: `\b(uri)\b`, Type: Keyword, Mutator: Push("uri_directive")},
		},
		"matcher": {
			{Pattern: `\{`, Type: Punctuation, Mutator: Push("block")},
			// Not can be one-liner
			{Pattern: `not`, Type: Keyword, Mutator: Push("deep_not_matcher")},
			// Heredoc for CEL expression
			Include("heredoc"),
			// Backtick for CEL expression
			{Pattern: "`", Type: StringBacktick, Mutator: Push("backticks")},
			// Any other same-line matcher
			{Pattern: `[^\s#]+`, Type: Keyword, Mutator: Push("arguments")},
			// Terminators
			{Pattern: `\s*\n`, Type: Text, Mutator: Pop(1)},
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			Include("base"),
		},
		"block": {
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(2)},
			// Using double quotes doesn't stop at spaces
			{Pattern: `"`, Type: StringDouble, Mutator: Push("double_quotes")},
			// Using backticks doesn't stop at spaces
			{Pattern: "`", Type: StringBacktick, Mutator: Push("backticks")},
			// Not can be one-liner
			{Pattern: `not`, Type: Keyword, Mutator: Push("not_matcher")},
			// Directives & matcher definitions
			Include("site_body"),
			// Any directive
			{Pattern: `[^\s#]+`, Type: Keyword, Mutator: Push("subdirective")},
			Include("base"),
		},
		"nested_block": {
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(2)},
			// Using double quotes doesn't stop at spaces
			{Pattern: `"`, Type: StringDouble, Mutator: Push("double_quotes")},
			// Using backticks doesn't stop at spaces
			{Pattern: "`", Type: StringBacktick, Mutator: Push("backticks")},
			// Not can be one-liner
			{Pattern: `not`, Type: Keyword, Mutator: Push("not_matcher")},
			// Directives & matcher definitions
			Include("site_body"),
			// Any other subdirective
			{Pattern: `[^\s#]+`, Type: Keyword, Mutator: Push("directive")},
			Include("base"),
		},
		"not_matcher": {
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(2)},
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("block")},
			{Pattern: `[^\s#]+`, Type: Keyword, Mutator: Push("arguments")},
			{Pattern: `\s+`, Type: Text, Mutator: nil},
		},
		"deep_not_matcher": {
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(2)},
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("block")},
			{Pattern: `[^\s#]+`, Type: Keyword, Mutator: Push("deep_subdirective")},
			{Pattern: `\s+`, Type: Text, Mutator: nil},
		},
		"directive": {
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("block")},
			{Pattern: caddyfileMatcherTokenRegexp, Type: NameDecorator, Mutator: Push("arguments")},
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: Pop(1)},
			{Pattern: `\s*\n`, Type: Text, Mutator: Pop(1)},
			Include("base"),
		},
		"nested_directive": {
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("nested_block")},
			{Pattern: caddyfileMatcherTokenRegexp, Type: NameDecorator, Mutator: Push("nested_arguments")},
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: Pop(1)},
			{Pattern: `\s*\n`, Type: Text, Mutator: Pop(1)},
			Include("base"),
		},
		"subdirective": {
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("block")},
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: Pop(1)},
			{Pattern: `\s*\n`, Type: Text, Mutator: Pop(1)},
			Include("base"),
		},
		"arguments": {
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("block")},
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: Pop(2)},
			{Pattern: `\\\n`, Type: Text, Mutator: nil}, // Skip escaped newlines
			{Pattern: `\s*\n`, Type: Text, Mutator: Pop(2)},
			Include("base"),
		},
		"nested_arguments": {
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("nested_block")},
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: Pop(2)},
			{Pattern: `\\\n`, Type: Text, Mutator: nil}, // Skip escaped newlines
			{Pattern: `\s*\n`, Type: Text, Mutator: Pop(2)},
			Include("base"),
		},
		"deep_subdirective": {
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("block")},
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: Pop(3)},
			{Pattern: `\s*\n`, Type: Text, Mutator: Pop(3)},
			Include("base"),
		},
		"uri_directive": {
			{Pattern: `\{(?=\s)`, Type: Punctuation, Mutator: Push("block")},
			{Pattern: caddyfileMatcherTokenRegexp, Type: NameDecorator, Mutator: nil},
			{Pattern: `(strip_prefix|strip_suffix|replace|path_regexp)`, Type: NameConstant, Mutator: Push("arguments")},
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: Pop(1)},
			{Pattern: `\s*\n`, Type: Text, Mutator: Pop(1)},
			Include("base"),
		},
		"double_quotes": {
			Include("placeholder"),
			{Pattern: `\\"`, Type: StringDouble, Mutator: nil},
			{Pattern: `[^"]`, Type: StringDouble, Mutator: nil},
			{Pattern: `"`, Type: StringDouble, Mutator: Pop(1)},
		},
		"backticks": {
			Include("placeholder"),
			{Pattern: "\\\\`", Type: StringBacktick, Mutator: nil},
			{Pattern: "[^`]", Type: StringBacktick, Mutator: nil},
			{Pattern: "`", Type: StringBacktick, Mutator: Pop(1)},
		},
		"optional": {
			// Docs syntax for showing optional parts with [ ]
			{Pattern: `\[`, Type: Punctuation, Mutator: Push("optional")},
			Include("name_constants"),
			{Pattern: `\|`, Type: Punctuation, Mutator: nil},
			{Pattern: `[^\[\]\|]+`, Type: String, Mutator: nil},
			{Pattern: `\]`, Type: Punctuation, Mutator: Pop(1)},
		},
		"heredoc": {
			{Pattern: `(<<([a-zA-Z0-9_-]+))(\n(.*|\n)*)(\s*)(\2)`, Type: ByGroups(StringHeredoc, nil, String, String, String, StringHeredoc), Mutator: nil},
		},
		"name_constants": {
			{Pattern: `\b(most_recently_modified|largest_size|smallest_size|first_exist|internal|disable_redirects|ignore_loaded_certs|disable_certs|private_ranges|first|last|before|after|on|off)\b(\||(?=\]|\s|$))`, Type: ByGroups(NameConstant, Punctuation), Mutator: nil},
		},
		"placeholder": {
			// Placeholder with dots, colon for default value, brackets for args[0:]
			{Pattern: `\{[\w+.\[\]\:\$-]+\}`, Type: StringEscape, Mutator: nil},
			// Handle opening brackets with no matching closing one
			{Pattern: `\{[^\}\s]*\b`, Type: String, Mutator: nil},
		},
		"base": {
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: nil},
			{Pattern: `\[\<matcher\>\]`, Type: NameDecorator, Mutator: nil},
			Include("name_constants"),
			Include("heredoc"),
			{Pattern: `(https?://)?([a-z0-9.-]+)(:)([0-9]+)([^\s]*)`, Type: ByGroups(Name, Name, Punctuation, NumberInteger, Name), Mutator: nil},
			{Pattern: `\[`, Type: Punctuation, Mutator: Push("optional")},
			{Pattern: "`", Type: StringBacktick, Mutator: Push("backticks")},
			{Pattern: `"`, Type: StringDouble, Mutator: Push("double_quotes")},
			Include("placeholder"),
			{Pattern: `[a-z-]+/[a-z-+]+`, Type: String, Mutator: nil},
			{Pattern: `[0-9]+([smhdk]|ns|us|µs|ms)?\b`, Type: NumberInteger, Mutator: nil},
			{Pattern: `[^\s\n#\{]+`, Type: String, Mutator: nil},
			{Pattern: `/[^\s#]*`, Type: Name, Mutator: nil},
			{Pattern: `\s+`, Type: Text, Mutator: nil},
		},
	}
}

// Caddyfile lexer.
var Caddyfile = Register(MustNewLexer(
	&Config{
		Name:      "Caddyfile",
		Aliases:   []string{"caddyfile", "caddy"},
		Filenames: []string{"Caddyfile*"},
		MimeTypes: []string{},
	},
	caddyfileRules,
))

func caddyfileRules() Rules {
	return Rules{
		"root": {
			{Pattern: caddyfileCommentRegexp, Type: CommentSingle, Mutator: nil},
			// Global options block
			{Pattern: `^\s*(\{)\s*$`, Type: ByGroups(Punctuation), Mutator: Push("globals")},
			// Top level import
			{Pattern: `(import)(\s+)([^\s]+)`, Type: ByGroups(Keyword, Text, NameVariableMagic), Mutator: nil},
			// Snippets
			{Pattern: `(&?\([^\s#]+\))(\s*)(\{)`, Type: ByGroups(NameVariableAnonymous, Text, Punctuation), Mutator: Push("snippet")},
			// Site label
			{Pattern: `[^#{(\s,]+`, Type: GenericHeading, Mutator: Push("label")},
			// Site label with placeholder
			{Pattern: `\{[\w+.\[\]\:\$-]+\}`, Type: StringEscape, Mutator: Push("label")},
			{Pattern: `\s+`, Type: Text, Mutator: nil},
		},
		"globals": {
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			// Global options are parsed as subdirectives (no matcher)
			{Pattern: `[^\s#]+`, Type: Keyword, Mutator: Push("subdirective")},
			Include("base"),
		},
		"snippet": {
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			Include("site_body"),
			// Any other directive
			{Pattern: `[^\s#]+`, Type: Keyword, Mutator: Push("directive")},
			Include("base"),
		},
		"label": {
			// Allow multiple labels, comma separated, newlines after
			// a comma means another label is coming
			{Pattern: `,\s*\n?`, Type: Text, Mutator: nil},
			{Pattern: ` `, Type: Text, Mutator: nil},
			// Site label with placeholder
			Include("placeholder"),
			// Site label
			{Pattern: `[^#{(\s,]+`, Type: GenericHeading, Mutator: nil},
			// Comment after non-block label (hack because comments end in \n)
			{Pattern: `#.*\n`, Type: CommentSingle, Mutator: Push("site_block")},
			// Note: if \n, we'll never pop out of the site_block, it's valid
			{Pattern: `\{(?=\s)|\n`, Type: Punctuation, Mutator: Push("site_block")},
		},
		"site_block": {
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(2)},
			Include("site_block_common"),
		},
	}.Merge(caddyfileCommonRules())
}

// Caddyfile directive-only lexer.
var CaddyfileDirectives = Register(MustNewLexer(
	&Config{
		Name:      "Caddyfile Directives",
		Aliases:   []string{"caddyfile-directives", "caddyfile-d", "caddy-d"},
		Filenames: []string{},
		MimeTypes: []string{},
	},
	caddyfileDirectivesRules,
))

func caddyfileDirectivesRules() Rules {
	return Rules{
		// Same as "site_block" in Caddyfile
		"root": {
			Include("site_block_common"),
		},
	}.Merge(caddyfileCommonRules())
}
