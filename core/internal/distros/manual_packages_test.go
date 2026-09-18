package distros

import (
	"testing"
)

func TestManualPackageInstaller_parseLatestTagFromGitOutput(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name: "normal tag output",
			input: `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v0.2.1
a5431dd02dc23d9ef1680e67777fed00fe5f7cda	refs/tags/v0.2.0
703a3789083d2f990c4e99cd25c97c2a4cccbd81	refs/tags/v0.1.0`,
			expected: "v0.2.1",
		},
		{
			name: "annotated tags with ^{}",
			input: `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v0.2.1
b1b150fab00a93ea983aaca5df55304bc837f51c	refs/tags/v0.2.1^{}
a5431dd02dc23d9ef1680e67777fed00fe5f7cda	refs/tags/v0.2.0`,
			expected: "v0.2.1",
		},
		{
			name: "mixed tags",
			input: `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v0.3.0
b1b150fab00a93ea983aaca5df55304bc837f51c	refs/tags/v0.3.0^{}
a5431dd02dc23d9ef1680e67777fed00fe5f7cda	refs/tags/v0.2.0
c1c150fab00a93ea983aaca5df55304bc837f51d	refs/tags/beta-1`,
			expected: "v0.3.0",
		},
		{
			name:     "empty output",
			input:    "",
			expected: "",
		},
		{
			name:     "no tags",
			input:    "some other output\nwithout tags",
			expected: "",
		},
		{
			name: "only annotated tags",
			input: `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v0.2.1^{}
a5431dd02dc23d9ef1680e67777fed00fe5f7cda	refs/tags/v0.2.0^{}`,
			expected: "",
		},
		{
			name:     "single tag",
			input:    `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v1.0.0`,
			expected: "v1.0.0",
		},
		{
			name: "tag with extra whitespace",
			input: `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v0.2.1
a5431dd02dc23d9ef1680e67777fed00fe5f7cda	refs/tags/v0.2.0`,
			expected: "v0.2.1",
		},
		{
			name: "beta and rc tags",
			input: `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v0.3.0-beta.1
a5431dd02dc23d9ef1680e67777fed00fe5f7cda	refs/tags/v0.2.0`,
			expected: "v0.3.0-beta.1",
		},
		{
			name: "tags without v prefix",
			input: `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/0.2.1
a5431dd02dc23d9ef1680e67777fed00fe5f7cda	refs/tags/0.2.0`,
			expected: "0.2.1",
		},
		{
			name: "multiple lines with spaces",
			input: `
a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v1.2.3
a5431dd02dc23d9ef1680e67777fed00fe5f7cda	refs/tags/v1.2.2
`,
			expected: "v1.2.3",
		},
		{
			name:     "tag at end of line",
			input:    `a1a150fab00a93ea983aaca5df55304bc837f51b	refs/tags/v0.2.1`,
			expected: "v0.2.1",
		},
	}

	logChan := make(chan string, 100)
	defer close(logChan)

	base := NewBaseDistribution(logChan)
	installer := &ManualPackageInstaller{BaseDistribution: base}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := installer.parseLatestTagFromGitOutput(tt.input)

			if result != tt.expected {
				t.Errorf("parseLatestTagFromGitOutput() = %q, expected %q", result, tt.expected)
			}
		})
	}
}
