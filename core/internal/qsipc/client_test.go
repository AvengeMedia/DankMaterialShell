package qsipc

import (
	"bytes"
	"encoding/hex"
	"errors"
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
		t.Fatalf("unexpected wire bytes:\ngot  %x\nwant %x", got.Bytes(), want)
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

func TestReadResponseErrors(t *testing.T) {
	tests := []struct {
		name  string
		index byte
		want  error
	}{
		{name: "not ready", index: responseNotReady, want: ErrNotReady},
		{name: "target not found", index: responseTargetNotFound, want: ErrTargetNotFound},
		{name: "function not found", index: responseFunctionNotFound, want: ErrFunctionNotFound},
		{name: "argument mismatch", index: responseArgumentMismatch, want: ErrArgumentMismatch},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := readResponse(bytes.NewReader([]byte{tt.index}))
			if !errors.Is(err, tt.want) {
				t.Fatalf("readResponse() error = %v, want %v", err, tt.want)
			}
		})
	}
}
