# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Quickshell-based desktop shell implementation with Material Design 3 dark theme. The shell provides a complete desktop environment experience with panels, widgets, and system integration services.

**Architecture**: Modular design with clean separation between UI components (Widgets), system services (Services), and shared utilities (Common).

## Technology Stack

- **QML (Qt Modeling Language)** - Primary language for all UI components
- **Quickshell Framework** - QML-based framework for building desktop shells
- **Qt/QtQuick** - UI rendering and controls
- **Wayland** - Display server protocol

## Development Commands

Since this is a Quickshell-based project without traditional build configuration files, development typically involves:

```bash
# Run the shell (requires Quickshell to be installed)
quickshell -p shell.qml

# Or use the shorthand
qs -p .
```

## Architecture Overview

### Modular Structure

The shell follows a clean modular architecture reduced from 4,830 lines to ~250 lines in shell.qml:

```
shell.qml           # Main entry point (minimal orchestration)
├── Common/         # Shared resources
│   ├── Theme.qml   # Material Design 3 theme singleton
│   └── Utilities.js # Shared utility functions
├── Services/       # System integration singletons
│   ├── AudioService.qml
│   ├── NetworkService.qml
│   ├── BrightnessService.qml
│   └── [9 total services]
└── Widgets/        # UI components
    ├── TopBar.qml
    ├── AppLauncher.qml
    ├── ControlCenterPopup.qml
    └── [18 total widgets]
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

3. **Services/** - System integration singletons
   - **Pattern**: All services use `Singleton` type with `id: root`
   - **Independence**: No cross-service dependencies
   - **Examples**: AudioService, NetworkService, BrightnessService, WeatherService
   - Services handle system commands, state management, and hardware integration

4. **Widgets/** - Reusable UI components
   - **Full-screen components**: AppLauncher, ClipboardHistory, ControlCenterPopup
   - **Panel components**: TopBar, SystemTrayWidget, NotificationPopup
   - **Reusable controls**: CustomSlider, WorkspaceSwitcher
   - Each widget directory contains `qmldir` for module registration

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

2. **Module Registration**: Each directory contains `qmldir` file:
   ```
   singleton ServiceName 1.0 ServiceName.qml
   ComponentName 1.0 ComponentName.qml
   ```

3. **Smart Feature Detection**: Services detect system capabilities:
   ```qml
   property bool featureAvailable: false
   // Auto-hide UI elements when features unavailable
   visible: ServiceName.featureAvailable
   ```

4. **Property Bindings**: Reactive UI updates through property binding
5. **Material Design Theming**: Consistent use of Theme singleton throughout

### Important Components

- **ControlCenterPopup**: System controls (WiFi, Bluetooth, brightness, volume, night mode)
- **AppLauncher**: Full-featured app grid/list with 93+ applications, search, categories
- **ClipboardHistory**: Complete clipboard management with cliphist integration
- **TopBar**: Per-monitor panels with workspace switching, clock, system tray
- **CustomSlider**: Reusable enhanced slider with animations and smart detection

## Code Conventions

### QML Style Guidelines

1. **Structure and Formatting**:
   - Use 4-space indentation
   - `id` should be the first property
   - Properties before signal handlers before child components
   - Prefer property bindings over imperative code

2. **Naming Conventions**:
   - **Services**: Use `Singleton` type with `id: root`
   - **Components**: Use descriptive names (e.g., `CustomSlider`, `TopBar`)
   - **Properties**: camelCase for properties, PascalCase for types

3. **Component Structure**:
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

1. **Standard Import Order**:
   ```qml
   import QtQuick
   import QtQuick.Controls  // If needed
   import Quickshell
   import Quickshell.Widgets
   import Quickshell.Io     // For Process, FileView
   import "../Common"       // For Theme, utilities
   import "../Services"     // For service access
   ```

2. **Service Dependencies**:
   - Services should NOT import other services
   - Widgets can import and use services via property bindings
   - Use `Theme.propertyName` for consistent styling

### Component Development Patterns

1. **Smart Feature Detection**:
   ```qml
   // In services - detect capabilities
   property bool brightnessAvailable: false
   
   // In widgets - adapt UI accordingly
   CustomSlider {
       visible: BrightnessService.brightnessAvailable
       enabled: BrightnessService.brightnessAvailable
       value: BrightnessService.brightnessLevel
   }
   ```

2. **Reusable Components**:
   - Create reusable widgets for common patterns (like CustomSlider)
   - Use configurable properties for different use cases
   - Include proper signal handling with unique names (avoid `valueChanged`)

3. **Service Integration**:
   - Services expose properties and functions
   - Widgets bind to service properties for reactive updates
   - Use service functions for actions: `ServiceName.performAction(value)`

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
- Workspace switchers are per-display and Niri-aware
- Monitors are automatically detected by screen name (DP-1, DP-2, etc.)
- Workspaces are dynamically synchronized with Niri's per-output workspaces

## Common Development Tasks

### Testing and Validation

When modifying the shell:
1. **Test changes**: `qs -p .` (automatic reload on file changes)
2. **Performance**: Ensure animations remain smooth (60 FPS target)
3. **Theming**: Use `Theme.propertyName` for Material Design 3 consistency
4. **Wayland compatibility**: Test on Wayland session
5. **Multi-monitor**: Verify behavior with multiple displays
6. **Feature detection**: Test on systems with/without required tools

### Adding New Widgets

1. **Create component**:
   ```bash
   # Create new widget file
   touch Widgets/NewWidget.qml
   ```

2. **Register in qmldir**:
   ```
   # Add to Widgets/qmldir
   NewWidget 1.0 NewWidget.qml
   ```

3. **Follow widget patterns**:
   - Use `Theme.propertyName` for styling
   - Import `"../Common"` and `"../Services"` as needed
   - Bind to service properties for reactive updates
   - Consider per-screen vs global behavior

4. **Integration in shell.qml**:
   ```qml
   NewWidget {
       id: newWidget
       // Configure properties
   }
   ```

### Adding New Services

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
           // Implementation
       }
   }
   ```

2. **Register in qmldir**:
   ```
   # Add to Services/qmldir
   singleton NewService 1.0 NewService.qml
   ```

3. **Use in widgets**:
   ```qml
   // In widget files
   property alias serviceValue: NewService.currentValue
   
   SomeControl {
       visible: NewService.featureAvailable
       enabled: NewService.featureAvailable
       onTriggered: NewService.performAction(value)
   }
   ```

### Debugging Common Issues

1. **Import errors**: Check `qmldir` registration and import paths
2. **Singleton conflicts**: Ensure services use `Singleton` type with `id: root`
3. **Property binding issues**: Use property aliases for reactive updates
4. **Process failures**: Check system tool availability and command syntax
5. **Theme inconsistencies**: Always use `Theme.propertyName` instead of hardcoded values

### Best Practices Summary

- **Modularity**: Keep components focused and independent
- **Reusability**: Create reusable components for common patterns
- **Responsiveness**: Use property bindings for reactive UI
- **Robustness**: Implement feature detection and graceful degradation
- **Consistency**: Follow Material Design 3 principles via Theme singleton
- **Performance**: Minimize expensive operations and use appropriate data structures