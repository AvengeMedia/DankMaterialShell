package qsipc

import (
	"bytes"
	"encoding/hex"
	"testing"
)

func TestWriteCall(t *testing.T) {
	var got bytes.Buffer
	if err := writeCall(&got, "spotlight", "toggle", []string{"true", "é"}); err != nil {
		t.Fatal(err)
	}
	want, err := hex.DecodeString("030000001200730070006f0074006c00690067006800740000000c0074006f00670067006c0065000000020000000800740072007500650000000200e9")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got.Bytes(), want) {
		for i := range got.Bytes() {
			if got.Bytes()[i] != want[i] {
				t.Fatalf("unexpected byte at %d: got %02x want %02x", i, got.Bytes()[i], want[i])
			}
		}
		t.Fatal("unexpected wire bytes")
	}
}

func TestReadResponse(t *testing.T) {
	data, err := hex.DecodeString("050000000018007b0022006f006b0022003a00200074007200750065007d")
	if err != nil {
		t.Fatal(err)
	}
	value, isVoid, err := readResponse(bytes.NewReader(data))
	if err != nil {
		t.Fatal(err)
	}
	if isVoid || value != `{"ok": true}` {
		t.Fatalf("unexpected response: value=%q void=%v", value, isVoid)
	}
}
