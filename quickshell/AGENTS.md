# AGENTS.md

This file provides guidance to AI coding assistants.

## AI Guidance

* After receiving tool results, carefully reflect on their quality and determine optimal next steps before proceeding. Use your thinking to plan and iterate based on this new information, and then take the best next action.
* For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.
* Before you finish, please verify your solution
* Do what has been asked; nothing more, nothing less.
* NEVER create files unless they're absolutely necessary for achieving your goal.
* ALWAYS prefer editing an existing file to creating a new one.
* NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
* When you update or modify core context files, also update markdown documentation and memory bank
* When asked to commit changes, exclude AGENTS.md and AGENTS-*.md referenced memory bank system files from any commits.

## Memory Bank System

This project uses a structured memory bank system with specialized context files. Always check these files for relevant information before starting work:

### Core Context Files

* **AGENTS-activeContext.md** - Current session state, goals, and progress (if exists)
* **AGENTS-patterns.md** - Established code patterns and conventions (if exists)
* **AGENTS-decisions.md** - Architecture decisions and rationale (if exists)
* **AGENTS-troubleshooting.md** - Common issues and proven solutions (if exists)
* **AGENTS-config-variables.md** - Configuration variables reference (if exists)
* **AGENTS-temp.md** - Temporary scratch pad (only read when referenced)

**Important:** Always reference the active context file first to understand what's currently being worked on and maintain session continuity.

### Memory Bank System Backups

When asked to backup Memory Bank System files, you will copy the core context files above and @.agents settings directory to directory @/path/to/backup-directory. If files already exist in the backup directory, you will overwrite them.

## Project Overview

DankMaterialShell is a complete desktop environment for Wayland compositors, built as a **monorepo** with two main components:

**1. Go Backend (core/)** - System integration, IPC server, and CLI tools (~118,000 lines)
**2. QML Frontend (quickshell/)** - UI layer consuming the backend's IPC API

**Architecture**: The Go backend provides all system integration via IPC (Inter-Process Communication), while QML services act as thin wrappers that communicate with the backend. This separation allows for robust system integration while maintaining a reactive, modern UI.

**Compositor Support**: Niri, Hyprland, MangoWC, Sway, labwc, Scroll (6 compositors supported)
**Distribution Support**: Arch, Fedora, Debian, Ubuntu, openSUSE, Gentoo (6 distributions supported)

## Technology Stack

### Backend (core/)
- **Go 1.24+** - System integration and backend services
- **Wayland Protocols** - Display management, screenshots, clipboard, workspaces
- **D-Bus** - Bluetooth, NetworkManager, systemd-logind, desktop portals
- **IPC Server** - Unix socket JSON API for QML ↔ Go communication
- **CLI Tools** - `dms` command with 20+ subcommands, `dankinstall` TUI installer

### Frontend (quickshell/)
- **QML (Qt Modeling Language)** - UI components and visual presentation
- **Quickshell Framework** - QML-based desktop shell framework
- **Qt/QtQuick** - UI rendering and controls
- **Matugen** - Dynamic theming system for wallpaper-based colors

## Development Commands

### Backend (Go)

```bash
cd core/

# Build
make                 # Build dms CLI (bin/dms)
make dankinstall     # Build installer (bin/dankinstall)
make test            # Run tests
make dist            # Build distribution binaries (no update/greeter features)

# Install
sudo make install    # Install to /usr/local/bin/dms

# Development
gofmt -w .           # Format Go code
go mod tidy          # Clean up dependencies
golangci-lint run    # Run linter

# Run dms CLI
./bin/dms run        # Start shell via dms daemon
./bin/dms ipc <cmd>  # Send IPC command to running shell
./bin/dms --help     # View all commands
```

### Frontend (QML)

```bash
cd quickshell/

# Run the shell (requires dms backend running or use 'dms run')
quickshell -p shell.qml
qs -p .              # Shorthand
qs -v -p shell.qml   # Verbose debugging

# Code formatting and linting
qmlfmt -t 4 -i 4 -b 250 -w /path/to/file.qml  # Format QML (don't use qmlformat)
make -C .. lint-qml  # From quickshell/, call the repo-root lint target; requires the generated .qmlls.ini VFS from `qs -p .`
./qmlformat-all.sh   # Format all QML files
```

## Architecture Overview

### Monorepo Structure

The project is organized as a monorepo with clear separation between backend and frontend:

