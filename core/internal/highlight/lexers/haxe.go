package lexers

import (
	. "github.com/alecthomas/chroma/v2" // nolint
)

// Haxe lexer.
var Haxe = Register(MustNewLexer(
	&Config{
		Name:      "Haxe",
		Aliases:   []string{"hx", "haxe", "hxsl"},
		Filenames: []string{"*.hx", "*.hxsl"},
		MimeTypes: []string{"text/haxe", "text/x-haxe", "text/x-hx"},
		DotAll:    true,
	},
	haxeRules,
))

func haxeRules() Rules {
	return Rules{
		"root": {
			Include("spaces"),
			Include("meta"),
			{Pattern: `(?:package)\b`, Type: KeywordNamespace, Mutator: Push("semicolon", "package")},
			{Pattern: `(?:import)\b`, Type: KeywordNamespace, Mutator: Push("semicolon", "import")},
			{Pattern: `(?:using)\b`, Type: KeywordNamespace, Mutator: Push("semicolon", "using")},
			{Pattern: `(?:extern|private)\b`, Type: KeywordDeclaration, Mutator: nil},
			{Pattern: `(?:abstract)\b`, Type: KeywordDeclaration, Mutator: Push("abstract")},
			{Pattern: `(?:class|interface)\b`, Type: KeywordDeclaration, Mutator: Push("class")},
			{Pattern: `(?:enum)\b`, Type: KeywordDeclaration, Mutator: Push("enum")},
			{Pattern: `(?:typedef)\b`, Type: KeywordDeclaration, Mutator: Push("typedef")},
			{Pattern: `(?=.)`, Type: Text, Mutator: Push("expr-statement")},
		},
		"spaces": {
			{Pattern: `\s+`, Type: Text, Mutator: nil},
			{Pattern: `//[^\n\r]*`, Type: CommentSingle, Mutator: nil},
			{Pattern: `/\*.*?\*/`, Type: CommentMultiline, Mutator: nil},
			{Pattern: `(#)(if|elseif|else|end|error)\b`, Type: CommentPreproc, Mutator: MutatorFunc(haxePreProcMutator)},
		},
		"string-single-interpol": {
			{Pattern: `\$\{`, Type: LiteralStringInterpol, Mutator: Push("string-interpol-close", "expr")},
			{Pattern: `\$\$`, Type: LiteralStringEscape, Mutator: nil},
			{Pattern: `\$(?=(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+))`, Type: LiteralStringInterpol, Mutator: Push("ident")},
			Include("string-single"),
		},
		"string-single": {
			{Pattern: `'`, Type: LiteralStringSingle, Mutator: Pop(1)},
			{Pattern: `\\.`, Type: LiteralStringEscape, Mutator: nil},
			{Pattern: `.`, Type: LiteralStringSingle, Mutator: nil},
		},
		"string-double": {
			{Pattern: `"`, Type: LiteralStringDouble, Mutator: Pop(1)},
			{Pattern: `\\.`, Type: LiteralStringEscape, Mutator: nil},
			{Pattern: `.`, Type: LiteralStringDouble, Mutator: nil},
		},
		"string-interpol-close": {
			{Pattern: `\$(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: LiteralStringInterpol, Mutator: nil},
			{Pattern: `\}`, Type: LiteralStringInterpol, Mutator: Pop(1)},
		},
		"package": {
			Include("spaces"),
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: NameNamespace, Mutator: nil},
			{Pattern: `\.`, Type: Punctuation, Mutator: Push("import-ident")},
			Default(Pop(1)),
		},
		"import": {
			Include("spaces"),
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: NameNamespace, Mutator: nil},
			{Pattern: `\*`, Type: Keyword, Mutator: nil},
			{Pattern: `\.`, Type: Punctuation, Mutator: Push("import-ident")},
			{Pattern: `in`, Type: KeywordNamespace, Mutator: Push("ident")},
			Default(Pop(1)),
		},
		"import-ident": {
			Include("spaces"),
			{Pattern: `\*`, Type: Keyword, Mutator: Pop(1)},
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: NameNamespace, Mutator: Pop(1)},
		},
		"using": {
			Include("spaces"),
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: NameNamespace, Mutator: nil},
			{Pattern: `\.`, Type: Punctuation, Mutator: Push("import-ident")},
			Default(Pop(1)),
		},
		"preproc-error": {
			{Pattern: `\s+`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `'`, Type: LiteralStringSingle, Mutator: Push("#pop", "string-single")},
			{Pattern: `"`, Type: LiteralStringDouble, Mutator: Push("#pop", "string-double")},
			Default(Pop(1)),
		},
		"preproc-expr": {
			{Pattern: `\s+`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `\!`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `\(`, Type: CommentPreproc, Mutator: Push("#pop", "preproc-parenthesis")},
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: CommentPreproc, Mutator: Pop(1)},
			{Pattern: `\.[0-9]+`, Type: LiteralNumberFloat, Mutator: nil},
			{Pattern: `[0-9]+[eE][+\-]?[0-9]+`, Type: LiteralNumberFloat, Mutator: nil},
			{Pattern: `[0-9]+\.[0-9]*[eE][+\-]?[0-9]+`, Type: LiteralNumberFloat, Mutator: nil},
			{Pattern: `[0-9]+\.[0-9]+`, Type: LiteralNumberFloat, Mutator: nil},
			{Pattern: `[0-9]+\.(?!(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)|\.\.)`, Type: LiteralNumberFloat, Mutator: nil},
			{Pattern: `0x[0-9a-fA-F]+`, Type: LiteralNumberHex, Mutator: nil},
			{Pattern: `[0-9]+`, Type: LiteralNumberInteger, Mutator: nil},
			{Pattern: `'`, Type: LiteralStringSingle, Mutator: Push("#pop", "string-single")},
			{Pattern: `"`, Type: LiteralStringDouble, Mutator: Push("#pop", "string-double")},
		},
		"preproc-parenthesis": {
			{Pattern: `\s+`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `\)`, Type: CommentPreproc, Mutator: Pop(1)},
			Default(Push("preproc-expr-in-parenthesis")),
		},
		"preproc-expr-chain": {
			{Pattern: `\s+`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `(?:%=|&=|\|=|\^=|\+=|\-=|\*=|/=|<<=|>\s*>\s*=|>\s*>\s*>\s*=|==|!=|<=|>\s*=|&&|\|\||<<|>>>|>\s*>|\.\.\.|<|>|%|&|\||\^|\+|\*|/|\-|=>|=)`, Type: CommentPreproc, Mutator: Push("#pop", "preproc-expr-in-parenthesis")},
			Default(Pop(1)),
		},
		"preproc-expr-in-parenthesis": {
			{Pattern: `\s+`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `\!`, Type: CommentPreproc, Mutator: nil},
			{Pattern: `\(`, Type: CommentPreproc, Mutator: Push("#pop", "preproc-expr-chain", "preproc-parenthesis")},
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: CommentPreproc, Mutator: Push("#pop", "preproc-expr-chain")},
			{Pattern: `\.[0-9]+`, Type: LiteralNumberFloat, Mutator: Push("#pop", "preproc-expr-chain")},
			{Pattern: `[0-9]+[eE][+\-]?[0-9]+`, Type: LiteralNumberFloat, Mutator: Push("#pop", "preproc-expr-chain")},
			{Pattern: `[0-9]+\.[0-9]*[eE][+\-]?[0-9]+`, Type: LiteralNumberFloat, Mutator: Push("#pop", "preproc-expr-chain")},
			{Pattern: `[0-9]+\.[0-9]+`, Type: LiteralNumberFloat, Mutator: Push("#pop", "preproc-expr-chain")},
			{Pattern: `[0-9]+\.(?!(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)|\.\.)`, Type: LiteralNumberFloat, Mutator: Push("#pop", "preproc-expr-chain")},
			{Pattern: `0x[0-9a-fA-F]+`, Type: LiteralNumberHex, Mutator: Push("#pop", "preproc-expr-chain")},
			{Pattern: `[0-9]+`, Type: LiteralNumberInteger, Mutator: Push("#pop", "preproc-expr-chain")},
			{Pattern: `'`, Type: LiteralStringSingle, Mutator: Push("#pop", "preproc-expr-chain", "string-single")},
			{Pattern: `"`, Type: LiteralStringDouble, Mutator: Push("#pop", "preproc-expr-chain", "string-double")},
		},
		"abstract": {
			Include("spaces"),
			Default(Pop(1), Push("abstract-body"), Push("abstract-relation"), Push("abstract-opaque"), Push("type-param-constraint"), Push("type-name")),
		},
		"abstract-body": {
			Include("spaces"),
			{Pattern: `\{`, Type: Punctuation, Mutator: Push("#pop", "class-body")},
		},
		"abstract-opaque": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "parenthesis-close", "type")},
			Default(Pop(1)),
		},
		"abstract-relation": {
			Include("spaces"),
			{Pattern: `(?:to|from)`, Type: KeywordDeclaration, Mutator: Push("type")},
			{Pattern: `,`, Type: Punctuation, Mutator: nil},
			Default(Pop(1)),
		},
		"meta": {
			Include("spaces"),
			{Pattern: `@`, Type: NameDecorator, Mutator: Push("meta-body", "meta-ident", "meta-colon")},
		},
		"meta-colon": {
			Include("spaces"),
			{Pattern: `:`, Type: NameDecorator, Mutator: Pop(1)},
			Default(Pop(1)),
		},
		"meta-ident": {
			Include("spaces"),
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: NameDecorator, Mutator: Pop(1)},
		},
		"meta-body": {
			Include("spaces"),
			{Pattern: `\(`, Type: NameDecorator, Mutator: Push("#pop", "meta-call")},
			Default(Pop(1)),
		},
		"meta-call": {
			Include("spaces"),
			{Pattern: `\)`, Type: NameDecorator, Mutator: Pop(1)},
			Default(Pop(1), Push("meta-call-sep"), Push("expr")),
		},
		"meta-call-sep": {
			Include("spaces"),
			{Pattern: `\)`, Type: NameDecorator, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "meta-call")},
		},
		"typedef": {
			Include("spaces"),
			Default(Pop(1), Push("typedef-body"), Push("type-param-constraint"), Push("type-name")),
		},
		"typedef-body": {
			Include("spaces"),
			{Pattern: `=`, Type: Operator, Mutator: Push("#pop", "optional-semicolon", "type")},
		},
		"enum": {
			Include("spaces"),
			Default(Pop(1), Push("enum-body"), Push("bracket-open"), Push("type-param-constraint"), Push("type-name")),
		},
		"enum-body": {
			Include("spaces"),
			Include("meta"),
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Name, Mutator: Push("enum-member", "type-param-constraint")},
		},
		"enum-member": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "semicolon", "flag", "function-param")},
			Default(Pop(1), Push("semicolon"), Push("flag")),
		},
		"class": {
			Include("spaces"),
			Default(Pop(1), Push("class-body"), Push("bracket-open"), Push("extends"), Push("type-param-constraint"), Push("type-name")),
		},
		"extends": {
			Include("spaces"),
			{Pattern: `(?:extends|implements)\b`, Type: KeywordDeclaration, Mutator: Push("type")},
			{Pattern: `,`, Type: Punctuation, Mutator: nil},
			Default(Pop(1)),
		},
		"bracket-open": {
			Include("spaces"),
			{Pattern: `\{`, Type: Punctuation, Mutator: Pop(1)},
		},
		"bracket-close": {
			Include("spaces"),
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
		},
		"class-body": {
			Include("spaces"),
			Include("meta"),
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `(?:static|public|private|override|dynamic|inline|macro)\b`, Type: KeywordDeclaration, Mutator: nil},
			Default(Push("class-member")),
		},
		"class-member": {
			Include("spaces"),
			{Pattern: `(var)\b`, Type: KeywordDeclaration, Mutator: Push("#pop", "optional-semicolon", "var")},
			{Pattern: `(function)\b`, Type: KeywordDeclaration, Mutator: Push("#pop", "optional-semicolon", "class-method")},
		},
		"function-local": {
			Include("spaces"),
			{Pattern: `(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: NameFunction, Mutator: Push("#pop", "optional-expr", "flag", "function-param", "parenthesis-open", "type-param-constraint")},
			Default(Pop(1), Push("optional-expr"), Push("flag"), Push("function-param"), Push("parenthesis-open"), Push("type-param-constraint")),
		},
		"optional-expr": {
			Include("spaces"),
			Include("expr"),
			Default(Pop(1)),
		},
		"class-method": {
			Include("spaces"),
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: NameFunction, Mutator: Push("#pop", "optional-expr", "flag", "function-param", "parenthesis-open", "type-param-constraint")},
		},
		"function-param": {
			Include("spaces"),
			{Pattern: `\)`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `\?`, Type: Punctuation, Mutator: nil},
			{Pattern: `(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Name, Mutator: Push("#pop", "function-param-sep", "assign", "flag")},
		},
		"function-param-sep": {
			Include("spaces"),
			{Pattern: `\)`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "function-param")},
		},
		"prop-get-set": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "parenthesis-close", "prop-get-set-opt", "comma", "prop-get-set-opt")},
			Default(Pop(1)),
		},
		"prop-get-set-opt": {
			Include("spaces"),
			{Pattern: `(?:default|null|never|dynamic|get|set)\b`, Type: Keyword, Mutator: Pop(1)},
			{Pattern: `(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Text, Mutator: Pop(1)},
		},
		"expr-statement": {
			Include("spaces"),
			Default(Pop(1), Push("optional-semicolon"), Push("expr")),
		},
		"expr": {
			Include("spaces"),
			{Pattern: `@`, Type: NameDecorator, Mutator: Push("#pop", "optional-expr", "meta-body", "meta-ident", "meta-colon")},
			{Pattern: `(?:\+\+|\-\-|~(?!/)|!|\-)`, Type: Operator, Mutator: nil},
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "expr-chain", "parenthesis")},
			{Pattern: `(?:static|public|private|override|dynamic|inline)\b`, Type: KeywordDeclaration, Mutator: nil},
			{Pattern: `(?:function)\b`, Type: KeywordDeclaration, Mutator: Push("#pop", "expr-chain", "function-local")},
			{Pattern: `\{`, Type: Punctuation, Mutator: Push("#pop", "expr-chain", "bracket")},
			{Pattern: `(?:true|false|null)\b`, Type: KeywordConstant, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `(?:this)\b`, Type: Keyword, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `(?:cast)\b`, Type: Keyword, Mutator: Push("#pop", "expr-chain", "cast")},
			{Pattern: `(?:try)\b`, Type: Keyword, Mutator: Push("#pop", "catch", "expr")},
			{Pattern: `(?:var)\b`, Type: KeywordDeclaration, Mutator: Push("#pop", "var")},
			{Pattern: `(?:new)\b`, Type: Keyword, Mutator: Push("#pop", "expr-chain", "new")},
			{Pattern: `(?:switch)\b`, Type: Keyword, Mutator: Push("#pop", "switch")},
			{Pattern: `(?:if)\b`, Type: Keyword, Mutator: Push("#pop", "if")},
			{Pattern: `(?:do)\b`, Type: Keyword, Mutator: Push("#pop", "do")},
			{Pattern: `(?:while)\b`, Type: Keyword, Mutator: Push("#pop", "while")},
			{Pattern: `(?:for)\b`, Type: Keyword, Mutator: Push("#pop", "for")},
			{Pattern: `(?:untyped|throw)\b`, Type: Keyword, Mutator: nil},
			{Pattern: `(?:return)\b`, Type: Keyword, Mutator: Push("#pop", "optional-expr")},
			{Pattern: `(?:macro)\b`, Type: Keyword, Mutator: Push("#pop", "macro")},
			{Pattern: `(?:continue|break)\b`, Type: Keyword, Mutator: Pop(1)},
			{Pattern: `(?:\$\s*[a-z]\b|\$(?!(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)))`, Type: Name, Mutator: Push("#pop", "dollar")},
			{Pattern: `(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Name, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `\.[0-9]+`, Type: LiteralNumberFloat, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `[0-9]+[eE][+\-]?[0-9]+`, Type: LiteralNumberFloat, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `[0-9]+\.[0-9]*[eE][+\-]?[0-9]+`, Type: LiteralNumberFloat, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `[0-9]+\.[0-9]+`, Type: LiteralNumberFloat, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `[0-9]+\.(?!(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)|\.\.)`, Type: LiteralNumberFloat, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `0x[0-9a-fA-F]+`, Type: LiteralNumberHex, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `[0-9]+`, Type: LiteralNumberInteger, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `'`, Type: LiteralStringSingle, Mutator: Push("#pop", "expr-chain", "string-single-interpol")},
			{Pattern: `"`, Type: LiteralStringDouble, Mutator: Push("#pop", "expr-chain", "string-double")},
			{Pattern: `~/(\\\\|\\/|[^/\n])*/[gimsu]*`, Type: LiteralStringRegex, Mutator: Push("#pop", "expr-chain")},
			{Pattern: `\[`, Type: Punctuation, Mutator: Push("#pop", "expr-chain", "array-decl")},
		},
		"expr-chain": {
			Include("spaces"),
			{Pattern: `(?:\+\+|\-\-)`, Type: Operator, Mutator: nil},
			{Pattern: `(?:%=|&=|\|=|\^=|\+=|\-=|\*=|/=|<<=|>\s*>\s*=|>\s*>\s*>\s*=|==|!=|<=|>\s*=|&&|\|\||<<|>>>|>\s*>|\.\.\.|<|>|%|&|\||\^|\+|\*|/|\-|=>|=)`, Type: Operator, Mutator: Push("#pop", "expr")},
			{Pattern: `(?:in)\b`, Type: Keyword, Mutator: Push("#pop", "expr")},
			{Pattern: `\?`, Type: Operator, Mutator: Push("#pop", "expr", "ternary", "expr")},
			{Pattern: `(\.)((?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+))`, Type: ByGroups(Punctuation, Name), Mutator: nil},
			{Pattern: `\[`, Type: Punctuation, Mutator: Push("array-access")},
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("call")},
			Default(Pop(1)),
		},
		"macro": {
			Include("spaces"),
			Include("meta"),
			{Pattern: `:`, Type: Punctuation, Mutator: Push("#pop", "type")},
			{Pattern: `(?:extern|private)\b`, Type: KeywordDeclaration, Mutator: nil},
			{Pattern: `(?:abstract)\b`, Type: KeywordDeclaration, Mutator: Push("#pop", "optional-semicolon", "abstract")},
			{Pattern: `(?:class|interface)\b`, Type: KeywordDeclaration, Mutator: Push("#pop", "optional-semicolon", "macro-class")},
			{Pattern: `(?:enum)\b`, Type: KeywordDeclaration, Mutator: Push("#pop", "optional-semicolon", "enum")},
			{Pattern: `(?:typedef)\b`, Type: KeywordDeclaration, Mutator: Push("#pop", "optional-semicolon", "typedef")},
			Default(Pop(1), Push("expr")),
		},
		"macro-class": {
			{Pattern: `\{`, Type: Punctuation, Mutator: Push("#pop", "class-body")},
			Include("class"),
		},
		"cast": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "parenthesis-close", "cast-type", "expr")},
			Default(Pop(1), Push("expr")),
		},
		"cast-type": {
			Include("spaces"),
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "type")},
			Default(Pop(1)),
		},
		"catch": {
			Include("spaces"),
			{Pattern: `(?:catch)\b`, Type: Keyword, Mutator: Push("expr", "function-param", "parenthesis-open")},
			Default(Pop(1)),
		},
		"do": {
			Include("spaces"),
			Default(Pop(1), Push("do-while"), Push("expr")),
		},
		"do-while": {
			Include("spaces"),
			{Pattern: `(?:while)\b`, Type: Keyword, Mutator: Push("#pop", "parenthesis", "parenthesis-open")},
		},
		"while": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "expr", "parenthesis")},
		},
		"for": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "expr", "parenthesis")},
		},
		"if": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "else", "optional-semicolon", "expr", "parenthesis")},
		},
		"else": {
			Include("spaces"),
			{Pattern: `(?:else)\b`, Type: Keyword, Mutator: Push("#pop", "expr")},
			Default(Pop(1)),
		},
		"switch": {
			Include("spaces"),
			Default(Pop(1), Push("switch-body"), Push("bracket-open"), Push("expr")),
		},
		"switch-body": {
			Include("spaces"),
			{Pattern: `(?:case|default)\b`, Type: Keyword, Mutator: Push("case-block", "case")},
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
		},
		"case": {
			Include("spaces"),
			{Pattern: `:`, Type: Punctuation, Mutator: Pop(1)},
			Default(Pop(1), Push("case-sep"), Push("case-guard"), Push("expr")),
		},
		"case-sep": {
			Include("spaces"),
			{Pattern: `:`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "case")},
		},
		"case-guard": {
			Include("spaces"),
			{Pattern: `(?:if)\b`, Type: Keyword, Mutator: Push("#pop", "parenthesis", "parenthesis-open")},
			Default(Pop(1)),
		},
		"case-block": {
			Include("spaces"),
			{Pattern: `(?!(?:case|default)\b|\})`, Type: Keyword, Mutator: Push("expr-statement")},
			Default(Pop(1)),
		},
		"new": {
			Include("spaces"),
			Default(Pop(1), Push("call"), Push("parenthesis-open"), Push("type")),
		},
		"array-decl": {
			Include("spaces"),
			{Pattern: `\]`, Type: Punctuation, Mutator: Pop(1)},
			Default(Pop(1), Push("array-decl-sep"), Push("expr")),
		},
		"array-decl-sep": {
			Include("spaces"),
			{Pattern: `\]`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "array-decl")},
		},
		"array-access": {
			Include("spaces"),
			Default(Pop(1), Push("array-access-close"), Push("expr")),
		},
		"array-access-close": {
			Include("spaces"),
			{Pattern: `\]`, Type: Punctuation, Mutator: Pop(1)},
		},
		"comma": {
			Include("spaces"),
			{Pattern: `,`, Type: Punctuation, Mutator: Pop(1)},
		},
		"colon": {
			Include("spaces"),
			{Pattern: `:`, Type: Punctuation, Mutator: Pop(1)},
		},
		"semicolon": {
			Include("spaces"),
			{Pattern: `;`, Type: Punctuation, Mutator: Pop(1)},
		},
		"optional-semicolon": {
			Include("spaces"),
			{Pattern: `;`, Type: Punctuation, Mutator: Pop(1)},
			Default(Pop(1)),
		},
		"ident": {
			Include("spaces"),
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Name, Mutator: Pop(1)},
		},
		"dollar": {
			Include("spaces"),
			{Pattern: `\{`, Type: Punctuation, Mutator: Push("#pop", "expr-chain", "bracket-close", "expr")},
			Default(Pop(1), Push("expr-chain")),
		},
		"type-name": {
			Include("spaces"),
			{Pattern: `_*[A-Z]\w*`, Type: Name, Mutator: Pop(1)},
		},
		"type-full-name": {
			Include("spaces"),
			{Pattern: `\.`, Type: Punctuation, Mutator: Push("ident")},
			Default(Pop(1)),
		},
		"type": {
			Include("spaces"),
			{Pattern: `\?`, Type: Punctuation, Mutator: nil},
			{Pattern: `(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Name, Mutator: Push("#pop", "type-check", "type-full-name")},
			{Pattern: `\{`, Type: Punctuation, Mutator: Push("#pop", "type-check", "type-struct")},
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "type-check", "type-parenthesis")},
		},
		"type-parenthesis": {
			Include("spaces"),
			Default(Pop(1), Push("parenthesis-close"), Push("type")),
		},
		"type-check": {
			Include("spaces"),
			{Pattern: `->`, Type: Punctuation, Mutator: Push("#pop", "type")},
			{Pattern: `<(?!=)`, Type: Punctuation, Mutator: Push("type-param")},
			Default(Pop(1)),
		},
		"type-struct": {
			Include("spaces"),
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `\?`, Type: Punctuation, Mutator: nil},
			{Pattern: `>`, Type: Punctuation, Mutator: Push("comma", "type")},
			{Pattern: `(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Name, Mutator: Push("#pop", "type-struct-sep", "type", "colon")},
			Include("class-body"),
		},
		"type-struct-sep": {
			Include("spaces"),
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "type-struct")},
		},
		"type-param-type": {
			{Pattern: `\.[0-9]+`, Type: LiteralNumberFloat, Mutator: Pop(1)},
			{Pattern: `[0-9]+[eE][+\-]?[0-9]+`, Type: LiteralNumberFloat, Mutator: Pop(1)},
			{Pattern: `[0-9]+\.[0-9]*[eE][+\-]?[0-9]+`, Type: LiteralNumberFloat, Mutator: Pop(1)},
			{Pattern: `[0-9]+\.[0-9]+`, Type: LiteralNumberFloat, Mutator: Pop(1)},
			{Pattern: `[0-9]+\.(?!(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)|\.\.)`, Type: LiteralNumberFloat, Mutator: Pop(1)},
			{Pattern: `0x[0-9a-fA-F]+`, Type: LiteralNumberHex, Mutator: Pop(1)},
			{Pattern: `[0-9]+`, Type: LiteralNumberInteger, Mutator: Pop(1)},
			{Pattern: `'`, Type: LiteralStringSingle, Mutator: Push("#pop", "string-single")},
			{Pattern: `"`, Type: LiteralStringDouble, Mutator: Push("#pop", "string-double")},
			{Pattern: `~/(\\\\|\\/|[^/\n])*/[gim]*`, Type: LiteralStringRegex, Mutator: Pop(1)},
			{Pattern: `\[`, Type: Operator, Mutator: Push("#pop", "array-decl")},
			Include("type"),
		},
		"type-param": {
			Include("spaces"),
			Default(Pop(1), Push("type-param-sep"), Push("type-param-type")),
		},
		"type-param-sep": {
			Include("spaces"),
			{Pattern: `>`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "type-param")},
		},
		"type-param-constraint": {
			Include("spaces"),
			{Pattern: `<(?!=)`, Type: Punctuation, Mutator: Push("#pop", "type-param-constraint-sep", "type-param-constraint-flag", "type-name")},
			Default(Pop(1)),
		},
		"type-param-constraint-sep": {
			Include("spaces"),
			{Pattern: `>`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "type-param-constraint-sep", "type-param-constraint-flag", "type-name")},
		},
		"type-param-constraint-flag": {
			Include("spaces"),
			{Pattern: `:`, Type: Punctuation, Mutator: Push("#pop", "type-param-constraint-flag-type")},
			Default(Pop(1)),
		},
		"type-param-constraint-flag-type": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Push("#pop", "type-param-constraint-flag-type-sep", "type")},
			Default(Pop(1), Push("type")),
		},
		"type-param-constraint-flag-type-sep": {
			Include("spaces"),
			{Pattern: `\)`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("type")},
		},
		"parenthesis": {
			Include("spaces"),
			Default(Pop(1), Push("parenthesis-close"), Push("flag"), Push("expr")),
		},
		"parenthesis-open": {
			Include("spaces"),
			{Pattern: `\(`, Type: Punctuation, Mutator: Pop(1)},
		},
		"parenthesis-close": {
			Include("spaces"),
			{Pattern: `\)`, Type: Punctuation, Mutator: Pop(1)},
		},
		"var": {
			Include("spaces"),
			{Pattern: `(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Text, Mutator: Push("#pop", "var-sep", "assign", "flag", "prop-get-set")},
		},
		"var-sep": {
			Include("spaces"),
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "var")},
			Default(Pop(1)),
		},
		"assign": {
			Include("spaces"),
			{Pattern: `=`, Type: Operator, Mutator: Push("#pop", "expr")},
			Default(Pop(1)),
		},
		"flag": {
			Include("spaces"),
			{Pattern: `:`, Type: Punctuation, Mutator: Push("#pop", "type")},
			Default(Pop(1)),
		},
		"ternary": {
			Include("spaces"),
			{Pattern: `:`, Type: Operator, Mutator: Pop(1)},
		},
		"call": {
			Include("spaces"),
			{Pattern: `\)`, Type: Punctuation, Mutator: Pop(1)},
			Default(Pop(1), Push("call-sep"), Push("expr")),
		},
		"call-sep": {
			Include("spaces"),
			{Pattern: `\)`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "call")},
		},
		"bracket": {
			Include("spaces"),
			{Pattern: `(?!(?:\$\s*[a-z]\b|\$(?!(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+))))(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Name, Mutator: Push("#pop", "bracket-check")},
			{Pattern: `'`, Type: LiteralStringSingle, Mutator: Push("#pop", "bracket-check", "string-single")},
			{Pattern: `"`, Type: LiteralStringDouble, Mutator: Push("#pop", "bracket-check", "string-double")},
			Default(Pop(1), Push("block")),
		},
		"bracket-check": {
			Include("spaces"),
			{Pattern: `:`, Type: Punctuation, Mutator: Push("#pop", "object-sep", "expr")},
			Default(Pop(1), Push("block"), Push("optional-semicolon"), Push("expr-chain")),
		},
		"block": {
			Include("spaces"),
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			Default(Push("expr-statement")),
		},
		"object": {
			Include("spaces"),
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			Default(Pop(1), Push("object-sep"), Push("expr"), Push("colon"), Push("ident-or-string")),
		},
		"ident-or-string": {
			Include("spaces"),
			{Pattern: `(?!(?:function|class|static|var|if|else|while|do|for|break|return|continue|extends|implements|import|switch|case|default|public|private|try|untyped|catch|new|this|throw|extern|enum|in|interface|cast|override|dynamic|typedef|package|inline|using|null|true|false|abstract)\b)(?:_*[a-z]\w*|_+[0-9]\w*|_*[A-Z]\w*|_+|\$\w+)`, Type: Name, Mutator: Pop(1)},
			{Pattern: `'`, Type: LiteralStringSingle, Mutator: Push("#pop", "string-single")},
			{Pattern: `"`, Type: LiteralStringDouble, Mutator: Push("#pop", "string-double")},
		},
		"object-sep": {
			Include("spaces"),
			{Pattern: `\}`, Type: Punctuation, Mutator: Pop(1)},
			{Pattern: `,`, Type: Punctuation, Mutator: Push("#pop", "object")},
		},
	}
}

func haxePreProcMutator(state *LexerState) error {
	stack, ok := state.Get("haxe-pre-proc").([][]string)
	if !ok {
		stack = [][]string{}
	}

	proc := state.Groups[2]
	switch proc {
	case "if":
		stack = append(stack, state.Stack)
	case "else", "elseif":
		if len(stack) > 0 {
			state.Stack = stack[len(stack)-1]
		}
	case "end":
		if len(stack) > 0 {
			stack = stack[:len(stack)-1]
		}
	}

	if proc == "if" || proc == "elseif" {
		state.Stack = append(state.Stack, "preproc-expr")
	}

	if proc == "error" {
		state.Stack = append(state.Stack, "preproc-error")
	}
	state.Set("haxe-pre-proc", stack)
	return nil
}
