package distros

import (
	"bytes"
	"os"
	"strings"
	"testing"
)

// Golden is `gpg --batch --dearmor` output for the fixture.
func TestDearmorPGPMatchesGPGGolden(t *testing.T) {
	armored, err := os.ReadFile("testdata/obs-release.asc")
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	want, err := os.ReadFile("testdata/obs-release.gpg")
	if err != nil {
		t.Fatalf("read golden: %v", err)
	}

	got, err := dearmorPGP(armored)
	if err != nil {
		t.Fatalf("dearmorPGP: %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("got %d bytes, want %d", len(got), len(want))
	}
}

func TestDearmorPGPAcceptsCRLF(t *testing.T) {
	armored, err := os.ReadFile("testdata/obs-release.asc")
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	want, err := dearmorPGP(armored)
	if err != nil {
		t.Fatalf("dearmorPGP: %v", err)
	}

	crlf := []byte(strings.ReplaceAll(string(armored), "\n", "\r\n"))
	got, err := dearmorPGP(crlf)
	if err != nil {
		t.Fatalf("dearmorPGP on CRLF input: %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Fatal("CRLF input decoded differently")
	}
}

func TestDearmorPGPRejects(t *testing.T) {
	tests := map[string]string{
		"no header":         "mQINBAAA\n",
		"unterminated":      "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nmQINBAAA\n",
		"bad base64":        "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n!!!!\n-----END PGP PUBLIC KEY BLOCK-----\n",
		"empty payload":     "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n-----END PGP PUBLIC KEY BLOCK-----\n",
		"checksum mismatch": "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nmQINBAAA\n=AAAA\n-----END PGP PUBLIC KEY BLOCK-----\n",
	}

	for name, input := range tests {
		t.Run(name, func(t *testing.T) {
			if _, err := dearmorPGP([]byte(input)); err == nil {
				t.Fatal("expected an error")
			}
		})
	}
}
