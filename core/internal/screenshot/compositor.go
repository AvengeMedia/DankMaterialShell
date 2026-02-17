package screenshot

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/dwl_ipc"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_output_management"
	wlhelpers "github.com/AvengeMedia/DankMaterialShell/core/internal/wayland/client"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

type Compositor int

const (
	CompositorUnknown Compositor = iota
	CompositorHyprland
	CompositorSway
	CompositorNiri
	CompositorDWL
	CompositorScroll
	CompositorMiracle
)

var detectedCompositor Compositor = -1

func DetectCompositor() Compositor {
	if detectedCompositor >= 0 {
		return detectedCompositor
	}

	hyprlandSig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	niriSocket := os.Getenv("NIRI_SOCKET")
	swaySocket := os.Getenv("SWAYSOCK")
	scrollSocket := os.Getenv("SCROLLSOCK")
	miracleSocket := os.Getenv("MIRACLESOCK")

	switch {
	case niriSocket != "":
		if _, err := os.Stat(niriSocket); err == nil {
			detectedCompositor = CompositorNiri
			return detectedCompositor
		}
	case scrollSocket != "":
		if _, err := os.Stat(scrollSocket); err == nil {
			detectedCompositor = CompositorScroll
			return detectedCompositor
		}
	case miracleSocket != "":
		if _, err := os.Stat(miracleSocket); err == nil {
			detectedCompositor = CompositorMiracle
			return detectedCompositor
		}
	case swaySocket != "":
		if _, err := os.Stat(swaySocket); err == nil {
			detectedCompositor = CompositorSway
			return detectedCompositor
		}
	case hyprlandSig != "":
		detectedCompositor = CompositorHyprland
		return detectedCompositor
	}

	if detectDWLProtocol() {
		detectedCompositor = CompositorDWL
		return detectedCompositor
	}

	detectedCompositor = CompositorUnknown
	return detectedCompositor
}

func detectDWLProtocol() bool {
	display, err := client.Connect("")
	if err != nil {
		return false
	}
	ctx := display.Context()
	defer ctx.Close()

	registry, err := display.GetRegistry()
	if err != nil {
		return false
	}

	found := false
	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		if e.Interface == dwl_ipc.ZdwlIpcManagerV2InterfaceName {
			found = true
		}
	})

	if err := wlhelpers.Roundtrip(display, ctx); err != nil {
		return false
	}

	return found
}

func SetCompositorDWL() {
	detectedCompositor = CompositorDWL
}

type WindowGeometry struct {
	X               int32
	Y               int32
	Width           int32
	Height          int32
	Output          string
	Scale           float64
	OutputX         int32
	OutputY         int32
	OutputTransform int32
}

func GetActiveWindow() (*WindowGeometry, error) {
	switch DetectCompositor() {
	case CompositorHyprland:
		return getHyprlandActiveWindow()
	case CompositorDWL:
		return getDWLActiveWindow()
	default:
		return nil, fmt.Errorf("window capture requires Hyprland or DWL")
	}
}

type hyprlandWindow struct {
	At   [2]int32 `json:"at"`
	Size [2]int32 `json:"size"`
}

func getHyprlandActiveWindow() (*WindowGeometry, error) {
	output, err := exec.Command("hyprctl", "-j", "activewindow").Output()
	if err != nil {
		return nil, fmt.Errorf("hyprctl activewindow: %w", err)
	}

	var win hyprlandWindow
	if err := json.Unmarshal(output, &win); err != nil {
		return nil, fmt.Errorf("parse activewindow: %w", err)
	}

	if win.Size[0] <= 0 || win.Size[1] <= 0 {
		return nil, fmt.Errorf("no active window")
	}

	return &WindowGeometry{
		X:      win.At[0],
		Y:      win.At[1],
		Width:  win.Size[0],
		Height: win.Size[1],
	}, nil
}

type hyprlandMonitor struct {
	Name    string  `json:"name"`
	X       int32   `json:"x"`
	Y       int32   `json:"y"`
	Width   int32   `json:"width"`
	Height  int32   `json:"height"`
	Scale   float64 `json:"scale"`
	Focused bool    `json:"focused"`
}

