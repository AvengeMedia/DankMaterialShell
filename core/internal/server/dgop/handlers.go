package dgop

import (
	"context"
	"fmt"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dgop/gops"
)

const metaTimeout = 10 * time.Second

var util = gops.NewGopsUtil()

func HandleRequest(conn *models.Conn, req models.Request) {
	switch req.Method {
	case "dgop.meta":
		handleMeta(conn, req)
	case "dgop.gpu":
		handleGPU(conn, req)
	case "dgop.hardware":
		handleHardware(conn, req)
	case "dgop.modules":
		handleModules(conn, req)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleMeta(conn *models.Conn, req models.Request) {
	modules := params.StringSlice(req.Params, "modules")
	if len(modules) == 0 {
		models.RespondError(conn, req.ID, "modules is required")
		return
	}

	metaParams := gops.MetaParams{
		SortBy:         gops.ProcSortBy(params.StringOpt(req.Params, "sort", string(gops.SortByCPU))),
		ProcLimit:      params.IntOpt(req.Params, "limit", 20),
		EnableCPU:      !params.BoolLoose(req.Params, "noCpu"),
		MergeChildren:  params.BoolOpt(req.Params, "mergeChildren", true),
		GPUPciIds:      params.StringSlice(req.Params, "gpuPciIds"),
		CPUCursor:      params.StringOpt(req.Params, "cpuCursor", ""),
		ProcCursor:     params.StringOpt(req.Params, "procCursor", ""),
		NetRateCursor:  params.StringOpt(req.Params, "netRateCursor", ""),
		DiskRateCursor: params.StringOpt(req.Params, "diskRateCursor", ""),
	}

	ctx, cancel := context.WithTimeout(context.Background(), metaTimeout)
	defer cancel()

	meta, err := util.GetMeta(ctx, modules, metaParams)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, meta)
}

func handleGPU(conn *models.Conn, req models.Request) {
	gpu, err := util.GetGPUInfo()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, gpu)
}

func handleHardware(conn *models.Conn, req models.Request) {
	hw, err := util.GetSystemHardware()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, hw)
}

func handleModules(conn *models.Conn, req models.Request) {
	modules, err := util.GetModules()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, modules)
}
