package lexers

import (
	. "github.com/alecthomas/chroma/v2" // nolint
)

// Typoscript lexer.
var Typoscript = Register(MustNewLexer(
	&Config{
		Name:      "TypoScript",
		Aliases:   []string{"typoscript"},
		Filenames: []string{"*.ts"},
		MimeTypes: []string{"text/x-typoscript"},
		DotAll:    true,
		Priority:  0.1,
	},
	typoscriptRules,
))

func typoscriptRules() Rules {
	return Rules{
		"root": {
			Include("comment"),
			Include("constant"),
			Include("html"),
			Include("label"),
			Include("whitespace"),
			Include("keywords"),
			Include("punctuation"),
			Include("operator"),
			Include("structure"),
			Include("literal"),
			Include("other"),
		},
		"keywords": {
			{Pattern: `(\[)(?i)(browser|compatVersion|dayofmonth|dayofweek|dayofyear|device|ELSE|END|GLOBAL|globalString|globalVar|hostname|hour|IP|language|loginUser|loginuser|minute|month|page|PIDinRootline|PIDupinRootline|system|treeLevel|useragent|userFunc|usergroup|version)([^\]]*)(\])`, Type: ByGroups(LiteralStringSymbol, NameConstant, Text, LiteralStringSymbol), Mutator: nil},
			{Pattern: `(?=[\w\-])(HTMLparser|HTMLparser_tags|addParams|cache|encapsLines|filelink|if|imageLinkWrap|imgResource|makelinks|numRows|numberFormat|parseFunc|replacement|round|select|split|stdWrap|strPad|tableStyle|tags|textStyle|typolink)(?![\w\-])`, Type: NameFunction, Mutator: nil},
			{Pattern: `(?:(=?\s*<?\s+|^\s*))(cObj|field|config|content|constants|FEData|file|frameset|includeLibs|lib|page|plugin|register|resources|sitemap|sitetitle|styles|temp|tt_[^:.\s]*|types|xmlnews|INCLUDE_TYPOSCRIPT|_CSS_DEFAULT_STYLE|_DEFAULT_PI_VARS|_LOCAL_LANG)(?![\w\-])`, Type: ByGroups(Operator, NameBuiltin), Mutator: nil},
			{Pattern: `(?=[\w\-])(CASE|CLEARGIF|COA|COA_INT|COBJ_ARRAY|COLUMNS|CONTENT|CTABLE|EDITPANEL|FILE|FILES|FLUIDTEMPLATE|FORM|HMENU|HRULER|HTML|IMAGE|IMGTEXT|IMG_RESOURCE|LOAD_REGISTER|MEDIA|MULTIMEDIA|OTABLE|PAGE|QTOBJECT|RECORDS|RESTORE_REGISTER|SEARCHRESULT|SVG|SWFOBJECT|TEMPLATE|TEXT|USER|USER_INT)(?![\w\-])`, Type: NameClass, Mutator: nil},
			{Pattern: `(?=[\w\-])(ACTIFSUBRO|ACTIFSUB|ACTRO|ACT|CURIFSUBRO|CURIFSUB|CURRO|CUR|IFSUBRO|IFSUB|NO|SPC|USERDEF1RO|USERDEF1|USERDEF2RO|USERDEF2|USRRO|USR)`, Type: NameClass, Mutator: nil},
			{Pattern: `(?=[\w\-])(GMENU_FOLDOUT|GMENU_LAYERS|GMENU|IMGMENUITEM|IMGMENU|JSMENUITEM|JSMENU|TMENUITEM|TMENU_LAYERS|TMENU)`, Type: NameClass, Mutator: nil},
			{Pattern: `(?=[\w\-])(PHP_SCRIPT(_EXT|_INT)?)`, Type: NameClass, Mutator: nil},
			{Pattern: `(?=[\w\-])(userFunc)(?![\w\-])`, Type: NameFunction, Mutator: nil},
		},
		"whitespace": {
			{Pattern: `\s+`, Type: Text, Mutator: nil},
		},
		"html": {
			{Pattern: `<\S[^\n>]*>`, Type: Using("TypoScriptHTMLData"), Mutator: nil},
			{Pattern: `&[^;\n]*;`, Type: LiteralString, Mutator: nil},
			{Pattern: `(_CSS_DEFAULT_STYLE)(\s*)(\()(?s)(.*(?=\n\)))`, Type: ByGroups(NameClass, Text, LiteralStringSymbol, Using("TypoScriptCSSData")), Mutator: nil},
		},
		"literal": {
			{Pattern: `0x[0-9A-Fa-f]+t?`, Type: LiteralNumberHex, Mutator: nil},
			{Pattern: `[0-9]+`, Type: LiteralNumberInteger, Mutator: nil},
			{Pattern: `(###\w+###)`, Type: NameConstant, Mutator: nil},
		},
		"label": {
			{Pattern: `(EXT|FILE|LLL):[^}\n"]*`, Type: LiteralString, Mutator: nil},
			{Pattern: `(?![^\w\-])([\w\-]+(?:/[\w\-]+)+/?)(\S*\n)`, Type: ByGroups(LiteralString, LiteralString), Mutator: nil},
		},
		"punctuation": {
			{Pattern: `[,.]`, Type: Punctuation, Mutator: nil},
		},
		"operator": {
			{Pattern: `[<>,:=.*%+|]`, Type: Operator, Mutator: nil},
		},
		"structure": {
			{Pattern: `[{}()\[\]\\]`, Type: LiteralStringSymbol, Mutator: nil},
		},
		"constant": {
			{Pattern: `(\{)(\$)((?:[\w\-]+\.)*)([\w\-]+)(\})`, Type: ByGroups(LiteralStringSymbol, Operator, NameConstant, NameConstant, LiteralStringSymbol), Mutator: nil},
			{Pattern: `(\{)([\w\-]+)(\s*:\s*)([\w\-]+)(\})`, Type: ByGroups(LiteralStringSymbol, NameConstant, Operator, NameConstant, LiteralStringSymbol), Mutator: nil},
			{Pattern: `(#[a-fA-F0-9]{6}\b|#[a-fA-F0-9]{3}\b)`, Type: LiteralStringChar, Mutator: nil},
		},
		"comment": {
			{Pattern: `(?<!(#|\'|"))(?:#(?!(?:[a-fA-F0-9]{6}|[a-fA-F0-9]{3}))[^\n#]+|//[^\n]*)`, Type: Comment, Mutator: nil},
			{Pattern: `/\*(?:(?!\*/).)*\*/`, Type: Comment, Mutator: nil},
			{Pattern: `(\s*#\s*\n)`, Type: Comment, Mutator: nil},
		},
		"other": {
			{Pattern: `[\w"\-!/&;]+`, Type: Text, Mutator: nil},
		},
	}
}