func GetHyprlandMonitorScale(name string) float64 {
	output, err := exec.Command("hyprctl", "-j", "monitors").Output()
	if err != nil {
		return 0
	}

	var monitors []hyprlandMonitor
	if err := json.Unmarshal(output, &monitors); err != nil {
		return 0
	}

	for _, m := range monitors {
		if m.Name == name {
			return m.Scale
		}
	}
	return 0
}

func getHyprlandFocusedMonitor() string {
	output, err := exec.Command("hyprctl", "-j", "monitors").Output()
	if err != nil {
		return ""
	}

	var monitors []hyprlandMonitor
	if err := json.Unmarshal(output, &monitors); err != nil {
		return ""
	}

	for _, m := range monitors {
		if m.Focused {
			return m.Name
		}
	}
	return ""
}

func GetHyprlandMonitorGeometry(name string) (x, y, w, h int32, ok bool) {
	output, err := exec.Command("hyprctl", "-j", "monitors").Output()
	if err != nil {
		return 0, 0, 0, 0, false
	}

	var monitors []hyprlandMonitor
	if err := json.Unmarshal(output, &monitors); err != nil {
		return 0, 0, 0, 0, false
	}

	for _, m := range monitors {
		if m.Name == name {
			logicalW := int32(float64(m.Width) / m.Scale)
			logicalH := int32(float64(m.Height) / m.Scale)
			return m.X, m.Y, logicalW, logicalH, true
		}
	}
	return 0, 0, 0, 0, false
}

type swayWorkspace struct {
	Output  string `json:"output"`
	Focused bool   `json:"focused"`
}

func getSwayFocusedMonitor() string {
	output, err := exec.Command("swaymsg", "-t", "get_workspaces").Output()
	if err != nil {
		return ""
	}

	var workspaces []swayWorkspace
	if err := json.Unmarshal(output, &workspaces); err != nil {
		return ""
	}

	for _, ws := range workspaces {
		if ws.Focused {
			return ws.Output
		}
	}
	return ""
}

func getScrollFocusedMonitor() string {
	output, err := exec.Command("scrollmsg", "-t", "get_workspaces").Output()
	if err != nil {
		return ""
	}

	var workspaces []swayWorkspace
	if err := json.Unmarshal(output, &workspaces); err != nil {
		return ""
	}

	for _, ws := range workspaces {
		if ws.Focused {
			return ws.Output
		}
	}
	return ""
}

func getMiracleFocusedMonitor() string {
	output, err := exec.Command("miraclemsg", "-t", "get_workspaces").Output()
	if err != nil {
		return ""
	}

	var workspaces []swayWorkspace
	if err := json.Unmarshal(output, &workspaces); err != nil {
		return ""
	}

	for _, ws := range workspaces {
		if ws.Focused {
			return ws.Output
		}
	}
	return ""
}

type niriWorkspace struct {
	Output    string `json:"output"`
	IsFocused bool   `json:"is_focused"`
}

func getNiriFocusedMonitor() string {
	output, err := exec.Command("niri", "msg", "-j", "workspaces").Output()
	if err != nil {
		return ""
	}

	var workspaces []niriWorkspace
	if err := json.Unmarshal(output, &workspaces); err != nil {
		return ""
	}

	for _, ws := range workspaces {
		if ws.IsFocused {
			return ws.Output
		}
	}
	return ""
}

var dwlActiveOutput string

func SetDWLActiveOutput(name string) {
	dwlActiveOutput = name
}

func getDWLFocusedMonitor() string {
	if dwlActiveOutput != "" {
		return dwlActiveOutput
	}
	return queryDWLActiveOutput()
}

