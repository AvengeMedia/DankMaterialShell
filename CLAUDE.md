# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Quickshell-based desktop shell implementation with Material Design 3 dark theme. The shell provides a complete desktop environment experience with panels, widgets, and system integration services.

## Technology Stack

- **QML (Qt Modeling Language)** - Primary language for all UI components
- **Quickshell Framework** - QML-based framework for building desktop shells
- **Qt/QtQuick** - UI rendering and controls
- **Qt5Compat** - Graphical effects
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

### Component Organization

1. **Shell Entry Point** (root directory)
   - `shell.qml` - Main shell implementation with multi-monitor support

2. **Widgets/** - Reusable UI components
   - Each widget is a self-contained QML module with its own `qmldir`
   - Examples: TopBar, ClockWidget, SystemTrayWidget, NotificationWidget
   - Components follow Material Design 3 principles

3. **Services/** - Backend services and controllers
   - `MprisController.qml` - Media player integration
   - `OSDetectionService.qml` - Operating system detection
   - `WeatherService.qml` - Weather data fetching
   - Services handle system integration and data management

### Key Architectural Patterns

1. **Module System**: Each component directory contains a `qmldir` file defining the module exports
2. **Property Bindings**: Heavy use of Qt property bindings for reactive UI updates
3. **Singleton Services**: Services are typically instantiated once and shared across components
4. **Material Design Theming**: Consistent use of Material Design 3 color properties throughout

### Important Components

- **ControlCenter**: Central hub for system controls (WiFi, Bluetooth, brightness, volume)
- **ApplicationLauncher**: App grid and search functionality
- **NotificationSystem**: Notification display and management
- **ClipboardHistory**: Clipboard manager with history
- **WorkspaceSwitcher**: Per-display virtual desktop switching with Niri integration

## Code Conventions

1. **QML Style**:
   - Use 4-space indentation
   - Properties before signal handlers
   - ID should be the first property
   - Prefer property bindings over imperative code

2. **Component Structure**:
   ```qml
   Item {
       id: root
       
       // Properties
       property type name: value
       
       // Signal handlers
       onSignal: { }
       
       // Child components
       Component { }
   }
   ```

3. **Service Integration**: Components should communicate with services through properties and signals rather than direct method calls

## Multi-Monitor Support

The shell uses Quickshell's `Variants` pattern for multi-monitor support:
- Each connected monitor gets its own top bar instance
- Workspace switchers are per-display and Niri-aware
- Monitors are automatically detected by screen name (DP-1, DP-2, etc.)
- Workspaces are dynamically synchronized with Niri's per-output workspaces

## Common Tasks

When modifying the shell:
1. Test changes with `qs -p .`
2. Check that animations remain smooth (60 FPS target)
3. Ensure Material Design 3 color consistency
4. Test on Wayland session
5. Verify multi-monitor behavior if applicable

When adding new widgets:
1. Create directory under `Widgets/`
2. Add `qmldir` file with module definition
3. Follow existing widget patterns for property exposure
4. Integrate with relevant services as needed
5. Consider whether the widget should be per-screen or global