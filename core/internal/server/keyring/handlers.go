package keyring

import (
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/params"
)

func HandleRequest(conn net.Conn, req models.Request) {
	switch req.Method {
	case "keyring.unlock":
		handleUnlock(conn, req)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleUnlock(conn net.Conn, req models.Request) {
	password, err := params.String(req.Params, "password")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := Unlock(password); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true})
}
