package styles

import (
	"embed"
	"io/fs"
	"sort"
	"strings"
	"sync"

	"github.com/alecthomas/chroma/v2"
)

//go:embed *.xml
var embedded embed.FS

// Registry of Styles, built on first use.
var Registry = sync.OnceValue(func() map[string]*chroma.Style {
	registry := map[string]*chroma.Style{}
	files, err := fs.ReadDir(embedded, ".")
	if err != nil {
		panic(err)
	}
	for _, file := range files {
		r, err := embedded.Open(file.Name())
		if err != nil {
			panic(err)
		}
		style, err := chroma.NewXMLStyle(r)
		if err != nil {
			panic(err)
		}
		registry[strings.ToLower(style.Name)] = style
		_ = r.Close()
	}
	return registry
})

// Fallback style.
func Fallback() *chroma.Style {
	return Registry()["swapoff"]
}

// Names of all available styles.
func Names() []string {
	out := []string{}
	for name := range Registry() {
		out = append(out, name)
	}
	sort.Strings(out)
	return out
}

// Get named style, or Fallback.
func Get(name string) *chroma.Style {
	if style, ok := Registry()[strings.ToLower(name)]; ok {
		return style
	}
	return Fallback()
}
