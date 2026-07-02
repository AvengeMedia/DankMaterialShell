//go:build !casthelper

// Stub built unless the `casthelper` tag is set, so a plain `go build ./...` /
// `go test ./...` over the core stays green without GStreamer dev packages (and
// without enabling CGO). The real GStreamer helper is built by `make
// cast-helper`, which passes `-tags casthelper` with CGO_ENABLED=1.
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "dms-cast-helper was built without GStreamer support; build it with `make cast-helper` (needs CGO + GStreamer dev packages)")
	os.Exit(2)
}
