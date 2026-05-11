# PopoutService Reference

The `PopoutService` singleton lets plugins control all DMS popouts and modals. It is automatically injected into widget, daemon, and settings components.

## Setup

Declare the property in your component for injection to work:

```qml
property var popoutService: null
```

Without this declaration, injection fails with: `Cannot assign to non-existent property "popoutService"`

## Popouts (DankPopout-based)

| Component | Open | Close | Toggle |
|-----------|------|-------|--------|
| Control Center | `openControlCenter()` | `closeControlCenter()` | `toggleControlCenter()` |
| Notification Center | `openNotificationCenter()` | `closeNotificationCenter()` | `toggleNotificationCenter()` |
| App Drawer | `openAppDrawer()` | `closeAppDrawer()` | `toggleAppDrawer()` |
| Process List | `openProcessList()` | `closeProcessList()` | `toggleProcessList()` |
| DankDash | `openDankDash(tab)` | `closeDankDash()` | `toggleDankDash(tab)` |
| Battery | `openBattery()` | `closeBattery()` | `toggleBattery()` |
| VPN | `openVpn()` | `closeVpn()` | `toggleVpn()` |
| System Update | `openSystemUpdate()` | `closeSystemUpdate()` | `toggleSystemUpdate()` |

## Modals (DankModal-based)

| Modal | Show | Hide | Notes |
|-------|------|------|-------|
| Settings | `openSettings()` | `closeSettings()` | Full settings interface |
| Clipboard History | `openClipboardHistory()` | `closeClipboardHistory()` | Clipboard integration |
| Launcher | `openDankLauncherV2()` | `closeDankLauncherV2()` | Also has `toggleDankLauncherV2()` |
| Power Menu | `openPowerMenu()` | `closePowerMenu()` | Also has `togglePowerMenu()` |
| Process List Modal | `showProcessListModal()` | `hideProcessListModal()` | Has `toggleProcessListModal()` |
| Color Picker | `showColorPicker()` | `hideColorPicker()` | Theme color selection |
| Notification | `showNotificationModal()` | `hideNotificationModal()` | Notification details |
| WiFi Password | `showWifiPasswordModal()` | `hideWifiPasswordModal()` | Network auth |
| Network Info | `showNetworkInfoModal()` | `hideNetworkInfoModal()` | Network details |

## Slideouts

| Component | Open | Close | Toggle |
|-----------|------|-------|--------|
| Notepad | `openNotepad()` | `closeNotepad()` | `toggleNotepad()` |

## Usage Examples

### Simple toggle

```qml
MouseArea {
    onClicked: popoutService?.toggleControlCenter()
}
```

### Conditional popout

```qml
Connections {
    target: BatteryService
    function onPercentageChanged() {
        if (BatteryService.percentage < 10 && !BatteryService.isCharging) {
            popoutService?.openBattery()
        }
    }
}
```

### Context menu with multiple actions

```qml
MouseArea {
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) contextMenu.popup()
        else popoutService?.toggleControlCenter()
    }
}

Menu {
    id: contextMenu
    MenuItem { text: "Settings"; onClicked: popoutService?.openSettings() }
    MenuItem { text: "Notifications"; onClicked: popoutService?.toggleNotificationCenter() }
    MenuItem { text: "Power"; onClicked: popoutService?.openPowerMenu() }
}
```

### Position-aware toggle (from bar pill)

Some toggle functions accept position parameters for proper popout placement:

```qml
pillClickAction: (x, y, width, section, screen) => {
    popoutService?.toggleControlCenter(x, y, width, section, screen)
}
```

## Best Practices

1. **Always use optional chaining** (`?.`) - the service may not be injected yet
2. **Check feature availability** before opening feature-specific popouts:
   ```qml
   if (BatteryService.batteryAvailable) {
       popoutService?.openBattery()
   }
   ```
3. **Lazy loading** - first access may activate lazy loaders; this is normal
4. **Popouts are shared** - avoid opening conflicting popouts simultaneously
5. **User intent** - only trigger popouts from user actions or critical system events
6. **Multi-monitor** - positioned popouts are screen-aware when using position parameters

## Injection Locations

The service is injected at these points:
- `DMSShell.qml` - daemon plugins
- `WidgetHost.qml` - widget plugins in left/right bar sections
- `CenterSection.qml` - center bar widgets
- `PluginsTab.qml` - settings components
