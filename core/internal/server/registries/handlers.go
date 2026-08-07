package registries

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/registries"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/spf13/afero"
)

type RegistryInfo struct {
	Name     string `json:"name"`
	URL      string `json:"url"`
	Official bool   `json:"official"`
}

type SuccessResult struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func HandleRequest(conn *models.Conn, req models.Request) {
	switch req.Method {
	case "registries.list":
		HandleList(conn, req)
	case "registries.add":
		HandleAdd(conn, req)
	case "registries.remove":
		HandleRemove(conn, req)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func HandleList(conn *models.Conn, req models.Request) {
	sources := registries.Load(afero.NewOsFs())
	result := make([]RegistryInfo, len(sources))
	for i, s := range sources {
		result[i] = RegistryInfo{Name: s.Name, URL: s.URL, Official: s.Official()}
	}
	models.Respond(conn, req.ID, result)
}

func HandleAdd(conn *models.Conn, req models.Request) {
	name, ok := models.Get[string](req, "name")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
		return
	}
	url, ok := models.Get[string](req, "url")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'url' parameter")
		return
	}

	if err := registries.Add(afero.NewOsFs(), name, url); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{
		Success: true,
		Message: fmt.Sprintf("registry added: %s", name),
	})
}

func HandleRemove(conn *models.Conn, req models.Request) {
	name, ok := models.Get[string](req, "name")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
		return
	}

	if err := registries.Remove(afero.NewOsFs(), name); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{
		Success: true,
		Message: fmt.Sprintf("registry removed: %s", name),
	})
}
