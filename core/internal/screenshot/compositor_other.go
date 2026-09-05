//go:build !linux

package screenshot

func waylandSocketOwner() string { return "" }
