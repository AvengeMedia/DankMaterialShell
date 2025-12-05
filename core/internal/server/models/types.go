package models

import (
	"encoding/json"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

type Request struct {
	ID     int            `json:"id,omitempty"`
	Method string         `json:"method"`
	Params map[string]any `json:"params,omitempty"`
}

type Response[T any] struct {
	ID     int    `json:"id,omitempty"`
	Result *T     `json:"result,omitempty"`
	Error  string `json:"error,omitempty"`
}

func RespondError(conn net.Conn, id int, errMsg string) {
	log.Errorf("DMS API Error: id=%d error=%s", id, errMsg)
	resp := Response[any]{ID: id, Error: errMsg}
	json.NewEncoder(conn).Encode(resp)
}

func Respond[T any](conn net.Conn, id int, result T) {
	resp := Response[T]{ID: id, Result: &result}
	json.NewEncoder(conn).Encode(resp)
}
