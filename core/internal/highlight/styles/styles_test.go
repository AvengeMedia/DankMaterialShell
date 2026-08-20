package styles

import "testing"

func TestRegistry(t *testing.T) {
	if n := len(Names()); n < 60 {
		t.Fatalf("only %d styles", n)
	}
	if Get("monokai") == Fallback() || Get("nope") != Fallback() {
		t.Fatal("style lookup or fallback wrong")
	}
}
