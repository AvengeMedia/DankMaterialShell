package server

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/bluez"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/brightness"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/cups"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/dwl"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/evdev"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/extworkspace"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/freedesktop"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/loginctl"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wayland"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wlcontext"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wlroutput"
)

const APIVersion = 18

type Capabilities struct {
	Capabilities []string `json:"capabilities"`
}

type ServerInfo struct {
	APIVersion   int      `json:"apiVersion"`
	Capabilities []string `json:"capabilities"`
}

type ServiceEvent struct {
	Service string      `json:"service"`
	Data    interface{} `json:"data"`
}

var networkManager *network.Manager
var loginctlManager *loginctl.Manager
var freedesktopManager *freedesktop.Manager
var waylandManager *wayland.Manager
var bluezManager *bluez.Manager
var cupsManager *cups.Manager
var dwlManager *dwl.Manager
var extWorkspaceManager *extworkspace.Manager
var brightnessManager *brightness.Manager
var wlrOutputManager *wlroutput.Manager
var evdevManager *evdev.Manager
var wlContext *wlcontext.SharedContext

var capabilitySubscribers = make(map[string]chan ServerInfo)
var capabilityMutex sync.RWMutex

var cupsSubscribers = make(map[string]bool)
var cupsSubscribersMutex sync.Mutex

func getSocketDir() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return runtime
	}

	if os.Getuid() == 0 {
		if _, err := os.Stat("/run"); err == nil {
			return "/run/dankdots"
		}
		return "/var/run/dankdots"
	}

	return os.TempDir()
}

func GetSocketPath() string {
	return filepath.Join(getSocketDir(), fmt.Sprintf("danklinux-%d.sock", os.Getpid()))
}

func cleanupStaleSockets() {
	dir := getSocketDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name(), "danklinux-") || !strings.HasSuffix(entry.Name(), ".sock") {
			continue
		}

		pidStr := strings.TrimPrefix(entry.Name(), "danklinux-")
		pidStr = strings.TrimSuffix(pidStr, ".sock")
		pid, err := strconv.Atoi(pidStr)
		if err != nil {
			continue
		}

		process, err := os.FindProcess(pid)
		if err != nil {
			socketPath := filepath.Join(dir, entry.Name())
			os.Remove(socketPath)
			log.Debugf("Removed stale socket: %s", socketPath)
			continue
		}

		err = process.Signal(syscall.Signal(0))
		if err != nil {
			socketPath := filepath.Join(dir, entry.Name())
			os.Remove(socketPath)
			log.Debugf("Removed stale socket: %s", socketPath)
		}
	}
}

func InitializeNetworkManager() error {
	manager, err := network.NewManager()
	if err != nil {
		log.Warnf("Failed to initialize network manager: %v", err)
		return err
	}

	networkManager = manager

	log.Info("Network manager initialized")
	return nil
}

func InitializeLoginctlManager() error {
	manager, err := loginctl.NewManager()
	if err != nil {
		log.Warnf("Failed to initialize loginctl manager: %v", err)
		return err
	}

	loginctlManager = manager

	log.Info("Loginctl manager initialized")
	return nil
}

func InitializeFreedeskManager() error {
	manager, err := freedesktop.NewManager()
	if err != nil {
		log.Warnf("Failed to initialize freedesktop manager: %v", err)
		return err
	}

	freedesktopManager = manager

	log.Info("Freedesktop manager initialized")
	return nil
}

func InitializeWaylandManager() error {
	log.Info("Attempting to initialize Wayland gamma control...")

	if wlContext == nil {
		ctx, err := wlcontext.New()
		if err != nil {
			log.Errorf("Failed to create shared Wayland context: %v", err)
			return err
		}
		wlContext = ctx
	}

	config := wayland.DefaultConfig()
	manager, err := wayland.NewManager(wlContext.Display(), config)
	if err != nil {
		log.Errorf("Failed to initialize wayland manager: %v", err)
		return err
	}

	waylandManager = manager

	log.Info("Wayland gamma control initialized successfully")
	return nil
}

