package lexers

import (
	"embed"
	"io/fs"
	"regexp"
	"sync"

	"github.com/alecthomas/chroma/v2"
)

//go:embed embedded
var embedded embed.FS

// Go-coded lexers Register at package init; they are folded into the registry
// once it is built so that importing this package stays free.
var pending []chroma.Lexer

var built bool

var registry = sync.OnceValue(func() *chroma.LexerRegistry {
	built = true
	reg := chroma.NewLexerRegistry()
	paths, err := fs.Glob(embedded, "embedded/*.xml")
	if err != nil {
		panic(err)
	}
	for _, path := range paths {
		reg.Register(chroma.MustNewXMLLexer(embedded, path))
	}
	for _, lexer := range pending {
		reg.Register(lexer)
	}
	for name, analyse := range analysers {
		reg.Get(name).SetAnalyser(analyse)
	}
	return reg
})

// Upstream dns.go, mysql.go and zed.go attach these in init() through Get(),
// which would force the registry at import time; kept here instead.
var (
	zoneAnalyserRe                     = regexp.MustCompile(`(?m)^@\s+IN\s+SOA\s+`)
	mysqlAnalyserNameBetweenBacktickRe = regexp.MustCompile("`[a-zA-Z_]\\w*`")
	mysqlAnalyserNameBetweenBracketRe  = regexp.MustCompile(`\[[a-zA-Z_]\w*\]`)
)

var analysers = map[string]func(text string) float32{
	"dns": func(text string) float32 {
		if zoneAnalyserRe.FindString(text) != "" {
			return 1.0
		}
		return 0.0
	},
	"mysql": func(text string) float32 {
		nameBetweenBacktickCount := len(mysqlAnalyserNameBetweenBacktickRe.FindAllString(text, -1))
		nameBetweenBracketCount := len(mysqlAnalyserNameBetweenBracketRe.FindAllString(text, -1))
		dialectNameCount := nameBetweenBacktickCount + nameBetweenBracketCount
		switch {
		case dialectNameCount >= 1 && nameBetweenBacktickCount >= 2*nameBetweenBracketCount:
			return 0.5
		case nameBetweenBacktickCount > nameBetweenBracketCount:
			return 0.2
		case nameBetweenBacktickCount > 0:
			return 0.1
		}
		return 0
	},
	"Zed": func(text string) float32 {
		has := func(s string) bool { return regexp.MustCompile(regexp.QuoteMeta(s)).MatchString(text) }
		switch {
		case has("definition ") && has("relation ") && has("permission "):
			return 0.9
		case has("definition "), has("relation "):
			return 0.5
		case has("permission "):
			return 0.25
		}
		return 0.0
	},
}

// Names of all lexers, optionally including aliases.
func Names(withAliases bool) []string {
	return registry().Names(withAliases)
}

// Get a Lexer by name, alias or file extension.
func Get(name string) chroma.Lexer {
	return registry().Get(name)
}

// MatchMimeType attempts to find a lexer for the given MIME type.
func MatchMimeType(mimeType string) chroma.Lexer {
	return registry().MatchMimeType(mimeType)
}

// Match returns the first lexer matching filename.
func Match(filename string) chroma.Lexer {
	return registry().Match(filename)
}

// Analyse text content and return the "best" lexer.
func Analyse(text string) chroma.Lexer {
	return registry().Analyse(text)
}

// Register a Lexer; before the registry exists it is queued.
func Register(lexer chroma.Lexer) chroma.Lexer {
	pending = append(pending, lexer)
	return lexer
}

// PlaintextRules is used for the fallback lexer as well as the explicit
// plaintext lexer.
func PlaintextRules() chroma.Rules {
	return chroma.Rules{
		"root": []chroma.Rule{
			{Pattern: `.+`, Type: chroma.Text, Mutator: nil},
			{Pattern: `\n`, Type: chroma.Text, Mutator: nil},
		},
	}
}

// Fallback lexer if no other is found.
var Fallback chroma.Lexer = chroma.MustNewLexer(&chroma.Config{
	Name:      "fallback",
	Filenames: []string{"*"},
	Priority:  -1,
}, PlaintextRules)