func queryDWLActiveOutput() string {
	display, err := client.Connect("")
	if err != nil {
		return ""
	}
	ctx := display.Context()
	defer ctx.Close()

	registry, err := display.GetRegistry()
	if err != nil {
		return ""
	}

	var dwlManager *dwl_ipc.ZdwlIpcManagerV2
	outputs := make(map[uint32]*client.Output)

	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		switch e.Interface {
		case dwl_ipc.ZdwlIpcManagerV2InterfaceName:
			mgr := dwl_ipc.NewZdwlIpcManagerV2(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, mgr); err == nil {
				dwlManager = mgr
			}
		case client.OutputInterfaceName:
			out := client.NewOutput(ctx)
			version := e.Version
			if version > 4 {
				version = 4
			}
			if err := registry.Bind(e.Name, e.Interface, version, out); err == nil {
				outputs[e.Name] = out
			}
		}
	})

	if err := wlhelpers.Roundtrip(display, ctx); err != nil {
		return ""
	}

	if dwlManager == nil || len(outputs) == 0 {
		return ""
	}

	outputNames := make(map[uint32]string)
	for name, out := range outputs {
		n := name
		out.SetNameHandler(func(e client.OutputNameEvent) {
			outputNames[n] = e.Name
		})
	}

	if err := wlhelpers.Roundtrip(display, ctx); err != nil {
		return ""
	}

	type outputState struct {
		name     string
		active   bool
		gotFrame bool
	}
	states := make(map[uint32]*outputState)

	for name, out := range outputs {
		dwlOut, err := dwlManager.GetOutput(out)
		if err != nil {
			continue
		}
		state := &outputState{name: outputNames[name]}
		states[name] = state

		dwlOut.SetActiveHandler(func(e dwl_ipc.ZdwlIpcOutputV2ActiveEvent) {
			state.active = e.Active != 0
		})
		dwlOut.SetFrameHandler(func(e dwl_ipc.ZdwlIpcOutputV2FrameEvent) {
			state.gotFrame = true
		})
	}

	allFramesReceived := func() bool {
		for _, s := range states {
			if !s.gotFrame {
				return false
			}
		}
		return true
	}

	for !allFramesReceived() {
		if err := ctx.Dispatch(); err != nil {
			return ""
		}
	}

	for _, state := range states {
		if state.active {
			return state.name
		}
	}

	return ""
}

func GetFocusedMonitor() string {
	switch DetectCompositor() {
	case CompositorHyprland:
		return getHyprlandFocusedMonitor()
	case CompositorSway:
		return getSwayFocusedMonitor()
	case CompositorScroll:
		return getScrollFocusedMonitor()
	case CompositorMiracle:
		return getMiracleFocusedMonitor()
	case CompositorNiri:
		return getNiriFocusedMonitor()
	case CompositorDWL:
		return getDWLFocusedMonitor()
	}
	return ""
}

type outputInfo struct {
	x, y      int32
	transform int32
}

func getOutputInfo(outputName string) (*outputInfo, bool) {
	display, err := client.Connect("")
	if err != nil {
		return nil, false
	}
	ctx := display.Context()
	defer ctx.Close()

	registry, err := display.GetRegistry()
	if err != nil {
		return nil, false
	}

	var outputManager *wlr_output_management.ZwlrOutputManagerV1

	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		if e.Interface == wlr_output_management.ZwlrOutputManagerV1InterfaceName {
			mgr := wlr_output_management.NewZwlrOutputManagerV1(ctx)
			version := e.Version
			if version > 4 {
				version = 4
			}
			if err := registry.Bind(e.Name, e.Interface, version, mgr); err == nil {
				outputManager = mgr
			}
		}
	})

	if err := wlhelpers.Roundtrip(display, ctx); err != nil {
		return nil, false
	}

	if outputManager == nil {
		return nil, false
	}

	type headState struct {
		name      string
		x, y      int32
		transform int32
	}
	heads := make(map[*wlr_output_management.ZwlrOutputHeadV1]*headState)
	done := false

	outputManager.SetHeadHandler(func(e wlr_output_management.ZwlrOutputManagerV1HeadEvent) {
		state := &headState{}
		heads[e.Head] = state
		e.Head.SetNameHandler(func(ne wlr_output_management.ZwlrOutputHeadV1NameEvent) {
			state.name = ne.Name
		})
		e.Head.SetPositionHandler(func(pe wlr_output_management.ZwlrOutputHeadV1PositionEvent) {
			state.x = pe.X
			state.y = pe.Y
		})
		e.Head.SetTransformHandler(func(te wlr_output_management.ZwlrOutputHeadV1TransformEvent) {
			state.transform = te.Transform
		})
	})
	outputManager.SetDoneHandler(func(e wlr_output_management.ZwlrOutputManagerV1DoneEvent) {
		done = true
	})

	for !done {
		if err := ctx.Dispatch(); err != nil {
			return nil, false
		}
	}

	for _, state := range heads {
		if state.name == outputName {
			return &outputInfo{
				x:         state.x,
				y:         state.y,
				transform: state.transform,
			}, true
		}
	}

	return nil, false
}

