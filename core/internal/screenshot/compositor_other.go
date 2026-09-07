//go:build !linux

package screenshot

import (
	"context"
	"errors"
)

func waylandSocketOwner() string { return "" }

func aqueousSnapshot(context.Context) (aqueousSnapshotModel, error) {
	return aqueousSnapshotModel{}, errors.New("Aqueous IPC is only supported on Linux")
}
