package tailscale

import (
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
)

// HandleRequest routes an IPC request to the appropriate handler.
func HandleRequest(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	switch req.Method {
	case "tailscale.getStatus":
		handleGetStatus(conn, req, manager)
	case "tailscale.refresh":
		handleRefresh(conn, req, manager)
	case "tailscale.connect":
		handleConnect(conn, req, manager)
	case "tailscale.disconnect":
		handleDisconnect(conn, req, manager)
	case "tailscale.setExitNode":
		handleSetExitNode(conn, req, manager)
	case "tailscale.setAllowLanAccess":
		handleSetAllowLanAccess(conn, req, manager)
	case "tailscale.setPrefs":
		handleSetPrefs(conn, req, manager)
	case "tailscale.login":
		handleSimple(conn, req, manager.Login)
	case "tailscale.logout":
		handleSimple(conn, req, manager.Logout)
	case "tailscale.addProfile":
		handleSimple(conn, req, manager.AddProfile)
	case "tailscale.profiles":
		handleProfiles(conn, req, manager)
	case "tailscale.switchProfile":
		id := models.GetOr(req, "id", "")
		handleSimple(conn, req, func() error { return manager.SwitchProfile(id) })
	case "tailscale.suggestExitNode":
		handleSuggestExitNode(conn, req, manager)
	case "tailscale.grantOperator":
		handleGrantOperator(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetStatus(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleRefresh(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	manager.RefreshState()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "refreshed"})
}

func handleConnect(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	if err := manager.Connect(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "connected"})
}

func handleDisconnect(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	if err := manager.Disconnect(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "disconnected"})
}

func handleSetExitNode(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	id := models.GetOr(req, "id", "")
	if err := manager.SetExitNode(id); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "exit node updated"})
}

func handleSetAllowLanAccess(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	enabled := models.GetOr(req, "enabled", false)
	if err := manager.SetAllowLANAccess(enabled); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "lan access updated"})
}

// Swappable for tests only; production values are fixed.
var (
	operatorStat        = os.Stat
	operatorLookPath    = lookPathResolved
	operatorCurrentUser = user.Current
	operatorRunner      = commandRunner(execCommandRunner)
)

var operatorGrantMu sync.Mutex

func handleSimple(conn *ipc.ConnWriter, req ipc.Request, fn func() error) {
	if err := fn(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true})
}

type setPrefsResult struct {
	Success bool   `json:"success"`
	Warning string `json:"warning,omitempty"`
}

func handleSetPrefs(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	var p PrefsPatch
	invalid := ""
	reject := func(key string) {
		if _, present := req.Params[key]; present && invalid == "" {
			invalid = key
		}
	}
	setBool := func(key string, dst **bool) {
		if v, ok := models.Get[bool](req, key); ok {
			*dst = &v
		} else {
			reject(key)
		}
	}
	setBool("acceptRoutes", &p.AcceptRoutes)
	setBool("acceptDns", &p.AcceptDNS)
	setBool("shieldsUp", &p.ShieldsUp)
	setBool("runSsh", &p.RunSSH)
	setBool("advertiseExitNode", &p.AdvertiseExitNode)
	if v, ok := models.Get[string](req, "hostname"); ok {
		p.Hostname = &v
	} else {
		reject("hostname")
	}
	v, routesOK := models.Get[[]any](req, "advertiseRoutes")
	if !routesOK {
		reject("advertiseRoutes")
	}
	if invalid != "" {
		models.RespondError(conn, req.ID, fmt.Sprintf("invalid '%s' parameter", invalid))
		return
	}
	if routesOK {
		routes := make([]string, 0, len(v))
		for _, e := range v {
			s, isStr := e.(string)
			if !isStr {
				models.RespondError(conn, req.ID, "advertiseRoutes must be a list of strings")
				return
			}
			routes = append(routes, s)
		}
		p.AdvertiseRoutes = &routes
	}

	warning, err := manager.SetPrefs(p)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, setPrefsResult{Success: true, Warning: warning})
}

// profilesWithGrant returns Profiles with GrantAvailable filled in.
func profilesWithGrant(manager *Manager) (ProfilesResult, error) {
	res, err := manager.Profiles()
	if err != nil {
		return res, err
	}
	if !res.CanOperate {
		_, argvErr := operatorGrantArgv(operatorStat, operatorLookPath, operatorCurrentUser)
		res.GrantAvailable = argvErr == nil
	}
	return res, nil
}

func handleProfiles(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	res, err := profilesWithGrant(manager)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, res)
}

func handleSuggestExitNode(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	sug, err := manager.SuggestExitNode()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, sug)
}

// handleGrantOperator takes no request params: the elevated argv is built
// from fixed values only.
func handleGrantOperator(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	if !operatorGrantMu.TryLock() {
		models.RespondError(conn, req.ID, "a permission request is already open")
		return
	}
	defer operatorGrantMu.Unlock()

	argv, err := operatorGrantArgv(operatorStat, operatorLookPath, operatorCurrentUser)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	if err := grantOperator(manager.ctx, argv, operatorRunner); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	manager.RefreshState()
	handleProfiles(conn, req, manager)
}

// lookPathResolved follows symlinks so the path that is checked is the path that is executed.
// A target with a different basename (multicall binaries) is refused.
func lookPathResolved(name string) (string, error) {
	p, err := exec.LookPath(name)
	if err != nil {
		return "", err
	}
	r, err := filepath.EvalSymlinks(p)
	if err != nil {
		return "", err
	}
	if filepath.Base(r) != name {
		return "", fmt.Errorf("%s resolves to %s (%s), refusing to run it under a different name", name, r, filepath.Base(r))
	}
	return r, nil
}
