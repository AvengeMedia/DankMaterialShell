package clipboard

import (
	"encoding/json"
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/params"
)

func HandleRequest(conn net.Conn, req models.Request, m *Manager) {
	switch req.Method {
	case "clipboard.getState":
		handleGetState(conn, req, m)
	case "clipboard.getHistory":
		handleGetHistory(conn, req, m)
	case "clipboard.getEntry":
		handleGetEntry(conn, req, m)
	case "clipboard.deleteEntry":
		handleDeleteEntry(conn, req, m)
	case "clipboard.clearHistory":
		handleClearHistory(conn, req, m)
	case "clipboard.copy":
		handleCopy(conn, req, m)
	case "clipboard.copyEntry":
		handleCopyEntry(conn, req, m)
	case "clipboard.paste":
		handlePaste(conn, req, m)
	case "clipboard.subscribe":
		handleSubscribe(conn, req, m)
	case "clipboard.search":
		handleSearch(conn, req, m)
	case "clipboard.getConfig":
		handleGetConfig(conn, req, m)
	case "clipboard.setConfig":
		handleSetConfig(conn, req, m)
	case "clipboard.store":
		handleStore(conn, req, m)
	default:
		models.RespondError(conn, req.ID, "unknown method: "+req.Method)
	}
}

func handleGetState(conn net.Conn, req models.Request, m *Manager) {
	models.Respond(conn, req.ID, m.GetState())
}

func handleGetHistory(conn net.Conn, req models.Request, m *Manager) {
	history := m.GetHistory()
	for i := range history {
		history[i].Data = nil
	}
	models.Respond(conn, req.ID, history)
}

func handleGetEntry(conn net.Conn, req models.Request, m *Manager) {
	id, err := params.Int(req.Params, "id")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	entry, err := m.GetEntry(uint64(id))
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, entry)
}

func handleDeleteEntry(conn net.Conn, req models.Request, m *Manager) {
	id, err := params.Int(req.Params, "id")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := m.DeleteEntry(uint64(id)); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "entry deleted"})
}

func handleClearHistory(conn net.Conn, req models.Request, m *Manager) {
	m.ClearHistory()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "history cleared"})
}

func handleCopy(conn net.Conn, req models.Request, m *Manager) {
	text, err := params.String(req.Params, "text")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := m.CopyText(text); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "copied to clipboard"})
}

func handleCopyEntry(conn net.Conn, req models.Request, m *Manager) {
	id, err := params.Int(req.Params, "id")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	entry, err := m.GetEntry(uint64(id))
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := m.SetClipboard(entry.Data, entry.MimeType); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "copied to clipboard"})
}

func handlePaste(conn net.Conn, req models.Request, m *Manager) {
	text, err := m.PasteText()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, map[string]string{"text": text})
}

func handleSubscribe(conn net.Conn, req models.Request, m *Manager) {
	clientID := fmt.Sprintf("clipboard-%d", req.ID)

	ch := m.Subscribe(clientID)
	defer m.Unsubscribe(clientID)

	initialState := m.GetState()
	if err := json.NewEncoder(conn).Encode(models.Response[State]{
		ID:     req.ID,
		Result: &initialState,
	}); err != nil {
		return
	}

	for state := range ch {
		if err := json.NewEncoder(conn).Encode(models.Response[State]{
			ID:     req.ID,
			Result: &state,
		}); err != nil {
			return
		}
	}
}

func handleSearch(conn net.Conn, req models.Request, m *Manager) {
	p := SearchParams{
		Query:    params.StringOpt(req.Params, "query", ""),
		MimeType: params.StringOpt(req.Params, "mimeType", ""),
		Limit:    params.IntOpt(req.Params, "limit", 50),
		Offset:   params.IntOpt(req.Params, "offset", 0),
	}

	if img, ok := req.Params["isImage"].(bool); ok {
		p.IsImage = &img
	}
	if b, ok := req.Params["before"].(float64); ok {
		v := int64(b)
		p.Before = &v
	}
	if a, ok := req.Params["after"].(float64); ok {
		v := int64(a)
		p.After = &v
	}

	models.Respond(conn, req.ID, m.Search(p))
}

func handleGetConfig(conn net.Conn, req models.Request, m *Manager) {
	models.Respond(conn, req.ID, m.GetConfig())
}

func handleSetConfig(conn net.Conn, req models.Request, m *Manager) {
	cfg := m.GetConfig()

	if _, ok := req.Params["maxHistory"]; ok {
		cfg.MaxHistory = params.IntOpt(req.Params, "maxHistory", cfg.MaxHistory)
	}
	if _, ok := req.Params["maxEntrySize"]; ok {
		cfg.MaxEntrySize = int64(params.IntOpt(req.Params, "maxEntrySize", int(cfg.MaxEntrySize)))
	}
	if _, ok := req.Params["autoClearDays"]; ok {
		cfg.AutoClearDays = params.IntOpt(req.Params, "autoClearDays", cfg.AutoClearDays)
	}
	if v, ok := req.Params["clearAtStartup"].(bool); ok {
		cfg.ClearAtStartup = v
	}
	if v, ok := req.Params["disabled"].(bool); ok {
		cfg.Disabled = v
	}

	if err := m.SetConfig(cfg); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "config updated"})
}

func handleStore(conn net.Conn, req models.Request, m *Manager) {
	data, err := params.String(req.Params, "data")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	mimeType := params.StringOpt(req.Params, "mimeType", "text/plain;charset=utf-8")

	if err := m.StoreData([]byte(data), mimeType); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "stored"})
}
