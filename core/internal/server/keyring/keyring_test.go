package keyring

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
)

func withRunner(t *testing.T, r runner) {
	t.Helper()
	prev := run
	run = r
	t.Cleanup(func() { run = prev })
}

func TestUnlock_PassesPasswordToRunner(t *testing.T) {
	var got string
	withRunner(t, func(password string) error {
		got = password
		return nil
	})

	err := Unlock("hunter2")
	assert.NoError(t, err)
	assert.Equal(t, "hunter2", got)
}

func TestUnlock_PropagatesError(t *testing.T) {
	wantErr := errors.New("boom")
	withRunner(t, func(password string) error {
		return wantErr
	})

	err := Unlock("anything")
	assert.ErrorIs(t, err, wantErr)
}

func TestDefaultRun_NoOpWhenBinaryMissing(t *testing.T) {
	prevLookPath := lookPath
	lookPath = func(name string) (string, error) {
		return "", errors.New("not found")
	}
	t.Cleanup(func() { lookPath = prevLookPath })

	assert.NoError(t, defaultRun("anything"))
}
