package lexers

import "testing"

func TestLazyRegistry(t *testing.T) {
	if built {
		t.Fatal("registry built at import time")
	}
	if n := len(Names(false)); n < 290 {
		t.Fatalf("only %d lexers", n)
	}
	for _, name := range []string{"go", "markdown", "http", "php", "mysql", "dns", "zed", "yaml+jinja"} {
		if Get(name) == nil {
			t.Errorf("lexer %q missing", name)
		}
	}
	if Match("main.rs") == nil || Analyse("@ IN SOA ns1.example.com.") == nil {
		t.Error("match or analyse failed")
	}
}
