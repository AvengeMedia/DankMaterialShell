package lexers

import (
	. "github.com/alecthomas/chroma/v2" // nolint
)

// Markless lexer.
var Markless = Register(MustNewLexer(
	&Config{
		Name:      "Markless",
		Aliases:   []string{"mess"},
		Filenames: []string{"*.mess", "*.markless"},
		MimeTypes: []string{"text/x-markless"},
	},
	marklessRules,
))

func marklessRules() Rules {
	return Rules{
		"root": {
			Include("block"),
		},
		// Block directives
		"block": {
			Include("header"),
			Include("ordered-list"),
			Include("unordered-list"),
			Include("code-block"),
			Include("blockquote"),
			Include("blockquote-header"),
			Include("align"),
			Include("comment"),
			Include("instruction"),
			Include("embed"),
			Include("footnote"),
			Include("horizontal-rule"),
			Include("paragraph"),
		},
		"header": {
			{Pattern: `(# )(.*)$`, Type: ByGroups(Keyword, GenericHeading), Mutator: Push("inline")},
			{Pattern: `(##+)(.*)$`, Type: ByGroups(Keyword, GenericSubheading), Mutator: Push("inline")},
		},
		"ordered-list": {
			{Pattern: `([0-9]+\.)`, Type: Keyword, Mutator: nil},
		},
		"unordered-list": {
			{Pattern: `(- )`, Type: Keyword, Mutator: nil},
		},
		"code-block": {
			{Pattern: `(::+)( *)(\w*)([^\n]*)(\n)([\w\W]*?)(^\1$)`, Type: UsingByGroup(3, 6, Keyword, TextWhitespace, NameFunction, String, TextWhitespace, Text, Keyword), Mutator: nil},
		},
		"blockquote": {
			{Pattern: `(\| )(.*)$`, Type: ByGroups(Keyword, GenericInserted), Mutator: nil},
		},
		"blockquote-header": {
			{Pattern: `(~ )([^|\n]+)(\| )(.*?\n)`, Type: ByGroups(Keyword, NameEntity, Keyword, GenericInserted), Mutator: Push("inline-blockquote")},
			{Pattern: `(~ )(.*)$`, Type: ByGroups(Keyword, NameEntity), Mutator: nil},
		},
		"inline-blockquote": {
			{Pattern: `^(   +)(\| )(.*$)`, Type: ByGroups(TextWhitespace, Keyword, GenericInserted), Mutator: nil},
			Default(Pop(1)),
		},
		"align": {
			{Pattern: `(\|\|)|(\|<)|(\|>)|(><)`, Type: Keyword, Mutator: nil},
		},
		"comment": {
			{Pattern: `(;[; ]).*?$`, Type: CommentSingle, Mutator: nil},
		},
		"instruction": {
			{Pattern: `(! )([^ ]+)(.+?)$`, Type: ByGroups(Keyword, NameFunction, NameVariable), Mutator: nil},
		},
		"embed": {
			{Pattern: `(\[ )([^ ]+)( )([^,\]\n]+)`, Type: ByGroups(Keyword, NameFunction, TextWhitespace, String), Mutator: Push("embed-options")},
		},
		"embed-options": {
			{Pattern: `\\.`, Type: Text, Mutator: nil},
			{Pattern: `,`, Type: Punctuation, Mutator: nil},
			{Pattern: `\]?$`, Type: Keyword, Mutator: Pop(1)},
			// Generic key or key/value pair
			{Pattern: `( *)([^, \]\n]+)([^,\]\n]+)?`, Type: ByGroups(TextWhitespace, NameFunction, String), Mutator: nil},
			{Pattern: `.`, Type: Text, Mutator: nil},
		},
		"footnote": {
			{Pattern: `(\[)([0-9]+)(\])`, Type: ByGroups(Keyword, NameVariable, Keyword), Mutator: Push("inline")},
		},
		"horizontal-rule": {
			{Pattern: `(==+)$`, Type: LiteralOther, Mutator: nil},
		},
		"paragraph": {
			{Pattern: ` *`, Type: TextWhitespace, Mutator: Push("inline")},
		},
		// Inline directives
		"inline": {
			Include("escapes"),
			Include("dashes"),
			Include("newline"),
			Include("italic"),
			Include("underline"),
			Include("bold"),
			Include("strikethrough"),
			Include("code"),
			Include("compound"),
			Include("footnote-reference"),
			Include("subtext"),
			Include("subtext"),
			Include("url"),
			{Pattern: `.`, Type: Text, Mutator: nil},
			{Pattern: `\n`, Type: TextWhitespace, Mutator: Pop(1)},
		},
		"escapes": {
			{Pattern: `\\.`, Type: Text, Mutator: nil},
		},
		"dashes": {
			{Pattern: `-{2,3}`, Type: TextPunctuation, Mutator: nil},
		},
		"newline": {
			{Pattern: `-/-`, Type: TextWhitespace, Mutator: nil},
		},
		"italic": {
			{Pattern: `(//)(.*?)(\1)`, Type: ByGroups(Keyword, GenericEmph, Keyword), Mutator: nil},
		},
		"underline": {
			{Pattern: `(__)(.*?)(\1)`, Type: ByGroups(Keyword, GenericUnderline, Keyword), Mutator: nil},
		},
		"bold": {
			{Pattern: `(\*\*)(.*?)(\1)`, Type: ByGroups(Keyword, GenericStrong, Keyword), Mutator: nil},
		},
		"strikethrough": {
			{Pattern: `(<-)(.*?)(->)`, Type: ByGroups(Keyword, GenericDeleted, Keyword), Mutator: nil},
		},
		"code": {
			{Pattern: "(``+)(.*?)(\\1)", Type: ByGroups(Keyword, LiteralStringBacktick, Keyword), Mutator: nil},
		},
		"compound": {
			{Pattern: `(''+)(.*?)(''\()`, Type: ByGroups(Keyword, UsingSelf("inline"), Keyword), Mutator: Push("compound-options")},
		},
		"compound-options": {
			{Pattern: `\\.`, Type: Text, Mutator: nil},
			{Pattern: `,`, Type: Punctuation, Mutator: nil},
			{Pattern: `\)`, Type: Keyword, Mutator: Pop(1)},
			// Hex Color
			{Pattern: ` *#[0-9A-Fa-f]{3,6} *`, Type: LiteralNumberHex, Mutator: nil},
			// Named Color
			{Pattern: ` *(indian-red|light-coral|salmon|dark-salmon|light-salmon|crimson|red|firebrick|dark-red|pink|light-pink|hot-pink|deep-pink|medium-violet-red|pale-violet-red|coral|tomato|orange-red|dark-orange|orange|gold|yellow|light-yellow|lemon-chiffon|light-goldenrod-yellow|papayawhip|moccasin|peachpuff|pale-goldenrod|khaki|dark-khaki|lavender|thistle|plum|violet|orchid|fuchsia|magenta|medium-orchid|medium-purple|rebecca-purple|blue-violet|dark-violet|dark-orchid|dark-magenta|purple|indigo|slate-blue|dark-slate-blue|medium-slate-blue|green-yellow|chartreuse|lawn-green|lime|lime-green|pale-green|light-green|medium-spring-green|spring-green|medium-sea-green|sea-green|forest-green|green|dark-green|yellow-green|olive-drab|olive|dark-olive-green|medium-aquamarine|dark-sea-green|light-sea-green|dark-cyan|teal|aqua|cyan|light-cyan|pale-turquoise|aquamarine|turquoise|medium-turquoise|dark-turquoise|cadet-blue|steel-blue|light-steel-blue|powder-blue|light-blue|sky-blue|light-sky-blue|deep-sky-blue|dodger-blue|cornflower-blue|royal-blue|blue|medium-blue|dark-blue|navy|midnight-blue|cornsilk|blanched-almond|bisque|navajo-white|wheat|burlywood|tan|rosy-brown|sandy-brown|goldenrod|dark-goldenrod|peru|chocolate|saddle-brown|sienna|brown|maroon|white|snow|honeydew|mintcream|azure|alice-blue|ghost-white|white-smoke|seashell|beige|oldlace|floral-white|ivory|antique-white|linen|lavenderblush|mistyrose|gainsboro|light-gray|silver|dark-gray|gray|dim-gray|light-slate-gray|slate-gray|dark-slate-gray) *`, Type: LiteralOther, Mutator: nil},
			// Named size
			{Pattern: ` *(microscopic|tiny|small|normal|big|large|huge|gigantic) *`, Type: NameTag, Mutator: nil},
			// Options
			{Pattern: ` *(bold|italic|underline|strikethrough|subtext|supertext|spoiler) *`, Type: NameBuiltin, Mutator: nil},
			// URL. Note the missing ) and , in the match.
			{Pattern: ` *\w[-\w+.]*://[\w$\-_.+!*'(&/:;=?@z%#\\]+ *`, Type: String, Mutator: nil},
			// Generic key or key/value pair
			{Pattern: `( *)([^, )]+)( [^,)]+)?`, Type: ByGroups(TextWhitespace, NameFunction, String), Mutator: nil},
			{Pattern: `.`, Type: Text, Mutator: nil},
		},
		"footnote-reference": {
			{Pattern: `(\[)([0-9]+)(\])`, Type: ByGroups(Keyword, NameVariable, Keyword), Mutator: nil},
		},
		"subtext": {
			{Pattern: `(v\()(.*?)(\))`, Type: ByGroups(Keyword, UsingSelf("inline"), Keyword), Mutator: nil},
		},
		"supertext": {
			{Pattern: `(\^\()(.*?)(\))`, Type: ByGroups(Keyword, UsingSelf("inline"), Keyword), Mutator: nil},
		},
		"url": {
			{Pattern: `\w[-\w+.]*://[\w\$\-_.+!*'()&,/:;=?@z%#\\]+`, Type: String, Mutator: nil},
		},
	}
}
