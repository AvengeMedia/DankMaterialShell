package dgop

import (
	"reflect"
	"testing"

	"github.com/duxlabs-dev/dux-gop/gops"
)

func TestMetaParamsFromAllKeys(t *testing.T) {
	got := metaParamsFrom(map[string]any{
		"sort":                 "memory",
		"limit":                float64(5),
		"noCpu":                true,
		"mergeChildren":        false,
		"gpuPciIds":            []any{"0000:01:00.0"},
		"cpuCursor":            "c",
		"procCursor":           "p",
		"netRateCursor":        "n",
		"diskRateCursor":       "d",
		"gpuCursor":            "g",
		"netRateAllInterfaces": true,
	})
	want := gops.MetaParams{
		SortBy: gops.ProcSortBy("memory"), ProcLimit: 5, EnableCPU: false, MergeChildren: false,
		GPUPciIds: []string{"0000:01:00.0"}, CPUCursor: "c", ProcCursor: "p", NetRateCursor: "n",
		DiskRateCursor: "d", GPUCursor: "g", NetRateAllInterfaces: true,
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %+v, want %+v", got, want)
	}
}

func TestMetaParamsFromDefaults(t *testing.T) {
	got := metaParamsFrom(nil)
	if got.ProcLimit != 20 || !got.MergeChildren || !got.EnableCPU || got.SortBy != gops.SortByCPU ||
		got.GPUCursor != "" || got.NetRateAllInterfaces {
		t.Fatalf("unexpected defaults: %+v", got)
	}
}

func TestMetaParamsFromGPUPciIdsEmptyIsNotNil(t *testing.T) {
	if got := metaParamsFrom(map[string]any{"gpuPciIds": []any{}}).GPUPciIds; got == nil || len(got) != 0 {
		t.Fatalf("empty list must stay non-nil (monitor none), got %#v", got)
	}
	if got := metaParamsFrom(map[string]any{}).GPUPciIds; got != nil {
		t.Fatalf("absent key must stay nil (monitor all), got %#v", got)
	}
}
