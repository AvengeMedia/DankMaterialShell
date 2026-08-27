package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMatugenQtengineCommandAcceptsConfigDir(t *testing.T) {
	flag := matugenQtengineCmd.Flags().Lookup("config-dir")
	require.NotNil(t, flag)
	assert.Equal(t, "", flag.DefValue)
}