```
DankMaterialShell/
├── core/               # Go backend (~118,000 lines)
│   ├── cmd/            # Binary entrypoints
│   │   ├── dms/        # Main CLI with 20+ commands
│   │   └── dankinstall/# TUI installer
│   ├── internal/       # System integration packages (23 packages)
│   │   ├── clipboard/  # Clipboard history (ext-data-control-v1)
│   │   ├── colorpicker/# Native Wayland color picker
│   │   ├── screenshot/ # Screen capture functionality
│   │   ├── brightness/ # DDC/CI & backlight control
│   │   ├── bluez/      # Bluetooth D-Bus integration
│   │   ├── config/     # Configuration management
│   │   ├── dank16/     # Terminal color scheme generator
│   │   ├── deps/       # Dependency detection
│   │   ├── distros/    # Distribution-specific installers (6 distros)
│   │   ├── greeter/    # Display manager greeter
│   │   ├── keybinds/   # Compositor keybind management
│   │   ├── matugen/    # Matugen integration
│   │   ├── notify/     # Notification daemon
│   │   ├── plugins/    # Plugin registry & management
│   │   ├── screenshot/ # Screenshot utilities
│   │   ├── server/     # IPC server with 15+ submodules
│   │   ├── themes/     # Theme registry
│   │   ├── wayland/    # Wayland protocol handlers
│   │   └── windowrules/# Window rules management
│   ├── pkg/            # Shared packages
│   │   ├── go-wayland/ # Wayland client library
│   │   ├── dbusutil/   # D-Bus utilities
│   │   ├── ipp/        # Internet Printing Protocol
│   │   └── syncmap/    # Thread-safe map
│   └── go.mod          # Go module definition
├── quickshell/         # QML frontend (UI layer) - see "QML Frontend Architecture" below
│   ├── shell.qml       # Main entry point
│   ├── Services/       # IPC client wrappers
│   ├── Modules/        # UI components
│   ├── Widgets/        # Reusable controls
│   ├── Modals/         # Full-screen overlays
│   └── Common/         # Shared resources
├── distro/             # Distribution packaging
│   ├── arch/           # AUR packages
│   ├── fedora/         # RPM specs
│   ├── debian/         # Debian packaging
│   ├── ubuntu/         # Ubuntu PPAs
│   ├── opensuse/       # OBS packaging
│   └── nix/            # NixOS modules
└── flake.nix           # Nix flake
```

### Go Backend Architecture

The backend provides all system integration through these key components:

#### 1. IPC Server (`internal/server/`)

JSON-based RPC over Unix socket (`/tmp/dms-ipc-<uid>.sock`) with 15+ submodules:

