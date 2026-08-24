package lexers

import (
	"strings"

	. "github.com/alecthomas/chroma/v2" // nolint
)

// HTTP lexer.
var HTTP = Register(httpBodyContentTypeLexer(MustNewLexer(
	&Config{
		Name:         "HTTP",
		Aliases:      []string{"http"},
		Filenames:    []string{},
		MimeTypes:    []string{},
		NotMultiline: true,
		DotAll:       true,
	},
	httpRules,
)))

func httpRules() Rules {
	return Rules{
		"root": {
			{Pattern: `(GET|POST|PUT|DELETE|HEAD|OPTIONS|TRACE|PATCH|CONNECT)( +)([^ ]+)( +)(HTTP)(/)([123](?:\.[01])?)(\r?\n|\Z)`, Type: ByGroups(NameFunction, Text, NameNamespace, Text, KeywordReserved, Operator, LiteralNumber, Text), Mutator: Push("headers")},
			{Pattern: `(HTTP)(/)([123](?:\.[01])?)( +)(\d{3})( *)([^\r\n]*)(\r?\n|\Z)`, Type: ByGroups(KeywordReserved, Operator, LiteralNumber, Text, LiteralNumber, Text, NameException, Text), Mutator: Push("headers")},
		},
		"headers": {
			{Pattern: `([^\s:]+)( *)(:)( *)([^\r\n]+)(\r?\n|\Z)`, Type: EmitterFunc(httpHeaderBlock), Mutator: nil},
			{Pattern: `([\t ]+)([^\r\n]+)(\r?\n|\Z)`, Type: EmitterFunc(httpContinuousHeaderBlock), Mutator: nil},
			{Pattern: `\r?\n`, Type: Text, Mutator: Push("content")},
		},
		"content": {
			{Pattern: `.+`, Type: EmitterFunc(httpContentBlock), Mutator: nil},
		},
	}
}

func httpContentBlock(groups []string, state *LexerState) Iterator {
	tokens := []Token{
		{Type: Generic, Value: groups[0]},
	}
	return Literator(tokens...)
}

func httpHeaderBlock(groups []string, state *LexerState) Iterator {
	tokens := []Token{
		{Type: Name, Value: groups[1]},
		{Type: Text, Value: groups[2]},
		{Type: Operator, Value: groups[3]},
		{Type: Text, Value: groups[4]},
		{Type: Literal, Value: groups[5]},
		{Type: Text, Value: groups[6]},
	}
	return Literator(tokens...)
}

func httpContinuousHeaderBlock(groups []string, state *LexerState) Iterator {
	tokens := []Token{
		{Type: Text, Value: groups[1]},
		{Type: Literal, Value: groups[2]},
		{Type: Text, Value: groups[3]},
	}
	return Literator(tokens...)
}

func httpBodyContentTypeLexer(lexer Lexer) Lexer { return &httpBodyContentTyper{lexer} }

type httpBodyContentTyper struct{ Lexer }

func (d *httpBodyContentTyper) Tokenise(options *TokeniseOptions, text string) (Iterator, error) { // nolint: gocognit
	var contentType string
	var isContentType bool
	var subIterator Iterator

	it, err := d.Lexer.Tokenise(options, text)
	if err != nil {
		return nil, err
	}

	return func() Token {
		token := it()

		if token == EOF {
			if subIterator != nil {
				return subIterator()
			}
			return EOF
		}

		switch {
		case token.Type == Name && strings.ToLower(token.Value) == "content-type":
			{
				isContentType = true
			}
		case token.Type == Literal && isContentType:
			{
				isContentType = false
				contentType = strings.TrimSpace(token.Value)
				pos := strings.Index(contentType, ";")
				if pos > 0 {
					contentType = strings.TrimSpace(contentType[:pos])
				}
			}
		case token.Type == Generic && contentType != "":
			{
				lexer := MatchMimeType(contentType)

				// application/calendar+xml can be treated as application/xml
				// if there's not a better match.
				if lexer == nil && strings.Contains(contentType, "+") {
					slashPos := strings.Index(contentType, "/")
					plusPos := strings.LastIndex(contentType, "+")
					contentType = contentType[:slashPos+1] + contentType[plusPos+1:]
					lexer = MatchMimeType(contentType)
				}

				if lexer == nil {
					token.Type = Text
				} else {
					subIterator, err = lexer.Tokenise(nil, token.Value)
					if err != nil {
						panic(err)
					}
					return subIterator()
				}
			}
		}
		return token
	}, nil
}
