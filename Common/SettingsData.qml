pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Common.settings
import qs.Services
import "settings/SettingsSpec.js" as Spec
import "settings/SettingsStore.js" as Store

Singleton {
    id: root

    readonly property int settingsConfigVersion: 1

    readonly property bool isGreeterMode: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"

    enum Position {
        Top,
        Bottom,
        Left,
        Right
    }

    enum AnimationSpeed {
        None,
        Short,
        Medium,
        Long,
        Custom
    }

    enum SuspendBehavior {
        Suspend,
        Hibernate,
        SuspendThenHibernate
    }

    readonly property string defaultFontFamily: "Inter Variable"
    readonly property string defaultMonoFontFamily: "Fira Code"
    readonly property string _homeUrl: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string _configUrl: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string _configDir: Paths.strip(_configUrl)
    readonly property string pluginSettingsPath: _configDir + "/DankMaterialShell/plugin_settings.json"

    property bool _loading: false
    property bool _pluginSettingsLoading: false
    property bool hasTriedDefaultSettings: false
    property var pluginSettings: ({})

    property alias dankBarLeftWidgetsModel: leftWidgetsModel
    property alias dankBarCenterWidgetsModel: centerWidgetsModel
    property alias dankBarRightWidgetsModel: rightWidgetsModel

    property string currentThemeName: "blue"
    property string customThemeFile: ""
    property string matugenScheme: "scheme-tonal-spot"
    property bool runUserMatugenTemplates: true
    property string matugenTargetMonitor: ""
    property real dankBarTransparency: 1.0
    property real dankBarWidgetTransparency: 1.0
    property real popupTransparency: 1.0
    property real dockTransparency: 1
    property string widgetBackgroundColor: "sch"
    property string surfaceBase: "s"
    property real cornerRadius: 12

    property bool use24HourClock: true
    property bool showSeconds: false
    property bool useFahrenheit: false
    property bool nightModeEnabled: false
    property int animationSpeed: SettingsData.AnimationSpeed.Short
    property int customAnimationDuration: 500
    property string wallpaperFillMode: "Fill"
    property bool blurredWallpaperLayer: false
    property bool blurWallpaperOnOverview: false

    property bool showLauncherButton: true
    property bool showWorkspaceSwitcher: true
    property bool showFocusedWindow: true
    property bool showWeather: true
    property bool showMusic: true
    property bool showClipboard: true
    property bool showCpuUsage: true
    property bool showMemUsage: true
    property bool showCpuTemp: true
    property bool showGpuTemp: true
    property int selectedGpuIndex: 0
    property var enabledGpuPciIds: []
    property bool showSystemTray: true
    property bool showClock: true
    property bool showNotificationButton: true
    property bool showBattery: true
    property bool showControlCenterButton: true

    property bool controlCenterShowNetworkIcon: true
    property bool controlCenterShowBluetoothIcon: true
    property bool controlCenterShowAudioIcon: true
    property var controlCenterWidgets: [{
            "id": "volumeSlider",
            "enabled": true,
            "width": 50
        }, {
            "id": "brightnessSlider",
            "enabled": true,
            "width": 50
        }, {
            "id": "wifi",
            "enabled": true,
            "width": 50
        }, {
            "id": "bluetooth",
            "enabled": true,
            "width": 50
        }, {
            "id": "audioOutput",
            "enabled": true,
            "width": 50
        }, {
            "id": "audioInput",
            "enabled": true,
            "width": 50
        }, {
            "id": "nightMode",
            "enabled": true,
            "width": 50
        }, {
            "id": "darkMode",
            "enabled": true,
            "width": 50
        }]

    property bool showWorkspaceIndex: false
    property bool showWorkspacePadding: false
    property bool workspaceScrolling: false
    property bool showWorkspaceApps: false
    property int maxWorkspaceIcons: 3
    property bool workspacesPerMonitor: true
    property bool dwlShowAllTags: false
    property var workspaceNameIcons: ({})
    property bool waveProgressEnabled: true
    property bool clockCompactMode: false
    property bool focusedWindowCompactMode: false
    property bool runningAppsCompactMode: true
    property bool keyboardLayoutNameCompactMode: false
    property bool runningAppsCurrentWorkspace: false
    property bool runningAppsGroupByApp: false
    property string clockDateFormat: ""
    property string lockDateFormat: ""
    property int mediaSize: 1

    property var dankBarLeftWidgets: ["launcherButton", "workspaceSwitcher", "focusedWindow"]
    property var dankBarCenterWidgets: ["music", "clock", "weather"]
    property var dankBarRightWidgets: ["systemTray", "clipboard", "cpuUsage", "memUsage", "notificationButton", "battery", "controlCenterButton"]
    property var dankBarWidgetOrder: []

    property string appLauncherViewMode: "list"
    property string spotlightModalViewMode: "list"
    property bool sortAppsAlphabetically: false

    property string weatherLocation: "New York, NY"
    property string weatherCoordinates: "40.7128,-74.0060"
    property bool useAutoLocation: false
    property bool weatherEnabled: true

    property string networkPreference: "auto"
    property string vpnLastConnected: ""

    property string iconTheme: "System Default"
    property var availableIconThemes: ["System Default"]
    property string systemDefaultIconTheme: ""
    property bool qt5ctAvailable: false
    property bool qt6ctAvailable: false
    property bool gtkAvailable: false

    property string launcherLogoMode: "apps"
    property string launcherLogoCustomPath: ""
    property string launcherLogoColorOverride: ""
    property bool launcherLogoColorInvertOnMode: false
    property real launcherLogoBrightness: 0.5
    property real launcherLogoContrast: 1
    property int launcherLogoSizeOffset: 0

    property string fontFamily: "Inter Variable"
    property string monoFontFamily: "Fira Code"
    property int fontWeight: Font.Normal
    property real fontScale: 1.0
    property real dankBarFontScale: 1.0

    property bool notepadUseMonospace: true
    property string notepadFontFamily: ""
    property real notepadFontSize: 14
    property bool notepadShowLineNumbers: false
    property real notepadTransparencyOverride: -1
    property real notepadLastCustomTransparency: 0.7

    onNotepadUseMonospaceChanged: saveSettings()
    onNotepadFontFamilyChanged: saveSettings()
    onNotepadFontSizeChanged: saveSettings()
    onNotepadShowLineNumbersChanged: saveSettings()
    onNotepadTransparencyOverrideChanged: {
        if (notepadTransparencyOverride > 0) {
            notepadLastCustomTransparency = notepadTransparencyOverride
        }
        saveSettings()
    }
    onNotepadLastCustomTransparencyChanged: saveSettings()

    property bool soundsEnabled: true
    property bool useSystemSoundTheme: false
    property bool soundNewNotification: true
    property bool soundVolumeChanged: true
    property bool soundPluggedIn: true

    property int acMonitorTimeout: 0
    property int acLockTimeout: 0
    property int acSuspendTimeout: 0
    property int acSuspendBehavior: SettingsData.SuspendBehavior.Suspend
    property int batteryMonitorTimeout: 0
    property int batteryLockTimeout: 0
    property int batterySuspendTimeout: 0
    property int batterySuspendBehavior: SettingsData.SuspendBehavior.Suspend
    property bool lockBeforeSuspend: false
    property bool loginctlLockIntegration: true
    property string launchPrefix: ""
    property var brightnessDevicePins: ({})

    property bool gtkThemingEnabled: false
    property bool qtThemingEnabled: false
    property bool syncModeWithPortal: true

    property bool showDock: false
    property bool dockAutoHide: false
    property bool dockGroupByApp: false
    property bool dockOpenOnOverview: false
    property int dockPosition: SettingsData.Position.Bottom
    property real dockSpacing: 4
    property real dockBottomGap: 0
    property real dockIconSize: 40
    property string dockIndicatorStyle: "circle"

    property bool notificationOverlayEnabled: false
    property bool dankBarAutoHide: false
    property bool dankBarOpenOnOverview: false
    property bool dankBarVisible: true
    property int overviewRows: 2
    property int overviewColumns: 5
    property real overviewScale: 0.16
    property real dankBarSpacing: 4
    property real dankBarBottomGap: 0
    property real dankBarInnerPadding: 4
    property int dankBarPosition: SettingsData.Position.Top
    property bool dankBarIsVertical: dankBarPosition === SettingsData.Position.Left || dankBarPosition === SettingsData.Position.Right

    property bool dankBarSquareCorners: false
    property bool dankBarNoBackground: false
    property bool dankBarGothCornersEnabled: false
    property bool dankBarBorderEnabled: false
    property string dankBarBorderColor: "surfaceText"
    property real dankBarBorderOpacity: 1.0
    property real dankBarBorderThickness: 1

    onDankBarBorderColorChanged: saveSettings()
    onDankBarBorderOpacityChanged: saveSettings()
    onDankBarBorderThicknessChanged: saveSettings()

    property bool popupGapsAuto: true
    property int popupGapsManual: 4

    property bool modalDarkenBackground: true

    property bool lockScreenShowPowerActions: true
    property bool enableFprint: false
    property int maxFprintTries: 3
    property bool fprintdAvailable: false
    property bool hideBrightnessSlider: false

    property int notificationTimeoutLow: 5000
    property int notificationTimeoutNormal: 5000
    property int notificationTimeoutCritical: 0
    property int notificationPopupPosition: SettingsData.Position.Top

    property bool osdAlwaysShowValue: false

    property bool powerActionConfirm: true
    property string customPowerActionLock: ""
    property string customPowerActionLogout: ""
    property string customPowerActionSuspend: ""
    property string customPowerActionHibernate: ""
    property string customPowerActionReboot: ""
    property string customPowerActionPowerOff: ""

    property bool updaterUseCustomCommand: false
    property string updaterCustomCommand: ""
    property string updaterTerminalAdditionalParams: ""

    property var screenPreferences: ({})
    property var showOnLastDisplay: ({})

    signal forceDankBarLayoutRefresh
    signal forceDockLayoutRefresh
    signal widgetDataChanged
    signal workspaceIconsUpdated

    Component.onCompleted: {
        if (!isGreeterMode) {
            Processes.settingsRoot = root
            loadSettings()
            initializeListModels()
            Processes.detectFprintd()
            Processes.checkPluginSettings()
        }
    }

    function applyStoredTheme() {
        if (typeof Theme !== "undefined") {
            Theme.switchTheme(currentThemeName, false, false)
        } else {
            Qt.callLater(function() {
                if (typeof Theme !== "undefined") {
                    Theme.switchTheme(currentThemeName, false, false)
                }
            })
        }
    }

    function regenSystemThemes() {
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function updateNiriLayout() {
        if (typeof NiriService !== "undefined" && typeof CompositorService !== "undefined" && CompositorService.isNiri) {
            NiriService.generateNiriLayoutConfig()
        }
    }

    function applyStoredIconTheme() {
        updateGtkIconTheme()
        updateQtIconTheme()
    }

    function updateGtkIconTheme() {
        const gtkThemeName = (iconTheme === "System Default") ? systemDefaultIconTheme : iconTheme
        if (gtkThemeName === "System Default" || gtkThemeName === "") return

        if (typeof DMSService !== "undefined" && DMSService.apiVersion >= 3 && typeof PortalService !== "undefined") {
            PortalService.setSystemIconTheme(gtkThemeName)
        }

        const configScript = `mkdir -p ${_configDir}/gtk-3.0 ${_configDir}/gtk-4.0

for config_dir in ${_configDir}/gtk-3.0 ${_configDir}/gtk-4.0; do
    settings_file="$config_dir/settings.ini"
    if [ -f "$settings_file" ]; then
        if grep -q "^gtk-icon-theme-name=" "$settings_file"; then
            sed -i 's/^gtk-icon-theme-name=.*/gtk-icon-theme-name=${gtkThemeName}/' "$settings_file"
        else
            if grep -q "\\[Settings\\]" "$settings_file"; then
                sed -i '/\\[Settings\\]/a gtk-icon-theme-name=${gtkThemeName}' "$settings_file"
            else
                echo -e '\\n[Settings]\\ngtk-icon-theme-name=${gtkThemeName}' >> "$settings_file"
            fi
        fi
    else
        echo -e '[Settings]\\ngtk-icon-theme-name=${gtkThemeName}' > "$settings_file"
    fi
done

rm -rf ~/.cache/icon-cache ~/.cache/thumbnails 2>/dev/null || true
pkill -HUP -f 'gtk' 2>/dev/null || true`

        Quickshell.execDetached(["sh", "-lc", configScript])
    }

    function updateQtIconTheme() {
        const qtThemeName = (iconTheme === "System Default") ? "" : iconTheme
        if (!qtThemeName) return

        const home = _homeUrl.replace("file://", "").replace(/'/g, "'\\''")
        const qtThemeNameEscaped = qtThemeName.replace(/'/g, "'\\''")

        const script = `mkdir -p ${_configDir}/qt5ct ${_configDir}/qt6ct ${_configDir}/environment.d 2>/dev/null || true
update_qt_icon_theme() {
  local config_file="$1"
  local theme_name="$2"
  if [ -f "$config_file" ]; then
    if grep -q "^\\[Appearance\\]" "$config_file"; then
      if grep -q "^icon_theme=" "$config_file"; then
        sed -i "s/^icon_theme=.*/icon_theme=$theme_name/" "$config_file"
      else
        sed -i "/^\\[Appearance\\]/a icon_theme=$theme_name" "$config_file"
      fi
    else
      printf "\\n[Appearance]\\nicon_theme=%s\\n" "$theme_name" >> "$config_file"
    fi
  else
    printf "[Appearance]\\nicon_theme=%s\\n" "$theme_name" > "$config_file"
  fi
}
update_qt_icon_theme ${_configDir}/qt5ct/qt5ct.conf '${qtThemeNameEscaped}'
update_qt_icon_theme ${_configDir}/qt6ct/qt6ct.conf '${qtThemeNameEscaped}'
rm -rf '${home}'/.cache/icon-cache '${home}'/.cache/thumbnails 2>/dev/null || true`

        Quickshell.execDetached(["sh", "-lc", script])
    }

    readonly property var _hooks: ({
        applyStoredTheme: applyStoredTheme,
        regenSystemThemes: regenSystemThemes,
        updateNiriLayout: updateNiriLayout,
        applyStoredIconTheme: applyStoredIconTheme
    })

    function set(key, value) {
        Spec.set(root, key, value, saveSettings, _hooks)
    }

    function loadSettings() {
        _loading = true
        try {
            const txt = settingsFile.text()
            const obj = (txt && txt.trim()) ? JSON.parse(txt) : null
            Store.parse(root, obj)
            const shouldMigrate = Store.migrate(root, obj)
            applyStoredTheme()
            applyStoredIconTheme()
            Processes.detectIcons()
            Processes.detectQtTools()
            if (obj && obj.configVersion === undefined) {
                const cleaned = Store.cleanup(txt)
                if (cleaned) {
                    settingsFile.setText(cleaned)
                }
                saveSettings()
            }
            if (shouldMigrate) {
                savePluginSettings()
                saveSettings()
            }
        } catch (e) {
            console.warn("SettingsData: Failed to load settings:", e.message)
            applyStoredTheme()
            applyStoredIconTheme()
        } finally {
            _loading = false
        }
        loadPluginSettings()
    }

    function loadPluginSettings() {
        _pluginSettingsLoading = true
        parsePluginSettings(pluginSettingsFile.text())
        _pluginSettingsLoading = false
    }

    function parsePluginSettings(content) {
        _pluginSettingsLoading = true
        try {
            if (content && content.trim()) {
                pluginSettings = JSON.parse(content)
            } else {
                pluginSettings = {}
            }
        } catch (e) {
            console.warn("SettingsData: Failed to parse plugin settings:", e.message)
            pluginSettings = {}
        } finally {
            _pluginSettingsLoading = false
        }
    }

    function saveSettings() {
        if (_loading) return
        settingsFile.setText(JSON.stringify(Store.toJson(root), null, 2))
    }

    function savePluginSettings() {
        if (_pluginSettingsLoading) return
        pluginSettingsFile.setText(JSON.stringify(pluginSettings, null, 2))
    }

    function detectAvailableIconThemes() {
        Processes.detectIcons()
    }

    function getEffectiveTimeFormat() {
        if (use24HourClock) {
            return showSeconds ? "hh:mm:ss" : "hh:mm"
        } else {
            return showSeconds ? "h:mm:ss AP" : "h:mm AP"
        }
    }

    function getEffectiveClockDateFormat() {
        return clockDateFormat && clockDateFormat.length > 0 ? clockDateFormat : "ddd d"
    }

    function getEffectiveLockDateFormat() {
        return lockDateFormat && lockDateFormat.length > 0 ? lockDateFormat : Locale.LongFormat
    }

    function initializeListModels() {
        Lists.init(leftWidgetsModel, centerWidgetsModel, rightWidgetsModel, dankBarLeftWidgets, dankBarCenterWidgets, dankBarRightWidgets)
    }

    function updateListModel(listModel, order) {
        Lists.update(listModel, order)
        widgetDataChanged()
    }

    function hasNamedWorkspaces() {
        if (typeof NiriService === "undefined" || !CompositorService.isNiri) return false

        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
            var ws = NiriService.allWorkspaces[i]
            if (ws.name && ws.name.trim() !== "") return true
        }
        return false
    }

    function getNamedWorkspaces() {
        var namedWorkspaces = []
        if (typeof NiriService === "undefined" || !CompositorService.isNiri) return namedWorkspaces

        for (const ws of NiriService.allWorkspaces) {
            if (ws.name && ws.name.trim() !== "") {
                namedWorkspaces.push(ws.name)
            }
        }
        return namedWorkspaces
    }

    function getPopupYPosition(barHeight) {
        const gothOffset = dankBarGothCornersEnabled ? Theme.cornerRadius : 0
        return barHeight + dankBarSpacing + dankBarBottomGap - gothOffset + Theme.popupDistance
    }

    function getPopupTriggerPosition(globalPos, screen, barThickness, widgetWidth) {
        const screenX = screen ? screen.x : 0
        const screenY = screen ? screen.y : 0
        const relativeX = globalPos.x - screenX
        const relativeY = globalPos.y - screenY

        if (dankBarPosition === SettingsData.Position.Left || dankBarPosition === SettingsData.Position.Right) {
            return {
                "x": relativeY,
                "y": barThickness + dankBarSpacing + Theme.popupDistance,
                "width": widgetWidth
            }
        }
        return {
            "x": relativeX,
            "y": barThickness + dankBarSpacing + Theme.popupDistance,
            "width": widgetWidth
        }
    }

    function getFilteredScreens(componentId) {
        var prefs = screenPreferences && screenPreferences[componentId] || ["all"]
        if (prefs.includes("all")) {
            return Quickshell.screens
        }
        var filtered = Quickshell.screens.filter(screen => prefs.includes(screen.name))
        if (filtered.length === 0 && showOnLastDisplay && showOnLastDisplay[componentId] && Quickshell.screens.length === 1) {
            return Quickshell.screens
        }
        return filtered
    }

    function sendTestNotifications() {
        sendTestNotification(0)
        testNotifTimer1.start()
        testNotifTimer2.start()
    }

    function sendTestNotification(index) {
        const notifications = [["Notification Position Test", "DMS test notification 1 of 3 ~ Hi there!", "preferences-system"], ["Second Test", "DMS Notification 2 of 3 ~ Check it out!", "applications-graphics"], ["Third Test", "DMS notification 3 of 3 ~ Enjoy!", "face-smile"]]

        if (index < 0 || index >= notifications.length) {
            return
        }

        const notif = notifications[index]
        testNotificationProcess.command = ["notify-send", "-h", "int:transient:1", "-a", "DMS", "-i", notif[2], notif[0], notif[1]]
        testNotificationProcess.running = true
    }


    function setMatugenScheme(scheme) {
        var normalized = scheme || "scheme-tonal-spot"
        if (matugenScheme === normalized) return
        set("matugenScheme", normalized)
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setRunUserMatugenTemplates(enabled) {
        if (runUserMatugenTemplates === enabled) return
        set("runUserMatugenTemplates", enabled)
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setMatugenTargetMonitor(monitorName) {
        if (matugenTargetMonitor === monitorName) return
        set("matugenTargetMonitor", monitorName)
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setSurfaceBase(base) {
        set("surfaceBase", base)
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setCornerRadius(radius) {
        set("cornerRadius", radius)
        NiriService.generateNiriLayoutConfig()
    }

    function setWeatherLocation(displayName, coordinates) {
        weatherLocation = displayName
        weatherCoordinates = coordinates
        saveSettings()
    }

    function setIconTheme(themeName) {
        iconTheme = themeName
        updateGtkIconTheme()
        updateQtIconTheme()
        saveSettings()
        if (typeof Theme !== "undefined" && Theme.currentTheme === Theme.dynamic) Theme.generateSystemThemesFromCurrentTheme()
    }

    function setGtkThemingEnabled(enabled) {
        set("gtkThemingEnabled", enabled)
        if (enabled && typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setQtThemingEnabled(enabled) {
        set("qtThemingEnabled", enabled)
        if (enabled && typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setShowDock(enabled) {
        showDock = enabled
        if (enabled && dockPosition === dankBarPosition) {
            if (dankBarPosition === SettingsData.Position.Top) {
                setDockPosition(SettingsData.Position.Bottom)
                return
            }
            if (dankBarPosition === SettingsData.Position.Bottom) {
                setDockPosition(SettingsData.Position.Top)
                return
            }
            if (dankBarPosition === SettingsData.Position.Left) {
                setDockPosition(SettingsData.Position.Right)
                return
            }
            if (dankBarPosition === SettingsData.Position.Right) {
                setDockPosition(SettingsData.Position.Left)
                return
            }
        }
        saveSettings()
    }

    function setDockPosition(position) {
        dockPosition = position
        if (position === SettingsData.Position.Bottom && dankBarPosition === SettingsData.Position.Bottom && showDock) {
            setDankBarPosition(SettingsData.Position.Top)
        }
        if (position === SettingsData.Position.Top && dankBarPosition === SettingsData.Position.Top && showDock) {
            setDankBarPosition(SettingsData.Position.Bottom)
        }
        if (position === SettingsData.Position.Left && dankBarPosition === SettingsData.Position.Left && showDock) {
            setDankBarPosition(SettingsData.Position.Right)
        }
        if (position === SettingsData.Position.Right && dankBarPosition === SettingsData.Position.Right && showDock) {
            setDankBarPosition(SettingsData.Position.Left)
        }
        saveSettings()
        Qt.callLater(() => forceDockLayoutRefresh())
    }

    function setDankBarSpacing(spacing) {
        set("dankBarSpacing", spacing)
        if (typeof NiriService !== "undefined" && CompositorService.isNiri) {
            NiriService.generateNiriLayoutConfig()
        }
    }

    function setDankBarPosition(position) {
        dankBarPosition = position
        if (position === SettingsData.Position.Bottom && dockPosition === SettingsData.Position.Bottom && showDock) {
            setDockPosition(SettingsData.Position.Top)
            return
        }
        if (position === SettingsData.Position.Top && dockPosition === SettingsData.Position.Top && showDock) {
            setDockPosition(SettingsData.Position.Bottom)
            return
        }
        if (position === SettingsData.Position.Left && dockPosition === SettingsData.Position.Left && showDock) {
            setDockPosition(SettingsData.Position.Right)
            return
        }
        if (position === SettingsData.Position.Right && dockPosition === SettingsData.Position.Right && showDock) {
            setDockPosition(SettingsData.Position.Left)
            return
        }
        saveSettings()
    }

    function setDankBarLeftWidgets(order) {
        dankBarLeftWidgets = order
        updateListModel(leftWidgetsModel, order)
        saveSettings()
    }

    function setDankBarCenterWidgets(order) {
        dankBarCenterWidgets = order
        updateListModel(centerWidgetsModel, order)
        saveSettings()
    }

    function setDankBarRightWidgets(order) {
        dankBarRightWidgets = order
        updateListModel(rightWidgetsModel, order)
        saveSettings()
    }

    function resetDankBarWidgetsToDefault() {
        var defaultLeft = ["launcherButton", "workspaceSwitcher", "focusedWindow"]
        var defaultCenter = ["music", "clock", "weather"]
        var defaultRight = ["systemTray", "clipboard", "notificationButton", "battery", "controlCenterButton"]
        dankBarLeftWidgets = defaultLeft
        dankBarCenterWidgets = defaultCenter
        dankBarRightWidgets = defaultRight
        updateListModel(leftWidgetsModel, defaultLeft)
        updateListModel(centerWidgetsModel, defaultCenter)
        updateListModel(rightWidgetsModel, defaultRight)
        showLauncherButton = true
        showWorkspaceSwitcher = true
        showFocusedWindow = true
        showWeather = true
        showMusic = true
        showClipboard = true
        showCpuUsage = true
        showMemUsage = true
        showCpuTemp = true
        showGpuTemp = true
        showSystemTray = true
        showClock = true
        showNotificationButton = true
        showBattery = true
        showControlCenterButton = true
        saveSettings()
    }

    function setWorkspaceNameIcon(workspaceName, iconData) {
        var iconMap = JSON.parse(JSON.stringify(workspaceNameIcons))
        iconMap[workspaceName] = iconData
        workspaceNameIcons = iconMap
        saveSettings()
        workspaceIconsUpdated()
    }

    function removeWorkspaceNameIcon(workspaceName) {
        var iconMap = JSON.parse(JSON.stringify(workspaceNameIcons))
        delete iconMap[workspaceName]
        workspaceNameIcons = iconMap
        saveSettings()
        workspaceIconsUpdated()
    }

    function getWorkspaceNameIcon(workspaceName) {
        return workspaceNameIcons[workspaceName] || null
    }

    function toggleDankBarVisible() {
        dankBarVisible = !dankBarVisible
        saveSettings()
    }

    function getPluginSetting(pluginId, key, defaultValue) {
        if (!pluginSettings[pluginId]) {
            return defaultValue
        }
        return pluginSettings[pluginId][key] !== undefined ? pluginSettings[pluginId][key] : defaultValue
    }

    function setPluginSetting(pluginId, key, value) {
        if (!pluginSettings[pluginId]) {
            pluginSettings[pluginId] = {}
        }
        pluginSettings[pluginId][key] = value
        savePluginSettings()
    }

    function removePluginSettings(pluginId) {
        if (pluginSettings[pluginId]) {
            delete pluginSettings[pluginId]
            savePluginSettings()
        }
    }

    function getPluginSettingsForPlugin(pluginId) {
        return pluginSettings[pluginId] || {}
    }


    ListModel {
        id: leftWidgetsModel
    }

    ListModel {
        id: centerWidgetsModel
    }

    ListModel {
        id: rightWidgetsModel
    }

    property Process testNotificationProcess

    testNotificationProcess: Process {
        command: []
        running: false
    }

    property Timer testNotifTimer1

    testNotifTimer1: Timer {
        interval: 400
        repeat: false
        onTriggered: sendTestNotification(1)
    }

    property Timer testNotifTimer2

    testNotifTimer2: Timer {
        interval: 800
        repeat: false
        onTriggered: sendTestNotification(2)
    }

    property alias settingsFile: settingsFile

    FileView {
        id: settingsFile

        path: isGreeterMode ? "" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell/settings.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: !isGreeterMode
        onLoaded: {
            if (!isGreeterMode) {
                try {
                    const txt = settingsFile.text()
                    const obj = (txt && txt.trim()) ? JSON.parse(txt) : null
                    Store.parse(root, obj)
                    Store.migrate(root, obj)
                } catch (e) {
                    console.warn("SettingsData: Failed to reload settings:", e.message)
                }
                hasTriedDefaultSettings = false
            }
        }
        onLoadFailed: error => {
            if (!isGreeterMode && !hasTriedDefaultSettings) {
                hasTriedDefaultSettings = true
                Processes.checkDefaultSettings()
            } else if (!isGreeterMode) {
                applyStoredTheme()
            }
        }
    }

    FileView {
        id: pluginSettingsFile

        path: isGreeterMode ? "" : pluginSettingsPath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: !isGreeterMode
        onLoaded: {
            if (!isGreeterMode) {
                parsePluginSettings(pluginSettingsFile.text())
            }
        }
        onLoadFailed: error => {
            if (!isGreeterMode) {
                pluginSettings = {}
            }
        }
    }

    property bool pluginSettingsFileExists: false

    IpcHandler {
        function reveal(): string {
            root.setDankBarVisible(true)
            return "BAR_SHOW_SUCCESS"
        }

        function hide(): string {
            root.setDankBarVisible(false)
            return "BAR_HIDE_SUCCESS"
        }

        function toggle(): string {
            root.toggleDankBarVisible()
            return root.dankBarVisible ? "BAR_SHOW_SUCCESS" : "BAR_HIDE_SUCCESS"
        }

        function status(): string {
            return root.dankBarVisible ? "visible" : "hidden"
        }

        target: "bar"
    }
}
