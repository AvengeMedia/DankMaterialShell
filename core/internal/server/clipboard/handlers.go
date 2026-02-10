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
	case "clipboard.pinEntry":
		handlePinEntry(conn, req, m)
	case "clipboard.unpinEntry":
		handleUnpinEntry(conn, req, m)
	case "clipboard.getPinnedEntries":
		handleGetPinnedEntries(conn, req, m)
	case "clipboard.getPinnedCount":
		handleGetPinnedCount(conn, req, m)
	case "clipboard.copyFile":
		handleCopyFile(conn, req, m)
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

	filePath := m.EntryToFile(entry)
	if filePath != "" {
		if err := m.CopyFile(filePath); err != nil {
			models.RespondError(conn, req.ID, err.Error())
			return
		}
		models.Respond(conn, req.ID, map[string]any{
			"success":  true,
			"filePath": filePath,
		})
		return
	}

	if err := m.SetClipboard(entry.Data, entry.MimeType); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if entry.Pinned {
		if err := m.CreateHistoryEntryFromPinned(entry); err != nil {
			models.RespondError(conn, req.ID, err.Error())
			return
		}
	} else {
		if err := m.TouchEntry(uint64(id)); err != nil {
			models.RespondError(conn, req.ID, err.Error())
			return
		}
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

	if img, ok := models.Get[bool](req, "isImage"); ok {
		p.IsImage = &img
	}
	if b, ok := models.Get[float64](req, "before"); ok {
		v := int64(b)
		p.Before = &v
	}
	if a, ok := models.Get[float64](req, "after"); ok {
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

	if v, ok := models.Get[float64](req, "maxHistory"); ok {
		cfg.MaxHistory = int(v)
	}
	if v, ok := models.Get[float64](req, "maxEntrySize"); ok {
		cfg.MaxEntrySize = int64(v)
	}
	if v, ok := models.Get[float64](req, "autoClearDays"); ok {
		cfg.AutoClearDays = int(v)
	}
	if v, ok := models.Get[bool](req, "clearAtStartup"); ok {
		cfg.ClearAtStartup = v
	}
	if v, ok := models.Get[bool](req, "disabled"); ok {
		cfg.Disabled = v
	}
	if v, ok := models.Get[float64](req, "maxPinned"); ok {
		cfg.MaxPinned = int(v)
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

func handlePinEntry(conn net.Conn, req models.Request, m *Manager) {
	id, err := params.Int(req.Params, "id")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := m.PinEntry(uint64(id)); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "entry pinned"})
}

func handleUnpinEntry(conn net.Conn, req models.Request, m *Manager) {
	id, err := params.Int(req.Params, "id")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := m.UnpinEntry(uint64(id)); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "entry unpinned"})
}

func handleGetPinnedEntries(conn net.Conn, req models.Request, m *Manager) {
	pinned := m.GetPinnedEntries()
	models.Respond(conn, req.ID, pinned)
}

func handleGetPinnedCount(conn net.Conn, req models.Request, m *Manager) {
	count := m.GetPinnedCount()
	models.Respond(conn, req.ID, map[string]int{"count": count})
}

func handleCopyFile(conn net.Conn, req models.Request, m *Manager) {
	filePath, err := params.String(req.Params, "filePath")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := m.CopyFile(filePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "copied"})
}
