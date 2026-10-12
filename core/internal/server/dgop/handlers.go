package dgop

import (
	"context"
	"fmt"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dgop/gops"
)

const metaTimeout = 10 * time.Second

var util = gops.NewGopsUtil()

func HandleRequest(conn *ipc.ConnWriter, req ipc.Request) {
	runLowPriority(func() { dispatch(conn, req) })
}

func dispatch(conn *ipc.ConnWriter, req ipc.Request) {
	switch req.Method {
	case "dgop.meta":
		handleMeta(conn, req)
	case "dgop.gpu":
		handleGPU(conn, req)
	case "dgop.hardware":
		handleHardware(conn, req)
	case "dgop.modules":
		handleModules(conn, req)
	case "dgop.process":
		handleProcess(conn, req)
	default:
		conn.RespondError(req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleMeta(conn *ipc.ConnWriter, req ipc.Request) {
	modules := params.StringSlice(req.Params, "modules")
	if len(modules) == 0 {
		conn.RespondError(req.ID, "modules is required")
		return
	}

	metaParams := metaParamsFrom(req.Params)

	ctx, cancel := context.WithTimeout(context.Background(), metaTimeout)
	defer cancel()

	meta, err := util.GetMeta(ctx, modules, metaParams)
	if err != nil {
		conn.RespondError(req.ID, err.Error())
		return
	}

	conn.Respond(req.ID, meta)
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

func handleGPU(conn *ipc.ConnWriter, req ipc.Request) {
	gpu, err := util.GetGPUInfo()
	if err != nil {
		conn.RespondError(req.ID, err.Error())
		return
	}

	conn.Respond(req.ID, gpu)
}

func handleHardware(conn *ipc.ConnWriter, req ipc.Request) {
	hw, err := util.GetSystemHardware()
	if err != nil {
		conn.RespondError(req.ID, err.Error())
		return
	}

	conn.Respond(req.ID, hw)
}

func handleModules(conn *ipc.ConnWriter, req ipc.Request) {
	modules, err := util.GetModules()
	if err != nil {
		conn.RespondError(req.ID, err.Error())
		return
	}

	conn.Respond(req.ID, modules)
}

func handleProcess(conn *ipc.ConnWriter, req ipc.Request) {
	pid, err := params.Int(req.Params, "pid")
	if err != nil || pid <= 0 {
		conn.RespondError(req.ID, "pid is required")
		return
	}
	detail, err := util.GetProcessDetail(int32(pid))
	if err != nil {
		conn.RespondError(req.ID, err.Error())
		return
	}
	conn.Respond(req.ID, detail)
}