- **apppicker/** - Application search and launch
- **bluez/** - Bluetooth device management
- **brightness/** - Display and monitor brightness
- **browser/** - Web browser integration
- **clipboard/** - Clipboard history and persistence
- **cups/** - Printer management
- **dbus/** - Generic D-Bus interface access
- **dwl/** - dwl/MangoWC compositor integration
- **evdev/** - Keyboard input device monitoring
- **extworkspace/** - Workspace protocol integration
- **freedesktop/** - Desktop portal integration
- **loginctl/** - systemd-logind (power, sessions, inhibitors)
- **network/** - Network management (multi-backend)
- **params/** - IPC parameter validation
- **plugins/** - Plugin lifecycle management
- **thememode/** - Dark/light mode synchronization
- **themes/** - Theme registry operations
- **wayland/** - Night mode, gamma control, output management
- **wlcontext/** - Wayland connection management
- **wlroutput/** - wlr-output-management protocol

#### 2. CLI Commands (`cmd/dms/`)

The `dms` CLI provides 20+ commands:

```bash
dms run [-d]                    # Start shell (daemon mode)
dms restart / kill              # Manage shell process
dms ipc <command> [args]        # Send IPC commands
dms brightness [list|set]       # Display brightness control
dms color pick [--rgb|--hsv]    # Native color picker
dms clipboard [list|clear]      # Clipboard management
dms screenshot [area|output]    # Take screenshots
dms notify send <msg>           # Send notifications
dms dpms [on|off]              # Display power management
dms keybinds [reload|list]     # Keybind management
dms windowrules [add|remove]   # Window rules management
dms matugen [generate|reload]  # Theme generation
dms dank16 [generate]          # Terminal theme generation
dms config [get|set]           # Configuration management
dms features                    # Show available features
dms doctor                      # System diagnostics
dms plugins [browse|install]   # Plugin management
dms update [check]             # Update DMS and deps
dms greeter [install|enable]   # Greeter management
```

#### 3. Wayland Integration (`internal/wayland/`, `internal/proto/`)

Native Wayland protocol implementations (as client):

- `wlr-gamma-control-unstable-v1` - Night mode color temperature
- `wlr-screencopy-unstable-v1` - Screenshots and color picker
- `wlr-layer-shell-unstable-v1` - Overlay surfaces
- `wlr-output-management-unstable-v1` - Display configuration
- `wlr-output-power-management-unstable-v1` - DPMS control
- `ext-data-control-v1` - Clipboard history
- `ext-workspace-v1` - Workspace integration
- `dwl-ipc-unstable-v2` - dwl/MangoWC IPC
- `keyboard-shortcuts-inhibit-unstable-v1` - Shortcut inhibition
- `wp-viewporter` - Fractional scaling support

#### 4. D-Bus Integration (`internal/server/bluez/`, `internal/server/network/`, etc.)

**Client interfaces** (consuming external services):
- `org.bluez` - Bluetooth with pairing agent
- `org.freedesktop.NetworkManager` - Network management
- `net.connman.iwd` - iwd Wi-Fi backend
- `org.freedesktop.network1` - systemd-networkd
- `org.freedesktop.login1` - Session control, inhibitors, brightness
- `org.freedesktop.Accounts` - User account info
- `org.freedesktop.portal.Desktop` - Desktop appearance settings
- CUPS via IPP - Printer management

**Server interfaces** (implementing services):
- `org.freedesktop.ScreenSaver` - Screensaver inhibition for media playback

#### 5. Distribution Support (`internal/distros/`)

`dankinstall` TUI installer with full support for:

- **Arch Linux** - pacman + AUR (yay/paru)
- **Fedora** - dnf + COPR
- **Debian** - apt + OBS repos
- **Ubuntu** - apt + PPAs
- **openSUSE** - zypper + OBS
- **Gentoo** - emerge + GURU overlay + USE flags

Each distro has custom package mappings, dependency detection, and installation logic.

### QML Frontend Architecture

The frontend follows a clean modular architecture with shell.qml reduced to ~250 lines:

```
shell.qml           # Main entry point (minimal orchestration)
├── Common/         # Shared resources (12 files)
│   ├── Theme.qml   # Material Design 3 theme singleton
│   ├── SettingsData.qml # User preferences and configuration
│   ├── SessionData.qml # Session state management
│   ├── Colors.qml  # Dynamic color scheme
│   └── [8 more utility files]
├── Services/       # System integration singletons (20 files)
│   ├── AudioService.qml
│   ├── NetworkService.qml
│   ├── BluetoothService.qml
│   ├── DisplayService.qml
│   ├── NotificationService.qml
│   ├── WeatherService.qml
│   ├── PluginService.qml
│   └── [14 more services]
├── Modules/        # UI components (93 files)
│   ├── TopBar/     # Panel components (13 files)
│   ├── ControlCenter/ # System controls (13 files)
│   ├── Notifications/ # Notification system (12 files)
│   ├── AppDrawer/  # Application launcher (3 files)
│   ├── Settings/   # Configuration interface (11 files)
│   ├── ProcessList/ # System monitoring (8 files)
│   ├── Dock/       # Application dock (6 files)
│   ├── Lock/       # Screen lock system (4 files)
│   └── [23 more module files]
├── Modals/         # Full-screen overlays (10 files)
│   ├── SettingsModal.qml
│   ├── ClipboardHistoryModal.qml
│   ├── ProcessListModal.qml
│   ├── PluginSettingsModal.qml
│   └── [7 more modals]
├── Widgets/        # Reusable UI controls (19 files)
│   ├── DankIcon.qml
│   ├── DankSlider.qml
│   ├── DankToggle.qml
│   ├── DankTabBar.qml
│   ├── DankGridView.qml
│   ├── DankListView.qml
│   └── [13 more widgets]
└── plugins/        # External plugins directory ($CONFIGPATH/DankMaterialShell/plugins/)
    └── PluginName/ # Example Plugin structure
        ├── plugin.json            # Plugin manifest
        ├── PluginNameWidget.qml   # Widget component
        └── PluginNameSettings.qml # Settings UI
```

### Component Organization

1. **Shell Entry Point** (`shell.qml`)
   - Minimal orchestration layer (~250 lines)
   - Imports and instantiates components
   - Handles global state and property bindings
   - Multi-monitor support using Quickshell's `Variants`

2. **Common/** - Shared resources
   - `Theme.qml` - Material Design 3 theme singleton with consistent colors, spacing, fonts
   - `Utilities.js` - Shared functions for workspace parsing, notifications, menu handling

3. **Services/** - IPC client wrappers (20 singletons)
   - **Pattern**: All services use `Singleton` type with `id: root`
   - **Architecture**: Thin QML wrappers that communicate with Go backend via IPC
   - **Examples**: AudioService, NetworkService, BluetoothService, DisplayService, WeatherService, NotificationService, CalendarService, BatteryService, NiriService, MprisController
   - Services expose properties and functions that send IPC requests to the Go backend
   - The Go backend handles all actual system integration (D-Bus, Wayland, hardware control)
   - QML services receive IPC responses and update their properties for reactive UI binding

4. **Modules/** - UI components (93 files)
   - **TopBar/**: Panel components with workspace switching, system indicators, media controls
   - **ControlCenter/**: System controls for WiFi, Bluetooth, audio, display settings
   - **Notifications/**: Complete notification system with center, popups, and keyboard navigation
   - **AppDrawer/**: Application launcher with grid/list views and category filtering
   - **Settings/**: Comprehensive configuration interface with multiple tabs
   - **ProcessList/**: System monitoring with process management and performance metrics
   - **Dock/**: Application dock with running apps and window management
   - **Lock/**: Screen lock system with authentication

5. **Modals/** - Full-screen overlays (10 files)
   - Modal system for settings, clipboard history, file browser, network info, power menu
   - Unified modal management with consistent styling and keyboard navigation

6. **Widgets/** - Reusable UI controls (19 files)
   - **DankIcon**: Centralized icon component with Material Design font integration
   - **DankSlider**: Enhanced slider with animations and smart detection
   - **DankToggle**: Consistent toggle switch component
   - **DankTabBar**: Unified tab bar implementation
   - **DankGridView**: Reusable grid view with adaptive columns
   - **DankListView**: Reusable list view with configurable styling
   - **DankTextField**: Styled text input with validation
   - **DankDropdown**: Dropdown selection component
   - **DankPopout**: Base popout component for overlays
   - **StateLayer**: Material Design 3 interaction states
   - **StyledRect/StyledText**: Themed base components
   - **CachingImage**: Optimized image loading with caching
   - **DankLocationSearch**: Location picker with search
   - **SystemLogo**: Animated system branding component

7. **Plugins/** - External plugin system (`$CONFIGPATH/DankMaterialShell/plugins/`)
   - **PluginService**: Discovers, loads, and manages plugin lifecycle
   - **Dynamic Loading**: Plugins loaded at runtime from external directory
   - **DankBar Integration**: Plugin widgets rendered alongside built-in widgets
   - **Settings System**: Per-plugin settings with persistence

### Key Architectural Patterns

1. **Singleton Services Pattern**:
   ```qml
   import QtQuick
   import Quickshell
   import Quickshell.Io
   pragma Singleton
   pragma ComponentBehavior: Bound

   Singleton {
       id: root

       property type value: defaultValue

       function performAction() { /* implementation */ }
   }
   ```

2. **Smart Feature Detection**: Services detect system capabilities:
   ```qml
   property bool featureAvailable: false
   // Auto-hide UI elements when features unavailable
   visible: ServiceName.featureAvailable
   ```

3. **Property Bindings**: Reactive UI updates through property binding
4. **Material Design Theming**: Consistent use of Theme singleton throughout

### Important Components

- **ControlCenter**: System controls (WiFi, Bluetooth, brightness, volume, night mode)
- **AppLauncher**: Full-featured app grid/list with 93+ applications, search, categories
- **ClipboardHistoryModal**: Complete clipboard management with cliphist integration
- **TopBar**: Per-monitor panels with workspace switching, clock, system tray
- **System App Theming**: Automatic GTK and Qt application theming using matugen templates

#### Key Widgets

- **DankIcon**: Centralized icon component with automatic Material Design font detection
- **DankSlider**: Enhanced slider with animations and smart detection
- **DankToggle**: Consistent toggle switch component
- **DankTabBar**: Unified tab bar implementation
- **DankGridView**: Reusable grid view with adaptive columns
- **DankListView**: Reusable list view with configurable styling

## Code Conventions

### Internationalization (I18n)

When adding user-facing strings, wrap them in `I18n.tr()` with context:

```qml
import qs.Common