func InitializeBluezManager() error {
	manager, err := bluez.NewManager()
	if err != nil {
		log.Warnf("Failed to initialize bluez manager: %v", err)
		return err
	}

	bluezManager = manager

	log.Info("Bluez manager initialized")
	return nil
}

func InitializeCupsManager() error {
	manager, err := cups.NewManager()
	if err != nil {
		log.Warnf("Failed to initialize cups manager: %v", err)
		return err
	}

	cupsManager = manager

	log.Info("CUPS manager initialized")
	return nil
}

func InitializeDwlManager() error {
	log.Info("Attempting to initialize DWL IPC...")

	if wlContext == nil {
		ctx, err := wlcontext.New()
		if err != nil {
			log.Errorf("Failed to create shared Wayland context: %v", err)
			return err
		}
		wlContext = ctx
	}

	manager, err := dwl.NewManager(wlContext.Display())
	if err != nil {
		log.Debug("Failed to initialize dwl manager: %v", err)
		return err
	}

	dwlManager = manager

	log.Info("DWL IPC initialized successfully")
	return nil
}

func InitializeBrightnessManager() error {
	manager, err := brightness.NewManager()
	if err != nil {
		log.Warnf("Failed to initialize brightness manager: %v", err)
		return err
	}

	brightnessManager = manager

	log.Info("Brightness manager initialized")
	return nil
}

func InitializeExtWorkspaceManager() error {
	log.Info("Attempting to initialize ExtWorkspace...")

	if wlContext == nil {
		ctx, err := wlcontext.New()
		if err != nil {
			log.Errorf("Failed to create shared Wayland context: %v", err)
			return err
		}
		wlContext = ctx
	}

	manager, err := extworkspace.NewManager(wlContext.Display())
	if err != nil {
		log.Debug("Failed to initialize extworkspace manager: %v", err)
		return err
	}

	extWorkspaceManager = manager

	log.Info("ExtWorkspace initialized successfully")
	return nil
}

func InitializeWlrOutputManager() error {
	log.Info("Attempting to initialize WlrOutput management...")

	if wlContext == nil {
		ctx, err := wlcontext.New()
		if err != nil {
			log.Errorf("Failed to create shared Wayland context: %v", err)
			return err
		}
		wlContext = ctx
	}

	manager, err := wlroutput.NewManager(wlContext.Display())
	if err != nil {
		log.Debug("Failed to initialize wlroutput manager: %v", err)
		return err
	}

	wlrOutputManager = manager

	log.Info("WlrOutput management initialized successfully")
	return nil
}

func InitializeEvdevManager() error {
	manager, err := evdev.InitializeManager()
	if err != nil {
		log.Warnf("Failed to initialize evdev manager: %v", err)
		return err
	}

	evdevManager = manager

	log.Info("Evdev manager initialized")
	return nil
}

func handleConnection(conn net.Conn) {
	defer conn.Close()

	caps := getCapabilities()
	capsData, _ := json.Marshal(caps)
	conn.Write(capsData)
	conn.Write([]byte("\n"))

	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		line := scanner.Bytes()

		var req models.Request
		if err := json.Unmarshal(line, &req); err != nil {
			log.Warnf("handleConnection: Failed to unmarshal JSON: %v, line: %s", err, string(line))
			models.RespondError(conn, 0, "invalid json")
			continue
		}

		go RouteRequest(conn, req)
	}
}

func getCapabilities() Capabilities {
	caps := []string{"plugins"}

	if networkManager != nil {
		caps = append(caps, "network")
	}

	if loginctlManager != nil {
		caps = append(caps, "loginctl")
	}

	if freedesktopManager != nil {
		caps = append(caps, "freedesktop")
	}

	if waylandManager != nil {
		caps = append(caps, "gamma")
	}

	if bluezManager != nil {
		caps = append(caps, "bluetooth")
	}

	if cupsManager != nil {
		caps = append(caps, "cups")
	}

	if dwlManager != nil {
		caps = append(caps, "dwl")
	}

	if extWorkspaceManager != nil {
		caps = append(caps, "extworkspace")
	}

	if brightnessManager != nil {
		caps = append(caps, "brightness")
	}

	if wlrOutputManager != nil {
		caps = append(caps, "wlroutput")
	}

	if evdevManager != nil {
		caps = append(caps, "evdev")
	}

	return Capabilities{Capabilities: caps}
}

