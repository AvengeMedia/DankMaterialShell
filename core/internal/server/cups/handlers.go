package cups

import (
	"encoding/json"
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type Request struct {
	ID     int            `json:"id,omitempty"`
	Method string         `json:"method"`
	Params map[string]any `json:"params,omitempty"`
}

type SuccessResult struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type CUPSEvent struct {
	Type string    `json:"type"`
	Data CUPSState `json:"data"`
}

func HandleRequest(conn net.Conn, req Request, manager *Manager) {
	switch req.Method {
	case "cups.subscribe":
		handleSubscribe(conn, req, manager)
	case "cups.getPrinters":
		handleGetPrinters(conn, req, manager)
	case "cups.getJobs":
		handleGetJobs(conn, req, manager)
	case "cups.pausePrinter":
		handlePausePrinter(conn, req, manager)
	case "cups.resumePrinter":
		handleResumePrinter(conn, req, manager)
	case "cups.cancelJob":
		handleCancelJob(conn, req, manager)
	case "cups.purgeJobs":
		handlePurgeJobs(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetPrinters(conn net.Conn, req Request, manager *Manager) {
	printers, err := manager.GetPrinters()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, printers)
}

func handleGetJobs(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	jobs, err := manager.GetJobs(printerName, "not-completed")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, jobs)
}

func handlePausePrinter(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	if err := manager.PausePrinter(printerName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "paused"})
}

func handleResumePrinter(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	if err := manager.ResumePrinter(printerName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "resumed"})
}

func handleCancelJob(conn net.Conn, req Request, manager *Manager) {
	jobIDFloat, ok := req.Params["jobID"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'jobid' parameter")
		return
	}
	jobID := int(jobIDFloat)

	if err := manager.CancelJob(jobID); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "job canceled"})
}

func handlePurgeJobs(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	if err := manager.PurgeJobs(printerName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "jobs canceled"})
}

func handleSubscribe(conn net.Conn, req Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	event := CUPSEvent{
		Type: "state_changed",
		Data: initialState,
	}

	if err := json.NewEncoder(conn).Encode(models.Response[CUPSEvent]{
		ID:     req.ID,
		Result: &event,
	}); err != nil {
		return
	}

	for state := range stateChan {
		event := CUPSEvent{
			Type: "state_changed",
			Data: state,
		}
		if err := json.NewEncoder(conn).Encode(models.Response[CUPSEvent]{
			Result: &event,
		}); err != nil {
			return
		}
	}
}