Text {
    text: I18n.tr("Hello World", "Hello world greeting that appears on the lock screen")
}
```

**Best practices:**
- Keep new terms to a minimum - reuse existing translations when possible
- Check `quickshell/translations/en.json` for existing terms
- Example: Use "Autoconnect" instead of "Auto-connect" if it's already translated
- Provide clear context for translators in the second parameter

### QML Style Guidelines

1. **Structure and Formatting**:
   - Use 4-space indentation
   - `id` should be the first property
   - Properties before signal handlers before child components
   - Prefer property bindings over imperative code
   - **CRITICAL**: NEVER add comments unless absolutely essential for complex logic understanding. Code should be self-documenting through clear naming and structure. Comments are a code smell indicating unclear implementation.
   - Use guard statements, example `if (abc) { something() return;} somethingElse();`
   - Don't use crazy ternary stuff, but use it for simple if else only. `propertyVal: a ? b : c`

2. **Naming Conventions**:
   - **Services**: Use `Singleton` type with `id: root`
   - **Components**: Use descriptive names (e.g., `DankSlider`, `TopBar`)
   - **Properties**: camelCase for properties, PascalCase for types

3. **Null-Safe Operations**:
   - **Use** `object?.property`

4. **Component Structure**:
   ```qml
   // For regular components
   Item {
       id: root

       property type name: value

       signal customSignal(type param)

       onSignal: { /* handler */ }

       Component { /* children */ }
   }

   // For services (singletons)
   Singleton {
       id: root

       property bool featureAvailable: false
       property type currentValue: defaultValue

       function performAction(param) { /* implementation */ }
   }
   ```

### Import Guidelines

#### QML Import Order

```qml
import QtQuick
import QtQuick.Controls  // If needed
import Quickshell
import Quickshell.Widgets
import Quickshell.Io     // For Process, FileView
import qs.Common         // For Theme, utilities
import qs.Services       // For service access
import qs.Widgets        // For reusable widgets (DankIcon, etc.)
```

#### Go Import Order

Follow standard Go conventions:

```go
import (
    // Standard library
    "context"
    "fmt"
    "os"

    // External dependencies
    "github.com/godbus/dbus/v5"
    "github.com/spf13/cobra"

    // Internal packages
    "github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
    "github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)
```

**Service Dependencies:**
- QML Services should NOT import other QML services
- Modules and Widgets can import and use services via property bindings
- Use `Theme.propertyName` for consistent styling
- Use `DankIcon { name: "icon_name" }` for all icons instead of manual Text components

### Go Backend Code Conventions

#### 1. Package Structure

- **cmd/** - Binary entrypoints only, minimal logic
- **internal/** - Implementation packages (not importable by external projects)
- **pkg/** - Shared packages (potentially importable)
- Each package should have a clear, single responsibility

#### 2. Error Handling

```go
// Always wrap errors with context
if err != nil {
    return fmt.Errorf("failed to connect to D-Bus: %w", err)
}

// Use custom error types for specific error handling
if errors.Is(err, errdefs.ErrNotFound) {
    // Handle specific error
}
```

#### 3. IPC Handler Pattern

All server modules should follow this pattern:

```go
package mymodule

import (
    "github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
    "github.com/AvengeMedia/DankMaterialShell/core/internal/server/params"
)

type Manager struct {
    // State, connections, etc.
}

func NewManager() (*Manager, error) {
    // Initialize
    return &Manager{}, nil
}

func (m *Manager) HandleRequest(req models.Request) models.Response {
    switch req.Method {
    case "list":
        return m.handleList(req)
    case "action":
        return m.handleAction(req)
    default:
        return models.ErrorResponse(req.ID, "unknown method")
    }
}

func (m *Manager) handleAction(req models.Request) models.Response {
    // Extract and validate parameters
    param, err := params.String(req.Params, "name")
    if err != nil {
        return models.ErrorResponse(req.ID, err.Error())
    }

    // Perform action
    result, err := m.doSomething(param)
    if err != nil {
        return models.ErrorResponse(req.ID, err.Error())
    }

    return models.SuccessResponse(req.ID, result)
}
```

#### 4. D-Bus Integration

```go
// Use context for cancellation
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

// Always check for D-Bus availability
if !dbusutil.ServiceExists(conn, "org.bluez") {
    return fmt.Errorf("bluetooth service not available")
}

// Handle signals properly with channels
signals := make(chan *dbus.Signal, 10)
conn.Signal(signals)
defer conn.RemoveSignal(signals)
```

#### 5. Wayland Protocol Integration

```go
// Check protocol availability before use
if registry.GetGammaControl() == nil {
    return errdefs.ErrNotSupported
}

// Clean up Wayland resources
defer output.Destroy()
defer surface.Destroy()
```

#### 6. Testing

```go
// Use table-driven tests
func TestManager_HandleRequest(t *testing.T) {
    tests := []struct {
        name    string
        request models.Request
        want    models.Response
        wantErr bool
    }{
        {
            name: "valid request",
            request: models.Request{
                ID:     "1",
                Method: "list",
            },
            wantErr: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            m := NewManager()
            got := m.HandleRequest(tt.request)
            // Assertions
        })
    }
}

