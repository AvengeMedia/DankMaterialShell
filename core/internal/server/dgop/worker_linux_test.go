//go:build linux

package dgop

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"golang.org/x/sys/unix"
)

func threadNice(t *testing.T) string {
	raw, err := os.ReadFile(fmt.Sprintf("/proc/self/task/%d/stat", unix.Gettid()))
	require.NoError(t, err)
	stat := string(raw)
	fields := strings.Fields(stat[strings.LastIndexByte(stat, ')')+2:])
	return fields[16]
}

func TestRunLowPriorityRunsJobsOnNicedThread(t *testing.T) {
	var nice string
	runLowPriority(func() { nice = threadNice(t) })
	require.Equal(t, "19", nice)
	require.NotEqual(t, "19", threadNice(t))
}
