package dbus

import (
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/params"
)

type objectParams struct {
	bus   string
	dest  string
	path  string
	iface string
}

func extractObjectParams(p map[string]any, requirePath bool) (objectParams, error) {
	bus, err := params.String(p, "bus")
	if err != nil {
		return objectParams{}, err
	}
	dest, err := params.String(p, "dest")
	if err != nil {
		return objectParams{}, err
	}

	var path string
	if requirePath {
		path, err = params.String(p, "path")
		if err != nil {
			return objectParams{}, err
		}
	} else {
		path = params.StringOpt(p, "path", "/")
	}

	iface, err := params.String(p, "interface")
	if err != nil {
		return objectParams{}, err
	}

	return objectParams{bus: bus, dest: dest, path: path, iface: iface}, nil
}

func HandleRequest(conn net.Conn, req models.Request, m *Manager, clientID string) {
	switch req.Method {
	case "dbus.call":
		handleCall(conn, req, m)
	case "dbus.getProperty":
		handleGetProperty(conn, req, m)
	case "dbus.setProperty":
		handleSetProperty(conn, req, m)
	case "dbus.getAllProperties":
		handleGetAllProperties(conn, req, m)
	case "dbus.introspect":
		handleIntrospect(conn, req, m)
	case "dbus.listNames":
		handleListNames(conn, req, m)
	case "dbus.subscribe":
		handleSubscribe(conn, req, m, clientID)
	case "dbus.unsubscribe":
		handleUnsubscribe(conn, req, m)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleCall(conn net.Conn, req models.Request, m *Manager) {
	op, err := extractObjectParams(req.Params, true)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	method, err := params.String(req.Params, "method")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	var args []any
	if argsRaw, ok := params.Any(req.Params, "args"); ok {
		if argsSlice, ok := argsRaw.([]any); ok {
			args = argsSlice
		}
	}

	result, err := m.Call(op.bus, op.dest, op.path, op.iface, method, args)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, result)
}

func handleGetProperty(conn net.Conn, req models.Request, m *Manager) {
	op, err := extractObjectParams(req.Params, true)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	property, err := params.String(req.Params, "property")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	result, err := m.GetProperty(op.bus, op.dest, op.path, op.iface, property)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, result)
}

func handleSetProperty(conn net.Conn, req models.Request, m *Manager) {
	op, err := extractObjectParams(req.Params, true)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	property, err := params.String(req.Params, "property")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	value, ok := params.Any(req.Params, "value")
	if !ok {
		models.RespondError(conn, req.ID, "missing 'value' parameter")
		return
	}

	if err := m.SetProperty(op.bus, op.dest, op.path, op.iface, property, value); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true})
}

func handleGetAllProperties(conn net.Conn, req models.Request, m *Manager) {
	op, err := extractObjectParams(req.Params, true)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	result, err := m.GetAllProperties(op.bus, op.dest, op.path, op.iface)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, result)
}

func handleIntrospect(conn net.Conn, req models.Request, m *Manager) {
	bus, err := params.String(req.Params, "bus")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	dest, err := params.String(req.Params, "dest")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	path := params.StringOpt(req.Params, "path", "/")

	result, err := m.Introspect(bus, dest, path)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, result)
}

func handleListNames(conn net.Conn, req models.Request, m *Manager) {
	bus, err := params.String(req.Params, "bus")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	result, err := m.ListNames(bus)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, result)
}

func handleSubscribe(conn net.Conn, req models.Request, m *Manager, clientID string) {
	if id := params.StringOpt(req.Params, "clientId", ""); id != "" {
		clientID = id
	}

	bus, err := params.String(req.Params, "bus")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	sender := params.StringOpt(req.Params, "sender", "")
	path := params.StringOpt(req.Params, "path", "")
	iface := params.StringOpt(req.Params, "interface", "")
	member := params.StringOpt(req.Params, "member", "")

	result, err := m.Subscribe(clientID, bus, sender, path, iface, member)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, result)
}

func handleUnsubscribe(conn net.Conn, req models.Request, m *Manager) {
	subID, err := params.String(req.Params, "subscriptionId")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := m.Unsubscribe(subID); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true})
}
