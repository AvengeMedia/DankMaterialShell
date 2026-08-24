// Package highlight replaces chroma's lexers and styles packages, whose
// package init parses every embedded XML definition (~10ms on every dms
// invocation). The copies under lexers/ and styles/ are chroma's own files,
// refreshed by go generate; only lexers/lexers.go and styles/styles.go are
// ours and build the registries on first use.
package highlight

//go:generate sh generate.sh
