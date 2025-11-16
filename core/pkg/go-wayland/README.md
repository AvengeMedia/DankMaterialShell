# Wayland implementation in Go

[![Go Reference](https://pkg.go.dev/badge/github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland.svg)](https://pkg.go.dev/github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland)

This module contains pure Go implementation of the Wayland protocol.
Currently only wayland-client functionality is supported.

Go code is generated from protocol XML files using
[`go-wayland-scanner`](cmd/go-wayland-scanner/scanner.go).

To load cursor, minimal port of `wayland-cursor` & `xcursor` in pure Go
is located at [`wayland/cursor`](wayland/cursor) & [`wayland/cursor/xcursor`](wayland/cursor/xcursor)
respectively.

To demonstrate the functionality of this module
[`examples/imageviewer`](examples/imageviewer) contains a simple image
viewer. It demos displaying a top-level window, resizing of window,
cursor themes, pointer and keyboard. Because it's in pure Go, it can be
compiled without CGO. You can try it using the following commands:

```sh
CGO_ENABLED=0 go install github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/examples/imageviewer@latest

imageviewer file.jpg
```
