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
	case "cups.getDevices":
		handleGetDevices(conn, req, manager)
	case "cups.getPPDs":
		handleGetPPDs(conn, req, manager)
	case "cups.getClasses":
		handleGetClasses(conn, req, manager)
	case "cups.createPrinter":
		handleCreatePrinter(conn, req, manager)
	case "cups.deletePrinter":
		handleDeletePrinter(conn, req, manager)
	case "cups.acceptJobs":
		handleAcceptJobs(conn, req, manager)
	case "cups.rejectJobs":
		handleRejectJobs(conn, req, manager)
	case "cups.setPrinterShared":
		handleSetPrinterShared(conn, req, manager)
	case "cups.setPrinterLocation":
		handleSetPrinterLocation(conn, req, manager)
	case "cups.setPrinterInfo":
		handleSetPrinterInfo(conn, req, manager)
	case "cups.moveJob":
		handleMoveJob(conn, req, manager)
	case "cups.printTestPage":
		handlePrintTestPage(conn, req, manager)
	case "cups.addPrinterToClass":
		handleAddPrinterToClass(conn, req, manager)
	case "cups.removePrinterFromClass":
		handleRemovePrinterFromClass(conn, req, manager)
	case "cups.deleteClass":
		handleDeleteClass(conn, req, manager)
	case "cups.restartJob":
		handleRestartJob(conn, req, manager)
	case "cups.holdJob":
		handleHoldJob(conn, req, manager)
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

func handleGetDevices(conn net.Conn, req Request, manager *Manager) {
	devices, err := manager.GetDevices()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, devices)
}

func handleGetPPDs(conn net.Conn, req Request, manager *Manager) {
	ppds, err := manager.GetPPDs()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, ppds)
}

func handleGetClasses(conn net.Conn, req Request, manager *Manager) {
	classes, err := manager.GetClasses()
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, classes)
}

func handleCreatePrinter(conn net.Conn, req Request, manager *Manager) {
	name, ok := req.Params["name"].(string)
	if !ok || name == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
		return
	}

	deviceURI, ok := req.Params["deviceURI"].(string)
	if !ok || deviceURI == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'deviceURI' parameter")
		return
	}

	ppd, ok := req.Params["ppd"].(string)
	if !ok || ppd == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'ppd' parameter")
		return
	}

	shared, _ := req.Params["shared"].(bool)
	errorPolicy, _ := req.Params["errorPolicy"].(string)
	information, _ := req.Params["information"].(string)
	location, _ := req.Params["location"].(string)

	if err := manager.CreatePrinter(name, deviceURI, ppd, shared, errorPolicy, information, location); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "printer created"})
}

func handleDeletePrinter(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	if err := manager.DeletePrinter(printerName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "printer deleted"})
}

func handleAcceptJobs(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	if err := manager.AcceptJobs(printerName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "accepting jobs"})
}

func handleRejectJobs(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	if err := manager.RejectJobs(printerName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "rejecting jobs"})
}

func handleSetPrinterShared(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	shared, ok := req.Params["shared"].(bool)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'shared' parameter")
		return
	}

	if err := manager.SetPrinterShared(printerName, shared); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "sharing updated"})
}

func handleSetPrinterLocation(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	location, ok := req.Params["location"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'location' parameter")
		return
	}

	if err := manager.SetPrinterLocation(printerName, location); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "location updated"})
}

func handleSetPrinterInfo(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	info, ok := req.Params["info"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'info' parameter")
		return
	}

	if err := manager.SetPrinterInfo(printerName, info); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "info updated"})
}

func handleMoveJob(conn net.Conn, req Request, manager *Manager) {
	jobIDFloat, ok := req.Params["jobID"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'jobID' parameter")
		return
	}

	destPrinter, ok := req.Params["destPrinter"].(string)
	if !ok || destPrinter == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'destPrinter' parameter")
		return
	}

	if err := manager.MoveJob(int(jobIDFloat), destPrinter); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "job moved"})
}

type TestPageResult struct {
	Success bool   `json:"success"`
	JobID   int    `json:"jobId"`
	Message string `json:"message"`
}

func handlePrintTestPage(conn net.Conn, req Request, manager *Manager) {
	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	jobID, err := manager.PrintTestPage(printerName)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, TestPageResult{Success: true, JobID: jobID, Message: "test page queued"})
}

func handleAddPrinterToClass(conn net.Conn, req Request, manager *Manager) {
	className, ok := req.Params["className"].(string)
	if !ok || className == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'className' parameter")
		return
	}

	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	if err := manager.AddPrinterToClass(className, printerName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "printer added to class"})
}

func handleRemovePrinterFromClass(conn net.Conn, req Request, manager *Manager) {
	className, ok := req.Params["className"].(string)
	if !ok || className == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'className' parameter")
		return
	}

	printerName, ok := req.Params["printerName"].(string)
	if !ok || printerName == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'printerName' parameter")
		return
	}

	if err := manager.RemovePrinterFromClass(className, printerName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "printer removed from class"})
}

func handleDeleteClass(conn net.Conn, req Request, manager *Manager) {
	className, ok := req.Params["className"].(string)
	if !ok || className == "" {
		models.RespondError(conn, req.ID, "missing or invalid 'className' parameter")
		return
	}

	if err := manager.DeleteClass(className); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "class deleted"})
}

func handleRestartJob(conn net.Conn, req Request, manager *Manager) {
	jobIDFloat, ok := req.Params["jobID"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'jobID' parameter")
		return
	}

	if err := manager.RestartJob(int(jobIDFloat)); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "job restarted"})
}

func handleHoldJob(conn net.Conn, req Request, manager *Manager) {
	jobIDFloat, ok := req.Params["jobID"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'jobID' parameter")
		return
	}

	holdUntil, _ := req.Params["holdUntil"].(string)
	if holdUntil == "" {
		holdUntil = "indefinite"
	}

	if err := manager.HoldJob(int(jobIDFloat), holdUntil); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "job held"})
}