func getServerInfo() ServerInfo {
	caps := []string{"plugins"}

	if networkManager != nil {
		caps = append(caps, "network")
	}

	if loginctlManager != nil {
		caps = append(caps, "loginctl")
	}

	if freedesktopManager != nil {
		caps = append(caps, "freedesktop")
	}

	if waylandManager != nil {
		caps = append(caps, "gamma")
	}

	if bluezManager != nil {
		caps = append(caps, "bluetooth")
	}

	if cupsManager != nil {
		caps = append(caps, "cups")
	}

	if dwlManager != nil {
		caps = append(caps, "dwl")
	}

	if extWorkspaceManager != nil {
		caps = append(caps, "extworkspace")
	}

	if brightnessManager != nil {
		caps = append(caps, "brightness")
	}

	if wlrOutputManager != nil {
		caps = append(caps, "wlroutput")
	}

	if evdevManager != nil {
		caps = append(caps, "evdev")
	}

	return ServerInfo{
		APIVersion:   APIVersion,
		Capabilities: caps,
	}
}

func notifyCapabilityChange() {
	capabilityMutex.RLock()
	defer capabilityMutex.RUnlock()

	info := getServerInfo()
	for _, ch := range capabilitySubscribers {
		select {
		case ch <- info:
		default:
		}
	}
}