func getDWLActiveWindow() (*WindowGeometry, error) {
	display, err := client.Connect("")
	if err != nil {
		return nil, fmt.Errorf("connect: %w", err)
	}
	ctx := display.Context()
	defer ctx.Close()

	registry, err := display.GetRegistry()
	if err != nil {
		return nil, fmt.Errorf("get registry: %w", err)
	}

	var dwlManager *dwl_ipc.ZdwlIpcManagerV2
	outputs := make(map[uint32]*client.Output)

	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		switch e.Interface {
		case dwl_ipc.ZdwlIpcManagerV2InterfaceName:
			mgr := dwl_ipc.NewZdwlIpcManagerV2(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, mgr); err == nil {
				dwlManager = mgr
			}
		case client.OutputInterfaceName:
			out := client.NewOutput(ctx)
			version := e.Version
			if version > 4 {
				version = 4
			}
			if err := registry.Bind(e.Name, e.Interface, version, out); err == nil {
				outputs[e.Name] = out
			}
		}
	})

	if err := wlhelpers.Roundtrip(display, ctx); err != nil {
		return nil, fmt.Errorf("roundtrip: %w", err)
	}

	if dwlManager == nil {
		return nil, fmt.Errorf("dwl_ipc_manager not available")
	}

	if len(outputs) == 0 {
		return nil, fmt.Errorf("no outputs found")
	}

	outputNames := make(map[uint32]string)
	for name, out := range outputs {
		n := name
		out.SetNameHandler(func(e client.OutputNameEvent) {
			outputNames[n] = e.Name
		})
	}

	if err := wlhelpers.Roundtrip(display, ctx); err != nil {
		return nil, fmt.Errorf("roundtrip: %w", err)
	}

	type dwlOutputState struct {
		output      *dwl_ipc.ZdwlIpcOutputV2
		name        string
		active      bool
		x, y        int32
		w, h        int32
		scalefactor uint32
		gotFrame    bool
	}

	dwlOutputs := make(map[uint32]*dwlOutputState)
	for name, out := range outputs {
		dwlOut, err := dwlManager.GetOutput(out)
		if err != nil {
			continue
		}
		state := &dwlOutputState{output: dwlOut, name: outputNames[name]}
		dwlOutputs[name] = state

		dwlOut.SetActiveHandler(func(e dwl_ipc.ZdwlIpcOutputV2ActiveEvent) {
			state.active = e.Active != 0
		})
		dwlOut.SetXHandler(func(e dwl_ipc.ZdwlIpcOutputV2XEvent) {
			state.x = e.X
		})
		dwlOut.SetYHandler(func(e dwl_ipc.ZdwlIpcOutputV2YEvent) {
			state.y = e.Y
		})
		dwlOut.SetWidthHandler(func(e dwl_ipc.ZdwlIpcOutputV2WidthEvent) {
			state.w = e.Width
		})
		dwlOut.SetHeightHandler(func(e dwl_ipc.ZdwlIpcOutputV2HeightEvent) {
			state.h = e.Height
		})
		dwlOut.SetScalefactorHandler(func(e dwl_ipc.ZdwlIpcOutputV2ScalefactorEvent) {
			state.scalefactor = e.Scalefactor
		})
		dwlOut.SetFrameHandler(func(e dwl_ipc.ZdwlIpcOutputV2FrameEvent) {
			state.gotFrame = true
		})
	}

	allFramesReceived := func() bool {
		for _, s := range dwlOutputs {
			if !s.gotFrame {
				return false
			}
		}
		return true
	}

	for !allFramesReceived() {
		if err := ctx.Dispatch(); err != nil {
			return nil, fmt.Errorf("dispatch: %w", err)
		}
	}

	for _, state := range dwlOutputs {
		if !state.active {
			continue
		}
		if state.w <= 0 || state.h <= 0 {
			return nil, fmt.Errorf("no active window")
		}
		scale := float64(state.scalefactor) / 100.0
		if scale <= 0 {
			scale = 1.0
		}

		geom := &WindowGeometry{
			X:      state.x,
			Y:      state.y,
			Width:  state.w,
			Height: state.h,
			Output: state.name,
			Scale:  scale,
		}

		if info, ok := getOutputInfo(state.name); ok {
			geom.OutputX = info.x
			geom.OutputY = info.y
			geom.OutputTransform = info.transform
		}

		return geom, nil
	}

	return nil, fmt.Errorf("no active output found")
}
