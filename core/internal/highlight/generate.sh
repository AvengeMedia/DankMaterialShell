#!/bin/sh
# Refreshes the chroma lexer and style copies from the module version in go.mod.
set -e
d=$(go list -m -f '{{.Dir}}' github.com/alecthomas/chroma/v2)
rm -f lexers/embedded/*.xml styles/*.xml
find lexers -maxdepth 1 -name '*.go' ! -name lexers.go -delete
install -m 0644 "$d"/lexers/embedded/*.xml lexers/embedded/
install -m 0644 "$d"/styles/*.xml styles/
install -m 0644 "$d"/COPYING COPYING
for f in "$d"/lexers/*.go; do
	case $(basename "$f") in
	lexers.go | dns.go | mysql.go | zed.go | *_test.go) continue ;;
	esac
	install -m 0644 "$f" lexers/
done