// Use mocks for external dependencies (see internal/mocks/)
```

#### 7. Logging

```go
import "github.com/AvengeMedia/DankMaterialShell/core/internal/log"

// Use appropriate log levels
log.Debug("Processing request", "method", req.Method)
log.Info("Service started", "address", addr)
log.Warn("Feature unavailable", "reason", "missing dependency")
log.Error("Failed to connect", "error", err)
log.Fatal("Critical failure", "error", err) // Only for unrecoverable errors
```

### Component Development Patterns

#### QML Frontend Patterns

1. **Code Reuse - Search Before Writing**:
   - **ALWAYS** search the codebase for existing functions before writing new ones
   - Use `Grep` or `Glob` tools to find existing implementations (e.g., search for "getWifiIcon", "getDeviceIcon")
   - Many utility functions already exist in Services/ and Common/ - reuse them instead of duplicating
   - Examples of existing utility functions: `Theme.getBatteryIcon()`, `BluetoothService.getDeviceIcon()`, `WeatherService.getWeatherIcon()`
   - If similar functionality exists, extend or refactor rather than duplicate

2. **Smart Feature Detection**:
   ```qml
   // In services - detect capabilities
   property bool brightnessAvailable: false

   // In modules - adapt UI accordingly
   DankSlider {
       visible: DisplayService.brightnessAvailable
       enabled: DisplayService.brightnessAvailable
       value: DisplayService.brightnessLevel
   }
   ```

3. **Reusable Components**:
   - Create reusable widgets for common patterns (like DankSlider)
   - Use configurable properties for different use cases
   - Include proper signal handling with unique names (avoid `valueChanged`)

4. **Service Integration**:
   - Services expose properties and functions
   - Modules and Widgets bind to service properties for reactive updates
   - Use service functions for actions: `ServiceName.performAction(value)`
   - **CRITICAL**: DO NOT create wrapper functions for everything - bind directly to underlying APIs when possible
   - Example: Use `BluetoothService.adapter.discovering = true` instead of `BluetoothService.startScan()`
   - Example: Use `device.connect()` directly instead of `BluetoothService.connect(device.address)`

### Error Handling and Debugging

1. **Console Logging**:
   ```qml
   // Use appropriate log levels
   console.log("Info message")           // General info
   console.warn("Warning message")       // Warnings
   console.error("Error message")        // Errors

   // Include context in service operations
   onExited: (exitCode) => {
       if (exitCode !== 0) {
           console.warn("Service failed:", serviceName, "exit code:", exitCode)
       }
   }
   ```

2. **Graceful Degradation**:
   - Always check feature availability before showing UI
   - Provide fallbacks for missing system tools
   - Use `visible` and `enabled` properties appropriately

## Multi-Monitor Support

The shell uses Quickshell's `Variants` pattern for multi-monitor support:
- Each connected monitor gets its own top bar instance
- Workspace switchers are compositor-aware (6 compositors supported)
- Monitors are automatically detected by screen name (DP-1, DP-2, etc.)
- **Niri**: Workspaces dynamically synchronized with per-output workspaces
- **Hyprland**: Integrates with Hyprland's workspace system
- **MangoWC**: Uses dwl-ipc-unstable-v2 for tag management
- **Sway/labwc/Scroll**: Standard i3 IPC integration

## IPC Communication Model

### QML ↔ Go Backend Communication

The shell uses a Unix socket-based IPC system for all system integration:

1. **Go Backend** (`core/internal/server/`) runs an IPC server on `/tmp/dms-ipc-<uid>.sock`
2. **QML Services** send JSON-RPC requests to the backend
3. **Backend** handles system integration (D-Bus, Wayland, hardware) and responds
4. **QML Services** receive responses and update properties for UI reactivity

**Example Flow:**
```
User clicks WiFi network in UI
  ↓
