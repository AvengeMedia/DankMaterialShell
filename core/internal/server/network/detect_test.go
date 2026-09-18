package network

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestDetectNetworkStack_Integration(t *testing.T) {
	result, err := DetectNetworkStack()

	if err != nil && strings.Contains(err.Error(), "connect system bus") {
		t.Skipf("system D-Bus unavailable: %v", err)
	}

	assert.NoError(t, err)
	if assert.NotNil(t, result) {
		assert.NotEmpty(t, result.ChosenReason)
	}
}