func handleSubscribe(conn net.Conn, req models.Request) {
	clientID := fmt.Sprintf("meta-client-%p", conn)

	var services []string
	if servicesParam, ok := req.Params["services"].([]interface{}); ok {
		for _, s := range servicesParam {
			if str, ok := s.(string); ok {
				services = append(services, str)
			}
		}
	}

	if len(services) == 0 {
		services = []string{"all"}
	}

	subscribeAll := false
	for _, s := range services {
		if s == "all" {
			subscribeAll = true
			break
		}
	}

	var wg sync.WaitGroup
	eventChan := make(chan ServiceEvent, 256)
	stopChan := make(chan struct{})

	capChan := make(chan ServerInfo, 64)
	capabilityMutex.Lock()
	capabilitySubscribers[clientID+"-capabilities"] = capChan
	capabilityMutex.Unlock()

	wg.Add(1)
	go func() {
		defer wg.Done()
		defer func() {
			capabilityMutex.Lock()
			delete(capabilitySubscribers, clientID+"-capabilities")
			capabilityMutex.Unlock()
		}()

		for {
			select {
			case info, ok := <-capChan:
				if !ok {
					return
				}
				select {
				case eventChan <- ServiceEvent{Service: "server", Data: info}:
				case <-stopChan:
					return
				}
			case <-stopChan:
				return
			}
		}
	}()

	shouldSubscribe := func(service string) bool {
		if subscribeAll {
			return true
		}
		for _, s := range services {
			if s == service {
				return true
			}
		}
		return false
	}

	if shouldSubscribe("network") && networkManager != nil {
		wg.Add(1)
		netChan := networkManager.Subscribe(clientID + "-network")
		go func() {
			defer wg.Done()
			defer networkManager.Unsubscribe(clientID + "-network")

			initialState := networkManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "network", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-netChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "network", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("network.credentials") && networkManager != nil {
		wg.Add(1)
		credChan := networkManager.SubscribeCredentials(clientID + "-credentials")
		go func() {
			defer wg.Done()
			defer networkManager.UnsubscribeCredentials(clientID + "-credentials")

			for {
				select {
				case prompt, ok := <-credChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "network.credentials", Data: prompt}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("loginctl") && loginctlManager != nil {
		wg.Add(1)
		loginChan := loginctlManager.Subscribe(clientID + "-loginctl")
		go func() {
			defer wg.Done()
			defer loginctlManager.Unsubscribe(clientID + "-loginctl")

			initialState := loginctlManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "loginctl", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-loginChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "loginctl", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("freedesktop") && freedesktopManager != nil {
		wg.Add(1)
		freedesktopChan := freedesktopManager.Subscribe(clientID + "-freedesktop")
		go func() {
			defer wg.Done()
			defer freedesktopManager.Unsubscribe(clientID + "-freedesktop")

			initialState := freedesktopManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "freedesktop", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-freedesktopChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "freedesktop", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("gamma") && waylandManager != nil {
		wg.Add(1)
		waylandChan := waylandManager.Subscribe(clientID + "-gamma")
		go func() {
			defer wg.Done()
			defer waylandManager.Unsubscribe(clientID + "-gamma")

			initialState := waylandManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "gamma", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-waylandChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "gamma", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("bluetooth") && bluezManager != nil {
		wg.Add(1)
		bluezChan := bluezManager.Subscribe(clientID + "-bluetooth")
		go func() {
			defer wg.Done()
			defer bluezManager.Unsubscribe(clientID + "-bluetooth")

			initialState := bluezManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "bluetooth", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-bluezChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "bluetooth", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("bluetooth.pairing") && bluezManager != nil {
		wg.Add(1)
		pairingChan := bluezManager.SubscribePairing(clientID + "-pairing")
		go func() {
			defer wg.Done()
			defer bluezManager.UnsubscribePairing(clientID + "-pairing")

			for {
				select {
				case prompt, ok := <-pairingChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "bluetooth.pairing", Data: prompt}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("cups") {
		cupsSubscribersMutex.Lock()
		wasEmpty := len(cupsSubscribers) == 0
		cupsSubscribers[clientID+"-cups"] = true
		cupsSubscribersMutex.Unlock()

		if wasEmpty {
			if err := InitializeCupsManager(); err != nil {
				log.Warnf("Failed to initialize CUPS manager for subscription: %v", err)
			} else {
				notifyCapabilityChange()
			}
		}

		if cupsManager != nil {
			wg.Add(1)
			cupsChan := cupsManager.Subscribe(clientID + "-cups")
			go func() {
				defer wg.Done()
				defer func() {
					cupsManager.Unsubscribe(clientID + "-cups")

					cupsSubscribersMutex.Lock()
					delete(cupsSubscribers, clientID+"-cups")
					isEmpty := len(cupsSubscribers) == 0
					cupsSubscribersMutex.Unlock()

					if isEmpty {
						log.Info("Last CUPS subscriber disconnected, shutting down CUPS manager")
						if cupsManager != nil {
							cupsManager.Close()
							cupsManager = nil
							notifyCapabilityChange()
						}
					}
				}()

				initialState := cupsManager.GetState()
				select {
				case eventChan <- ServiceEvent{Service: "cups", Data: initialState}:
				case <-stopChan:
					return
				}

				for {
					select {
					case state, ok := <-cupsChan:
						if !ok {
							return
						}
						select {
						case eventChan <- ServiceEvent{Service: "cups", Data: state}:
						case <-stopChan:
							return
						}
					case <-stopChan:
						return
					}
				}
			}()
		}
	}

	if shouldSubscribe("dwl") && dwlManager != nil {
		wg.Add(1)
		dwlChan := dwlManager.Subscribe(clientID + "-dwl")
		go func() {
			defer wg.Done()
			defer dwlManager.Unsubscribe(clientID + "-dwl")

			initialState := dwlManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "dwl", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-dwlChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "dwl", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("extworkspace") && extWorkspaceManager != nil {
		wg.Add(1)
		extWorkspaceChan := extWorkspaceManager.Subscribe(clientID + "-extworkspace")
		go func() {
			defer wg.Done()
			defer extWorkspaceManager.Unsubscribe(clientID + "-extworkspace")

			initialState := extWorkspaceManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "extworkspace", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-extWorkspaceChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "extworkspace", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("brightness") && brightnessManager != nil {
		wg.Add(2)
		brightnessStateChan := brightnessManager.Subscribe(clientID + "-brightness-state")
		brightnessUpdateChan := brightnessManager.SubscribeUpdates(clientID + "-brightness-updates")

		go func() {
			defer wg.Done()
			defer brightnessManager.Unsubscribe(clientID + "-brightness-state")

			initialState := brightnessManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "brightness", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-brightnessStateChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "brightness", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()

		go func() {
			defer wg.Done()
			defer brightnessManager.UnsubscribeUpdates(clientID + "-brightness-updates")

			for {
				select {
				case update, ok := <-brightnessUpdateChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "brightness.update", Data: update}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("wlroutput") && wlrOutputManager != nil {
		wg.Add(1)
		wlrOutputChan := wlrOutputManager.Subscribe(clientID + "-wlroutput")
		go func() {
			defer wg.Done()
			defer wlrOutputManager.Unsubscribe(clientID + "-wlroutput")

			initialState := wlrOutputManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "wlroutput", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-wlrOutputChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "wlroutput", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	if shouldSubscribe("evdev") && evdevManager != nil {
		wg.Add(1)
		evdevChan := evdevManager.Subscribe(clientID + "-evdev")
		go func() {
			defer wg.Done()
			defer evdevManager.Unsubscribe(clientID + "-evdev")

			initialState := evdevManager.GetState()
			select {
			case eventChan <- ServiceEvent{Service: "evdev", Data: initialState}:
			case <-stopChan:
				return
			}

			for {
				select {
				case state, ok := <-evdevChan:
					if !ok {
						return
					}
					select {
					case eventChan <- ServiceEvent{Service: "evdev", Data: state}:
					case <-stopChan:
						return
					}
				case <-stopChan:
					return
				}
			}
		}()
	}

	go func() {
		wg.Wait()
		close(eventChan)
	}()

	info := getServerInfo()
	if err := json.NewEncoder(conn).Encode(models.Response[ServiceEvent]{
		ID:     req.ID,
		Result: &ServiceEvent{Service: "server", Data: info},
	}); err != nil {
		close(stopChan)
		return
	}

	for event := range eventChan {
		if err := json.NewEncoder(conn).Encode(models.Response[ServiceEvent]{
			ID:     req.ID,
			Result: &event,
		}); err != nil {
			close(stopChan)
			return
		}
	}
}

func cleanupManagers() {
	if networkManager != nil {
		networkManager.Close()
	}
	if loginctlManager != nil {
		loginctlManager.Close()
	}
	if freedesktopManager != nil {
		freedesktopManager.Close()
	}
	if waylandManager != nil {
		waylandManager.Close()
	}
	if bluezManager != nil {
		bluezManager.Close()
	}
	if cupsManager != nil {
		cupsManager.Close()
	}
	if dwlManager != nil {
		dwlManager.Close()
	}
	if extWorkspaceManager != nil {
		extWorkspaceManager.Close()
	}
	if brightnessManager != nil {
		brightnessManager.Close()
	}
	if wlrOutputManager != nil {
		wlrOutputManager.Close()
	}
	if evdevManager != nil {
		evdevManager.Close()
	}
	if wlContext != nil {
		wlContext.Close()
	}
}

func Start(printDocs bool) error {
	cleanupStaleSockets()

	socketPath := GetSocketPath()
	os.Remove(socketPath)

	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		return err
	}
	defer listener.Close()
	defer cleanupManagers()

	log.Infof("DMS API Server listening on: %s", socketPath)
	log.Infof("API Version: %d", APIVersion)
	log.Info("Protocol: JSON over Unix socket")
	log.Info("Request format: {\"id\": <any>, \"method\": \"...\", \"params\": {...}}")
	log.Info("Response format: {\"id\": <any>, \"result\": {...}} or {\"id\": <any>, \"error\": \"...\"}")
	log.Info("")
	if printDocs {
		log.Info("Available methods:")
		log.Info("  ping          - Test connection")
		log.Info("  getServerInfo - Get server info (API version and capabilities)")
		log.Info("  subscribe     - Subscribe to multiple services (params: services [default: all])")
		log.Info("Plugins:")
		log.Info(" plugins.list                - List all plugins")
		log.Info(" plugins.listInstalled       - List installed plugins")
		log.Info(" plugins.install             - Install plugin (params: name)")
		log.Info(" plugins.uninstall           - Uninstall plugin (params: name)")
		log.Info(" plugins.update              - Update plugin (params: name)")
		log.Info(" plugins.search              - Search plugins (params: query, category?, compositor?, capability?)")
		log.Info("Network:")
		log.Info(" network.getState            - Get current network state")
		log.Info(" network.wifi.scan           - Scan for WiFi networks")
		log.Info(" network.wifi.networks       - Get WiFi network list")
		log.Info(" network.wifi.connect        - Connect to WiFi (params: ssid, password?, username?)")
		log.Info(" network.wifi.disconnect     - Disconnect WiFi")
		log.Info(" network.wifi.forget         - Forget network (params: ssid)")
		log.Info(" network.wifi.toggle         - Toggle WiFi radio")
		log.Info(" network.wifi.enable         - Enable WiFi")
		log.Info(" network.wifi.disable        - Disable WiFi")
		log.Info(" network.wifi.setAutoconnect - Set network autoconnect (params: ssid, autoconnect)")
		log.Info(" network.ethernet.connect    - Connect Ethernet")
		log.Info(" network.ethernet.connect.config - Connect Ethernet to a specific configuration")
		log.Info(" network.ethernet.disconnect - Disconnect Ethernet")
		log.Info(" network.vpn.profiles        - List VPN profiles")
		log.Info(" network.vpn.active          - List active VPN connections")
		log.Info(" network.vpn.connect         - Connect VPN (params: uuidOrName|name|uuid, singleActive?)")
		log.Info(" network.vpn.disconnect      - Disconnect VPN (params: uuidOrName|name|uuid)")
		log.Info(" network.vpn.disconnectAll   - Disconnect all VPNs")
		log.Info(" network.vpn.clearCredentials - Clear saved VPN credentials (params: uuidOrName|name|uuid)")
		log.Info(" network.preference.set      - Set preference (params: preference [auto|wifi|ethernet])")
		log.Info(" network.info                - Get network info (params: ssid)")
		log.Info(" network.credentials.submit  - Submit credentials for prompt (params: token, secrets, save?)")
		log.Info(" network.credentials.cancel  - Cancel credential prompt (params: token)")
		log.Info(" network.subscribe           - Subscribe to network state changes (streaming)")
		log.Info("Loginctl:")
		log.Info(" loginctl.getState           - Get current session state")
		log.Info(" loginctl.lock               - Lock session")
		log.Info(" loginctl.unlock             - Unlock session")
		log.Info(" loginctl.activate           - Activate session")
		log.Info(" loginctl.setIdleHint        - Set idle hint (params: idle)")
		log.Info(" loginctl.setLockBeforeSuspend - Set lock before suspend (params: enabled)")
		log.Info(" loginctl.setSleepInhibitorEnabled - Enable/disable sleep inhibitor (params: enabled)")
		log.Info(" loginctl.lockerReady        - Signal locker UI is ready (releases sleep inhibitor)")
		log.Info(" loginctl.terminate          - Terminate session")
		log.Info(" loginctl.subscribe          - Subscribe to session state changes (streaming)")
		log.Info("Freedesktop:")
		log.Info(" freedesktop.getState                  - Get accounts & settings state")
		log.Info(" freedesktop.accounts.setIconFile      - Set profile icon (params: path)")
		log.Info(" freedesktop.accounts.setRealName      - Set real name (params: name)")
		log.Info(" freedesktop.accounts.setEmail         - Set email (params: email)")
		log.Info(" freedesktop.accounts.setLanguage      - Set language (params: language)")
		log.Info(" freedesktop.accounts.setLocation      - Set location (params: location)")
		log.Info(" freedesktop.accounts.getUserIconFile  - Get user icon (params: username)")
		log.Info(" freedesktop.settings.getColorScheme   - Get color scheme")
		log.Info(" freedesktop.settings.setIconTheme     - Set icon theme (params: iconTheme)")
		log.Info("Wayland:")
		log.Info(" wayland.gamma.getState                - Get current gamma control state")
		log.Info(" wayland.gamma.setTemperature          - Set temperature range (params: low, high)")
		log.Info(" wayland.gamma.setLocation             - Set location (params: latitude, longitude)")
		log.Info(" wayland.gamma.setManualTimes          - Set manual times (params: sunrise, sunset)")
		log.Info(" wayland.gamma.setGamma                - Set gamma value (params: gamma)")
		log.Info(" wayland.gamma.setEnabled              - Enable/disable gamma control (params: enabled)")
		log.Info(" wayland.gamma.subscribe               - Subscribe to gamma state changes (streaming)")
		log.Info("Bluetooth:")
		log.Info(" bluetooth.getState                    - Get current bluetooth state")
		log.Info(" bluetooth.startDiscovery              - Start device discovery")
		log.Info(" bluetooth.stopDiscovery               - Stop device discovery")
		log.Info(" bluetooth.setPowered                  - Set adapter power state (params: powered)")
		log.Info(" bluetooth.pair                        - Pair with device (params: device)")
		log.Info(" bluetooth.connect                     - Connect to device (params: device)")
		log.Info(" bluetooth.disconnect                  - Disconnect from device (params: device)")
		log.Info(" bluetooth.remove                      - Remove/unpair device (params: device)")
		log.Info(" bluetooth.trust                       - Trust device (params: device)")
		log.Info(" bluetooth.untrust                     - Untrust device (params: device)")
		log.Info(" bluetooth.pairing.submit              - Submit pairing response (params: token, secrets?, accept?)")
		log.Info(" bluetooth.pairing.cancel              - Cancel pairing prompt (params: token)")
		log.Info(" bluetooth.subscribe                   - Subscribe to bluetooth state changes (streaming)")
		log.Info("CUPS:")
		log.Info(" cups.getPrinters                      - Get printers list")
		log.Info(" cups.getJobs                          - Get non-completed jobs list (params: printerName)")
		log.Info(" cups.pausePrinter                     - Pause printer (params: printerName)")
		log.Info(" cups.resumePrinter                    - Resume printer (params: printerName)")
		log.Info(" cups.cancelJob                        - Cancel job (params: printerName, jobID)")
		log.Info(" cups.purgeJobs                        - Cancel all jobs (params: printerName)")
		log.Info("DWL:")
		log.Info(" dwl.getState                          - Get current dwl state (tags, windows, layouts)")
		log.Info(" dwl.setTags                           - Set active tags (params: output, tagmask, toggleTagset)")
		log.Info(" dwl.setClientTags                     - Set focused client tags (params: output, andTags, xorTags)")
		log.Info(" dwl.setLayout                         - Set layout (params: output, index)")
		log.Info(" dwl.subscribe                         - Subscribe to dwl state changes (streaming)")
		log.Info("ExtWorkspace:")
		log.Info(" extworkspace.getState                 - Get current workspace state (groups, workspaces)")
		log.Info(" extworkspace.activateWorkspace        - Activate workspace (params: groupID, workspaceID)")
		log.Info(" extworkspace.deactivateWorkspace      - Deactivate workspace (params: groupID, workspaceID)")
		log.Info(" extworkspace.removeWorkspace          - Remove workspace (params: groupID, workspaceID)")
		log.Info(" extworkspace.createWorkspace          - Create workspace (params: groupID, name)")
		log.Info(" extworkspace.subscribe                - Subscribe to workspace state changes (streaming)")
		log.Info("Brightness:")
		log.Info(" brightness.getState                   - Get current brightness state for all devices")
		log.Info(" brightness.setBrightness              - Set device brightness (params: device, percent)")
		log.Info(" brightness.increment                  - Increment device brightness (params: device, step?)")
		log.Info(" brightness.decrement                  - Decrement device brightness (params: device, step?)")
		log.Info(" brightness.rescan                     - Rescan for brightness devices (e.g., after plugging in monitor)")
		log.Info(" brightness.subscribe                  - Subscribe to brightness state changes (streaming)")
		log.Info("   Subscription events:")
		log.Info("     - brightness       : Full device list (on rescan, DDC discovery, device changes)")
		log.Info("     - brightness.update: Single device update (on brightness change for efficiency)")
		log.Info("WlrOutput:")
		log.Info(" wlroutput.getState                    - Get current output configuration state")
		log.Info(" wlroutput.applyConfiguration          - Apply output configuration (params: heads)")
		log.Info(" wlroutput.testConfiguration           - Test output configuration without applying (params: heads)")
		log.Info(" wlroutput.subscribe                   - Subscribe to output state changes (streaming)")
		log.Info("   Head configuration params:")
		log.Info("     - name         : Output name (required)")
		log.Info("     - enabled      : Enable/disable output (required)")
		log.Info("     - modeId       : Mode ID from available modes (optional)")
		log.Info("     - customMode   : Custom mode {width, height, refresh} (optional)")
		log.Info("     - position     : Position {x, y} (optional)")
		log.Info("     - transform    : Transform value (optional)")
		log.Info("     - scale        : Scale value (optional)")
		log.Info("     - adaptiveSync : Adaptive sync state (optional)")
		log.Info("Evdev:")
		log.Info(" evdev.getState                        - Get current evdev state (caps lock)")
		log.Info(" evdev.subscribe                       - Subscribe to evdev state changes (streaming)")
		log.Info("")
	}
	log.Info("Initializing managers...")
	log.Info("")

	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()

		if err := InitializeNetworkManager(); err != nil {
			log.Warnf("Network manager unavailable: %v", err)
		} else {
			notifyCapabilityChange()
			return
		}

		for range ticker.C {
			if networkManager != nil {
				return
			}
			if err := InitializeNetworkManager(); err == nil {
				log.Info("Network manager initialized")
				notifyCapabilityChange()
				return
			}
		}
	}()

	go func() {
		if err := InitializeLoginctlManager(); err != nil {
			log.Warnf("Loginctl manager unavailable: %v", err)
		} else {
			notifyCapabilityChange()
		}
	}()

	go func() {
		if err := InitializeFreedeskManager(); err != nil {
			log.Warnf("Freedesktop manager unavailable: %v", err)
		} else if freedesktopManager != nil {
			freedesktopManager.NotifySubscribers()
			notifyCapabilityChange()
		}
	}()

	if err := InitializeWaylandManager(); err != nil {
		log.Warnf("Wayland manager unavailable: %v", err)
	}

	go func() {
		if err := InitializeBluezManager(); err != nil {
			log.Warnf("Bluez manager unavailable: %v", err)
		} else {
			notifyCapabilityChange()
		}
	}()

	if err := InitializeDwlManager(); err != nil {
		log.Debugf("DWL manager unavailable: %v", err)
	}

	if err := InitializeExtWorkspaceManager(); err != nil {
		log.Debugf("ExtWorkspace manager unavailable: %v", err)
	}

	if err := InitializeWlrOutputManager(); err != nil {
		log.Debugf("WlrOutput manager unavailable: %v", err)
	}

	fatalErrChan := make(chan error, 1)
	if wlrOutputManager != nil {
		go func() {
			err := <-wlrOutputManager.FatalError()
			fatalErrChan <- fmt.Errorf("WlrOutput fatal error: %w", err)
		}()
	}

	go func() {
		if err := InitializeBrightnessManager(); err != nil {
			log.Warnf("Brightness manager unavailable: %v", err)
		} else {
			notifyCapabilityChange()
		}
	}()

	go func() {
		if err := InitializeEvdevManager(); err != nil {
			log.Debugf("Evdev manager unavailable: %v", err)
		} else {
			notifyCapabilityChange()
		}
	}()

	if wlContext != nil {
		wlContext.Start()
		log.Info("Wayland event dispatcher started")
	}

	log.Info("")
	log.Infof("Ready! Capabilities: %v", getCapabilities().Capabilities)

	listenerErrChan := make(chan error, 1)

	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				listenerErrChan <- err
				return
			}
			go handleConnection(conn)
		}
	}()

	select {
	case err := <-listenerErrChan:
		return err
	case err := <-fatalErrChan:
		return err
	}
}
