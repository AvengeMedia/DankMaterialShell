package network

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestBackendType_Constants(t *testing.T) {
	assert.Equal(t, BackendType(0), BackendNone)
	assert.Equal(t, BackendType(1), BackendNetworkManager)
	assert.Equal(t, BackendType(2), BackendIwd)
	assert.Equal(t, BackendType(3), BackendConnMan)
	assert.Equal(t, BackendType(4), BackendNetworkd)
}

func TestDetectResult_HasNetworkdField(t *testing.T) {
	result := &DetectResult{
		Backend:     BackendNetworkd,
		HasNetworkd: true,
		HasIwd:      true,
	}

	assert.True(t, result.HasNetworkd)
	assert.True(t, result.HasIwd)
	assert.Equal(t, BackendNetworkd, result.Backend)
}

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
