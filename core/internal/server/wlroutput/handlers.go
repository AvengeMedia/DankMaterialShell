package wlroutput

import (
	"encoding/json"
	"fmt"
	"net"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_output_management"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type Request struct {
	ID     int                    `json:"id,omitempty"`
	Method string                 `json:"method"`
	Params map[string]interface{} `json:"params,omitempty"`
}

type SuccessResult struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type HeadConfig struct {
	Name       string  `json:"name"`
	Enabled    bool    `json:"enabled"`
	ModeID     *uint32 `json:"modeId,omitempty"`
	CustomMode *struct {
		Width   int32 `json:"width"`
		Height  int32 `json:"height"`
		Refresh int32 `json:"refresh"`
	} `json:"customMode,omitempty"`
	Position     *struct{ X, Y int32 } `json:"position,omitempty"`
	Transform    *int32                `json:"transform,omitempty"`
	Scale        *float64              `json:"scale,omitempty"`
	AdaptiveSync *uint32               `json:"adaptiveSync,omitempty"`
}

type ConfigurationRequest struct {
	Heads []HeadConfig `json:"heads"`
	Test  bool         `json:"test"`
}

func HandleRequest(conn net.Conn, req Request, manager *Manager) {
	if manager == nil {
		models.RespondError(conn, req.ID, "wlroutput manager not initialized")
		return
	}

	switch req.Method {
	case "wlroutput.getState":
		handleGetState(conn, req, manager)
	case "wlroutput.applyConfiguration":
		handleApplyConfiguration(conn, req, manager, false)
	case "wlroutput.testConfiguration":
		handleApplyConfiguration(conn, req, manager, true)
	case "wlroutput.subscribe":
		handleSubscribe(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleApplyConfiguration(conn net.Conn, req Request, manager *Manager, test bool) {
	headsParam, ok := req.Params["heads"]
	if !ok {
		models.RespondError(conn, req.ID, "missing 'heads' parameter")
		return
	}

	headsJSON, err := json.Marshal(headsParam)
	if err != nil {
		models.RespondError(conn, req.ID, "invalid 'heads' parameter format")
		return
	}

	var heads []HeadConfig
	if err := json.Unmarshal(headsJSON, &heads); err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("invalid heads configuration: %v", err))
		return
	}

	if err := manager.ApplyConfiguration(heads, test); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	msg := "configuration applied"
	if test {
		msg = "configuration test succeeded"
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: msg})
}

func handleSubscribe(conn net.Conn, req Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	if err := json.NewEncoder(conn).Encode(models.Response[State]{
		ID:     req.ID,
		Result: &initialState,
	}); err != nil {
		return
	}

	for state := range stateChan {
		if err := json.NewEncoder(conn).Encode(models.Response[State]{
			Result: &state,
		}); err != nil {
			return
		}
	}
}

func (m *Manager) ApplyConfiguration(heads []HeadConfig, test bool) error {
	if m.manager == nil {
		return fmt.Errorf("output manager not initialized")
	}

	resultChan := make(chan error, 1)

	m.post(func() {
		m.wlMutex.Lock()
		defer m.wlMutex.Unlock()

		config, err := m.manager.CreateConfiguration(m.serial)
		if err != nil {
			resultChan <- fmt.Errorf("failed to create configuration: %w", err)
			return
		}

		statusChan := make(chan error, 1)

		config.SetSucceededHandler(func(e wlr_output_management.ZwlrOutputConfigurationV1SucceededEvent) {
			log.Info("WlrOutput: configuration succeeded")
			statusChan <- nil
		})

		config.SetFailedHandler(func(e wlr_output_management.ZwlrOutputConfigurationV1FailedEvent) {
			log.Warn("WlrOutput: configuration failed")
			statusChan <- fmt.Errorf("compositor rejected configuration")
		})

		config.SetCancelledHandler(func(e wlr_output_management.ZwlrOutputConfigurationV1CancelledEvent) {
			log.Warn("WlrOutput: configuration cancelled")
			statusChan <- fmt.Errorf("configuration cancelled (outdated serial)")
		})

		headsByName := make(map[string]*headState)
		m.heads.Range(func(key uint32, head *headState) bool {
			if !head.finished {
				headsByName[head.name] = head
			}
			return true
		})

		for _, headCfg := range heads {
			head, exists := headsByName[headCfg.Name]
			if !exists {
				config.Destroy()
				resultChan <- fmt.Errorf("head not found: %s", headCfg.Name)
				return
			}

			if !headCfg.Enabled {
				if err := config.DisableHead(head.handle); err != nil {
					config.Destroy()
					resultChan <- fmt.Errorf("failed to disable head %s: %w", headCfg.Name, err)
					return
				}
				continue
			}

			headConfig, err := config.EnableHead(head.handle)
			if err != nil {
				config.Destroy()
				resultChan <- fmt.Errorf("failed to enable head %s: %w", headCfg.Name, err)
				return
			}

			if headCfg.ModeID != nil {
				mode, exists := m.modes.Load(*headCfg.ModeID)

				if !exists {
					config.Destroy()
					resultChan <- fmt.Errorf("mode not found: %d", *headCfg.ModeID)
					return
				}

				if err := headConfig.SetMode(mode.handle); err != nil {
					config.Destroy()
					resultChan <- fmt.Errorf("failed to set mode for %s: %w", headCfg.Name, err)
					return
				}
			} else if headCfg.CustomMode != nil {
				if err := headConfig.SetCustomMode(
					headCfg.CustomMode.Width,
					headCfg.CustomMode.Height,
					headCfg.CustomMode.Refresh,
				); err != nil {
					config.Destroy()
					resultChan <- fmt.Errorf("failed to set custom mode for %s: %w", headCfg.Name, err)
					return
				}
			}

			if headCfg.Position != nil {
				if err := headConfig.SetPosition(headCfg.Position.X, headCfg.Position.Y); err != nil {
					config.Destroy()
					resultChan <- fmt.Errorf("failed to set position for %s: %w", headCfg.Name, err)
					return
				}
			}

			if headCfg.Transform != nil {
				if err := headConfig.SetTransform(*headCfg.Transform); err != nil {
					config.Destroy()
					resultChan <- fmt.Errorf("failed to set transform for %s: %w", headCfg.Name, err)
					return
				}
			}

			if headCfg.Scale != nil {
				if err := headConfig.SetScale(*headCfg.Scale); err != nil {
					config.Destroy()
					resultChan <- fmt.Errorf("failed to set scale for %s: %w", headCfg.Name, err)
					return
				}
			}

			if headCfg.AdaptiveSync != nil {
				if err := headConfig.SetAdaptiveSync(*headCfg.AdaptiveSync); err != nil {
					config.Destroy()
					resultChan <- fmt.Errorf("failed to set adaptive sync for %s: %w", headCfg.Name, err)
					return
				}
			}
		}

		var applyErr error
		if test {
			applyErr = config.Test()
		} else {
			applyErr = config.Apply()
		}

		if applyErr != nil {
			config.Destroy()
			action := "apply"
			if test {
				action = "test"
			}
			resultChan <- fmt.Errorf("failed to %s configuration: %w", action, applyErr)
			return
		}

		go func() {
			select {
			case err := <-statusChan:
				config.Destroy()
				resultChan <- err
			case <-time.After(5 * time.Second):
				config.Destroy()
				resultChan <- fmt.Errorf("timeout waiting for configuration response")
			}
		}()
	})

	return <-resultChan
}
