package plugins

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
)

func HandleRequest(conn *ipc.ConnWriter, req ipc.Request) {
	switch req.Method {
	case "plugins.list":
		HandleList(conn, req)
	case "plugins.listInstalled":
		HandleListInstalled(conn, req)
	case "plugins.install":
		HandleInstall(conn, req)
	case "plugins.uninstall":
		HandleUninstall(conn, req)
	case "plugins.update":
		HandleUpdate(conn, req)
	case "plugins.search":
		HandleSearch(conn, req)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}
