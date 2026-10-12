package dgop

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dgop/gops"
)

const metaTimeout = 10 * time.Second

var util = gops.NewGopsUtil()

func HandleRequest(conn *ipc.ConnWriter, req ipc.Request) {
	runLowPriority(func() {
		result, err := Call(req.Method, req.Params)
		if err != nil {
			conn.RespondError(req.ID, err.Error())
			return
		}
		conn.Respond(req.ID, result)
	})
}

// Call answers one dgop.* request. The socket handler and the privileged sysmon helper both go through it.
func Call(method string, p map[string]any) (any, error) {
	switch method {
	case "dgop.meta":
		modules := params.StringSlice(p, "modules")
		if len(modules) == 0 {
			return nil, errors.New("modules is required")
		}
		ctx, cancel := context.WithTimeout(context.Background(), metaTimeout)
		defer cancel()
		return util.GetMeta(ctx, modules, metaParamsFrom(p))
	case "dgop.gpu":
		return util.GetGPUInfo()
	case "dgop.hardware":
		return util.GetSystemHardware()
	case "dgop.modules":
		return util.GetModules()
	case "dgop.process":
		pid, err := params.Int(p, "pid")
		if err != nil || pid <= 0 {
			return nil, errors.New("pid is required")
		}
		return util.GetProcessDetail(int32(pid))
	}
	return nil, fmt.Errorf("unknown method: %s", method)
}

func metaParamsFrom(p map[string]any) gops.MetaParams {
	return gops.MetaParams{
		SortBy:               gops.ProcSortBy(params.StringOpt(p, "sort", string(gops.SortByCPU))),
		ProcLimit:            params.IntOpt(p, "limit", 20),
		EnableCPU:            !params.BoolLoose(p, "noCpu"),
		MergeChildren:        params.BoolOpt(p, "mergeChildren", true),
		GPUPciIds:            params.StringSlice(p, "gpuPciIds"),
		CPUCursor:            params.StringOpt(p, "cpuCursor", ""),
		ProcCursor:           params.StringOpt(p, "procCursor", ""),
		NetRateCursor:        params.StringOpt(p, "netRateCursor", ""),
		DiskRateCursor:       params.StringOpt(p, "diskRateCursor", ""),
		GPUStatsCursor:       params.StringOpt(p, "gpuStatsCursor", ""),
		NetRateAllInterfaces: params.BoolLoose(p, "netRateAllInterfaces"),
	}
}
