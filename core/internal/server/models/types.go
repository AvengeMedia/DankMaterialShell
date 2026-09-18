package models

import (
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
)

func Get[T any](r ipc.Request, key string) (T, bool) {
	v, err := params.Get[T](r.Params, key)
	return v, err == nil
}

func GetOr[T any](r ipc.Request, key string, def T) T {
	return params.GetOpt(r.Params, key, def)
}

func RespondError(conn *ipc.ConnWriter, id int, errMsg string) {
	log.Errorf("DMS API Error: id=%d error=%s", id, errMsg)
	_ = conn.WriteResponse(ipc.Response[any]{ID: id, Error: errMsg})
}

func Respond[T any](conn *ipc.ConnWriter, id int, result T) {
	_ = conn.WriteResponse(ipc.Response[T]{ID: id, Result: &result})
}

type SuccessResult struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
	Value   string `json:"value,omitempty"`
}