QML NetworkService.connectNetwork(ssid, password)
  ↓
IPC Request: {"method": "network.connect", "params": {...}}
  ↓
Go Backend: internal/server/network/ handles D-Bus to NetworkManager
  ↓
IPC Response: {"result": {"success": true}}
  ↓
QML Service updates properties → UI updates reactively
```

**Why this architecture?**
- **Separation of concerns**: UI (QML) vs system integration (Go)
- **Type safety**: Go provides compile-time safety for system APIs
- **Performance**: Go handles expensive operations without blocking UI
- **Robustness**: Backend crashes don't crash the UI, and vice versa
- **Testing**: Backend can be tested independently of UI

**Development implications:**
- QML Services should be **thin wrappers** - minimal logic, just IPC calls
- System integration logic belongs in Go backend packages
- When adding features, implement backend first, then QML wrapper
- Use `dms ipc <command>` CLI to test backend functionality independently

## Common Development Tasks

### Testing and Validation

When modifying the shell:

**QML Frontend:**
1. **Test changes**: `qs -p .` (automatic reload on file changes)
2. **Code quality**: Run `./qmlformat-all.sh` or `qmlformat -i **/*.qml`, then from repo root run `make lint-qml` after Quickshell has generated the local `.qmlls.ini` VFS with `qs -p .`
3. **Performance**: Ensure animations remain smooth (60 FPS target)
4. **Theming**: Use `Theme.propertyName` for Material Design 3 consistency

**Go Backend:**
1. **Build**: `cd core && make` to build dms CLI
2. **Tests**: `make test` to run Go unit tests (add appropriate test coverage for new code)
3. **Linting**: `gofmt -w .`, `go mod tidy`, and `golangci-lint run`
4. **IPC testing**: Use `dms ipc <command>` to test backend functionality
5. **Rebuild**: After backend changes, rebuild with `make` and restart shell

**Integration:**
1. **Full test**: `dms restart` to restart both backend and frontend
2. **Wayland compatibility**: Test on Wayland session
3. **Multi-monitor**: Verify behavior with multiple displays
4. **Compositor compatibility**: Test on Niri, Hyprland, MangoWC, Sway, labwc, Scroll when possible
5. **Distribution compatibility**: Test installation on Arch, Fedora, Debian, Ubuntu, openSUSE, Gentoo
6. **Feature detection**: Test on systems with/without required tools

### Adding New Modules

1. **Create component**:
   ```bash
   # Create new module file
   touch Modules/NewModule.qml
   ```

2. **Follow module patterns**:
   - Use `Theme.propertyName` for styling
   - Import `qs.Common` and `qs.Services` as needed
   - Import `qs.Widgets` for reusable components
   - Bind to service properties for reactive updates
   - Consider per-screen vs global behavior
   - Use `DankIcon` for icons instead of manual Text components

3. **Integration in shell.qml**:
   ```qml
   NewModule {
       id: newModule
       // Configure properties
   }
   ```

### Adding New Widgets

1. **Create component**:
   ```bash
   # Create new widget file
   touch Widgets/NewWidget.qml
   ```

2. **Follow widget patterns**:
   - Use `Theme.propertyName` for styling
   - Import `qs.Common` for theming
   - Focus on reusability and composition
   - Keep widgets simple and focused
   - Use `DankIcon` for icons instead of manual Text components

### Adding New Services

**Important**: Most system integration should be done in the Go backend, with QML services as thin IPC wrappers.

#### Step 1: Implement Go Backend

1. **Create backend package**:
   ```bash
   mkdir -p core/internal/server/newsystem
   ```

2. **Implement backend logic** (`core/internal/server/newsystem/manager.go`):
   ```go
   package newsystem

   import (
       "github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
   )

   type Manager struct {
       // State and D-Bus connections
   }

   func NewManager() (*Manager, error) {
       // Initialize D-Bus connections, Wayland protocols, etc.
       return &Manager{}, nil
   }

   func (m *Manager) HandleRequest(req models.Request) models.Response {
       // Handle IPC requests
   }
   ```

3. **Add IPC handler** in `core/internal/server/router.go`:
   ```go
   newsystemMgr, _ := newsystem.NewManager()
   router["newsystem"] = newsystemMgr.HandleRequest
   ```

4. **Test backend**: `dms ipc newsystem.action '{"param": "value"}'`

#### Step 2: Create QML Wrapper

1. **Create service**:
   ```qml
   // Services/NewService.qml
   import QtQuick
   import Quickshell
   import Quickshell.Io
   pragma Singleton
   pragma ComponentBehavior: Bound

   Singleton {
       id: root

       property bool featureAvailable: false
       property type currentValue: defaultValue

       function performAction(param) {
           // Send IPC request to Go backend
           ipcClient.send("newsystem.action", {param: param})
       }

       // Handle IPC responses to update properties
       Connections {
           target: IPCClient
           function onResponse(method, data) {
               if (method === "newsystem.status") {
                   currentValue = data.value
               }
           }
       }
   }
   ```

2. **Use in modules**:
   ```qml
   property alias serviceValue: NewService.currentValue

   SomeControl {
       visible: NewService.featureAvailable
       enabled: NewService.featureAvailable
       onTriggered: NewService.performAction(value)
   }
   ```

### Creating Plugins

Plugins are external, dynamically-loaded components that extend DankMaterialShell functionality. Plugins are stored in `~/.config/DankMaterialShell/plugins/` and have their settings isolated from core DMS settings.

**Plugin Types:**
- **Widget plugins** (`"type": "widget"` or omit type field): Display UI components in DankBar
- **Daemon plugins** (`"type": "daemon"`): Run invisibly in the background without UI

#### Widget Plugins

1. **Create plugin directory**:
   ```bash
   mkdir -p ~/.config/DankMaterialShell/plugins/YourPlugin
   ```

2. **Create manifest** (`plugin.json`):
   ```json
   {
       "id": "yourPlugin",
       "name": "Your Plugin",
       "description": "Widget description",
       "version": "1.0.0",
       "author": "Your Name",
       "icon": "extension",
       "type": "widget",
       "component": "./YourWidget.qml",
       "settings": "./YourSettings.qml",
       "permissions": ["settings_read", "settings_write"]
   }
   ```

3. **Create widget component** (`YourWidget.qml`):
   ```qml
   import QtQuick
   import qs.Services

   Rectangle {
       id: root

       property bool compactMode: false
       property string section: "center"
       property real widgetHeight: 30
       property var pluginService: null

       width: content.implicitWidth + 16
       height: widgetHeight
       radius: 8
       color: "#20FFFFFF"

       Component.onCompleted: {
           if (pluginService) {
               var data = pluginService.loadPluginData("yourPlugin", "key", defaultValue)
           }
       }
   }
   ```

4. **Create settings component** (`YourSettings.qml`):
   ```qml
   import QtQuick
   import QtQuick.Controls

   FocusScope {
       id: root

       property var pluginService: null

       implicitHeight: settingsColumn.implicitHeight
       height: implicitHeight

       Column {
           id: settingsColumn
           anchors.fill: parent
           anchors.margins: 16
           spacing: 12

           Text {
               text: "Your Plugin Settings"
               font.pixelSize: 18
               font.weight: Font.Bold
           }

           // Your settings UI here
       }

       function saveSettings(key, value) {
           if (pluginService) {
               pluginService.savePluginData("yourPlugin", key, value)
           }
       }

       function loadSettings(key, defaultValue) {
           if (pluginService) {
               return pluginService.loadPluginData("yourPlugin", key, defaultValue)
           }
           return defaultValue
       }
   }
   ```

5. **Enable plugin**:
   - Open Settings → Plugins
   - Click "Scan for Plugins"
   - Toggle plugin to enable
   - Add plugin ID to DankBar widget list

#### Daemon Plugins

Daemon plugins run invisibly in the background without any UI components. They're useful for monitoring system events, background tasks, or data synchronization.

1. **Create plugin directory**:
   ```bash
   mkdir -p ~/.config/DankMaterialShell/plugins/YourDaemon
   ```

2. **Create manifest** (`plugin.json`):
   ```json
   {
       "id": "yourDaemon",
       "name": "Your Daemon",
       "description": "Background daemon description",
       "version": "1.0.0",
       "author": "Your Name",
       "icon": "settings_applications",
       "type": "daemon",
       "component": "./YourDaemon.qml",
       "permissions": ["settings_read", "settings_write"]
   }
   ```

3. **Create daemon component** (`YourDaemon.qml`):
   ```qml
   import QtQuick
   import qs.Common
   import qs.Services

   Item {
       id: root

       property var pluginService: null

       Connections {
           target: SessionData
           function onWallpaperPathChanged() {
               console.log("Wallpaper changed:", SessionData.wallpaperPath)
               if (pluginService) {
                   pluginService.savePluginData("yourDaemon", "lastEvent", Date.now())
               }
           }
       }

       Component.onCompleted: {
           console.log("Daemon started")
       }
   }
   ```

4. **Enable daemon**:
   - Open Settings → Plugins
   - Click "Scan for Plugins"
   - Toggle daemon to enable
   - Daemon runs automatically in background

**Example**: See `PLUGINS/WallpaperWatcherDaemon/` for a complete daemon plugin that monitors wallpaper changes

**Plugin Directory Structure:**
```
~/.config/DankMaterialShell/
├── settings.json                    # Core DMS settings + plugin settings
│   └── pluginSettings: {
│       └── yourPlugin: {
│           ├── enabled: true,
│           └── customData: {...}
│       }
│   }
└── plugins/                         # Plugin files directory
    └── YourPlugin/                  # Plugin directory (matches manifest ID)
        ├── plugin.json              # Plugin manifest
        ├── YourWidget.qml           # Widget component
        └── YourSettings.qml         # Settings UI (optional)
```

**Key Plugin APIs:**
- `pluginService.loadPluginData(pluginId, key, default)` - Load persistent data
- `pluginService.savePluginData(pluginId, key, value)` - Save persistent data
- `PluginService.enablePlugin(pluginId)` - Load plugin
- `PluginService.disablePlugin(pluginId)` - Unload plugin

**Important Notes:**
- Plugin settings are automatically injected by the PluginService via `item.pluginService = PluginService`
- Settings are stored in the main settings.json but namespaced under `pluginSettings.{pluginId}`
- Plugin directories must match the plugin ID in the manifest
- Use the injected `pluginService` property in both widget and settings components

### Debugging Common Issues

#### QML Frontend Issues

1. **Import errors**: Check import paths in qmldir files
2. **Singleton conflicts**: Ensure services use `Singleton` type with `id: root`
3. **Property binding issues**: Use property aliases for reactive updates
4. **Theme inconsistencies**: Always use `Theme.propertyName` instead of hardcoded values
5. **IPC communication failures**: Check if `dms run` backend is running

#### Go Backend Issues

1. **IPC not responding**:
   - Check if socket exists: `ls -la /tmp/dms-ipc-$(id -u).sock`
   - Test with CLI: `dms ipc test.ping`
   - Check logs: `journalctl --user -u dms.service -f`

2. **D-Bus errors**:
   - Verify service availability: `busctl --user list | grep org.bluez`
   - Test D-Bus call: `busctl --user introspect org.bluez /`
   - Check permissions: User must be in required groups (video, input, etc.)

3. **Wayland protocol errors**:
   - Check compositor support: Different compositors support different protocols
   - Use `dms features` to see available features
   - Enable debug output: `WAYLAND_DEBUG=1 dms run`

4. **Build failures**:
   - Update Go: Requires Go 1.24+
   - Clean build: `cd core && make clean && make`
   - Check dependencies: `go mod download`

5. **Process failures**:
   - Check system tool availability: `which <tool>`
   - Verify PATH: `echo $PATH`
   - Check command syntax in logs

### Best Practices Summary

#### General
- **Code Reuse**: ALWAYS search existing codebase before writing new functions - avoid duplication at all costs
- **No Comments**: Code should be self-documenting - comments indicate poor naming/structure (applies to both QML and Go)
- **Modularity**: Keep components focused and independent
- **Testing**: Write tests for Go backend, test QML changes with live reload

#### QML Frontend
- **Reusability**: Create reusable components for common patterns using Widgets/
- **Responsiveness**: Use property bindings for reactive UI
- **Consistency**: Follow Material Design 3 principles via Theme singleton
- **Performance**: Minimize expensive operations and use appropriate data structures
- **Icon Management**: Use `DankIcon` for all icons instead of manual Text components
- **Widget System**: Leverage existing widgets (DankSlider, DankToggle, etc.) for consistency
- **NO WRAPPER HELL**: Avoid creating unnecessary wrapper functions - bind directly to underlying APIs for better reactivity and performance
- **Modern QML Patterns**: Leverage new widgets like DankTextField, DankDropdown, CachingImage
- **Structured Organization**: Follow the established Services/Modules/Widgets/Modals separation

#### Go Backend
- **System Integration First**: Implement backend functionality before QML wrappers
- **Error Handling**: Always wrap errors with context using `fmt.Errorf` with `%w`
- **IPC Pattern**: Follow established IPC handler patterns for consistency
- **Feature Detection**: Check for system capabilities and fail gracefully
- **Robustness**: Implement feature detection and graceful degradation
- **D-Bus Best Practices**: Use contexts, check service availability, handle signals properly
- **Wayland Best Practices**: Clean up resources, check protocol availability
- **Testing**: Write table-driven tests, use mocks for external dependencies

#### Architecture
- **Separation of Concerns**: UI (QML) vs system integration (Go)
- **Thin QML Wrappers**: Services should only handle IPC communication, not business logic
- **Backend-First Development**: Implement and test backend via CLI before adding UI
- **Function Discovery**: Use grep/search tools to find existing utility functions before implementing new ones
- **Plugin System**: For user extensions, create plugins instead of modifying core modules

### Common Widget Patterns

1. **Icons**: Always use `DankIcon { name: "icon_name" }` instead of `Text { font.family: Theme.iconFont }`
2. **Sliders**: Use `DankSlider` for consistent styling and behavior
3. **Toggles**: Use `DankToggle` for switches and checkboxes
4. **Tab Bars**: Use `DankTabBar` for tabbed interfaces
5. **Lists**: Use `DankListView` for scrollable lists
6. **Grids**: Use `DankGridView` for grid layouts
7. **Text Fields**: Use `DankTextField` for text input with validation
8. **Dropdowns**: Use `DankDropdown` for selection menus
9. **Popouts**: Use `DankPopout` as base for overlay components
10. **Images**: Use `CachingImage` for optimized image loading

### Essential Utility Functions

Before writing new utility functions, check these existing ones:

**Theme.qml utilities:**
- `getBatteryIcon(level, isCharging, batteryAvailable)` - Battery status icons
- `getPowerProfileIcon(profile)` - Power profile indicators

**Service utilities:**
- `BluetoothService.getDeviceIcon(device)` - Bluetooth device type icons
- `BluetoothService.getSignalIcon(device)` - Signal strength indicators
- `WeatherService.getWeatherIcon(code)` - Weather condition icons
- `AppSearchService.getCategoryIcon(category)` - Application category icons
- `DgopService.getProcessIcon(command)` - Process type icons
- `SettingsData.getWorkspaceNameIcon(workspaceName)` - Workspace icons

**Always search for existing functions using:**
```bash
grep -r "function.*get.*Icon" Services/ Common/
grep -r "function.*" path/to/relevant/directory/
```
