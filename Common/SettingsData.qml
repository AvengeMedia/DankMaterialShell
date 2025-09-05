pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    // Theme settings
    property string currentThemeName: "blue"
    property string customThemeFile: ""
    property real topBarTransparency: 0.75
    property real topBarWidgetTransparency: 0.85
    property real popupTransparency: 0.92
    property real dockTransparency: 1
    property bool use24HourClock: true
    property bool useFahrenheit: false
    property bool nightModeEnabled: false
    property string weatherLocation: "New York, NY"
    property string weatherCoordinates: "40.7128,-74.0060"
    property bool useAutoLocation: false
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
    property bool showWorkspaceIndex: false
    property bool showWorkspacePadding: false
    property bool showWorkspaceApps: false
    property int maxWorkspaceIcons: 3
    property bool workspacesPerMonitor: true
    property var workspaceNameIcons: ({})
    property bool clockCompactMode: false
    property bool focusedWindowCompactMode: false
    property bool runningAppsCompactMode: true
    property bool runningAppsCurrentWorkspace: false
    property string clockDateFormat: ""
    property string lockDateFormat: ""
    property int mediaSize: 1
    property var topBarLeftWidgets: ["launcherButton", "workspaceSwitcher", "focusedWindow"]
    property var topBarCenterWidgets: ["music", "clock", "weather"]
    property var topBarRightWidgets: ["systemTray", "clipboard", "cpuUsage", "memUsage", "notificationButton", "battery", "controlCenterButton"]
    property alias topBarLeftWidgetsModel: leftWidgetsModel
    property alias topBarCenterWidgetsModel: centerWidgetsModel
    property alias topBarRightWidgetsModel: rightWidgetsModel
    property string appLauncherViewMode: "list"
    property string spotlightModalViewMode: "list"
    property string networkPreference: "auto"
    property string iconTheme: "System Default"
    property var availableIconThemes: ["System Default"]
    property string systemDefaultIconTheme: ""
    property bool qt5ctAvailable: false
    property bool qt6ctAvailable: false
    property bool gtkAvailable: false
    property bool useOSLogo: false
    property string osLogoColorOverride: ""
    property real osLogoBrightness: 0.5
    property real osLogoContrast: 1
    property bool wallpaperDynamicTheming: true
    property bool weatherEnabled: true
    property string fontFamily: "Inter Variable"
    property string monoFontFamily: "Fira Code"
    property int fontWeight: Font.Normal
    property bool gtkThemingEnabled: false
    property bool qtThemingEnabled: false
    property bool showDock: false
    property bool dockAutoHide: false
    property real cornerRadius: 12
    property bool notificationOverlayEnabled: false
    property bool topBarAutoHide: false
    property bool topBarVisible: true
    property real topBarSpacing: 4
    property real topBarBottomGap: 0
    property real topBarInnerPadding: 8
    property bool topBarSquareCorners: false
    property bool topBarNoBackground: false
    property int notificationTimeoutLow: 5000
    property int notificationTimeoutNormal: 5000
    property int notificationTimeoutCritical: 0
    property var screenPreferences: ({})
    readonly property string defaultFontFamily: "Inter Variable"
    readonly property string defaultMonoFontFamily: "Fira Code"
    readonly property string _homeUrl: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string _configUrl: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string _configDir: _configUrl.startsWith("file://") ? _configUrl.substring(7) : _configUrl

    signal forceTopBarLayoutRefresh
    signal widgetDataChanged
    signal workspaceIconsUpdated

    function getEffectiveTimeFormat() {
        if (use24HourClock) {
            return Locale.ShortFormat
        } else {
            return "h:mm AP"
        }
    }

    function getEffectiveClockDateFormat() {
        return clockDateFormat && clockDateFormat.length > 0 ? clockDateFormat : "ddd d"
    }

    function getEffectiveLockDateFormat() {
        return lockDateFormat && lockDateFormat.length > 0 ? lockDateFormat : Locale.LongFormat
    }

    function initializeListModels() {
        // ! Hack-ish to add all properties to the listmodel once
        // ! allows the properties to be bound on new widget addtions
        var dummyItem = {
            "widgetId": "dummy",
            "enabled": true,
            "size": 20,
            "selectedGpuIndex": 0,
            "pciId": ""
        }
        leftWidgetsModel.append(dummyItem)
        centerWidgetsModel.append(dummyItem)
        rightWidgetsModel.append(dummyItem)

        updateListModel(leftWidgetsModel, topBarLeftWidgets)
        updateListModel(centerWidgetsModel, topBarCenterWidgets)
        updateListModel(rightWidgetsModel, topBarRightWidgets)
    }

    function loadSettings() {
        parseSettings(settingsFile.text())
    }

    function parseSettings(content) {
        try {
            if (content && content.trim()) {
                var settings = JSON.parse(content)
                // Auto-migrate from old theme system
                if (settings.themeIndex !== undefined || settings.themeIsDynamic !== undefined) {
                    const themeNames = ["blue", "deepBlue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral"]
                    if (settings.themeIsDynamic) {
                        currentThemeName = "dynamic"
                    } else if (settings.themeIndex >= 0 && settings.themeIndex < themeNames.length) {
                        currentThemeName = themeNames[settings.themeIndex]
                    }
                    console.log("Auto-migrated theme from index", settings.themeIndex, "to", currentThemeName)
                } else {
                    currentThemeName = settings.currentThemeName !== undefined ? settings.currentThemeName : "blue"
                }
                customThemeFile = settings.customThemeFile !== undefined ? settings.customThemeFile : ""
                topBarTransparency = settings.topBarTransparency !== undefined ? (settings.topBarTransparency > 1 ? settings.topBarTransparency / 100 : settings.topBarTransparency) : 0.75
                topBarWidgetTransparency = settings.topBarWidgetTransparency !== undefined ? (settings.topBarWidgetTransparency > 1 ? settings.topBarWidgetTransparency / 100 : settings.topBarWidgetTransparency) : 0.85
                popupTransparency = settings.popupTransparency !== undefined ? (settings.popupTransparency > 1 ? settings.popupTransparency / 100 : settings.popupTransparency) : 0.92
                dockTransparency = settings.dockTransparency !== undefined ? (settings.dockTransparency > 1 ? settings.dockTransparency / 100 : settings.dockTransparency) : 1
                use24HourClock = settings.use24HourClock !== undefined ? settings.use24HourClock : true
                useFahrenheit = settings.useFahrenheit !== undefined ? settings.useFahrenheit : false
                nightModeEnabled = settings.nightModeEnabled !== undefined ? settings.nightModeEnabled : false
                weatherLocation = settings.weatherLocation !== undefined ? settings.weatherLocation : "New York, NY"
                weatherCoordinates = settings.weatherCoordinates !== undefined ? settings.weatherCoordinates : "40.7128,-74.0060"
                useAutoLocation = settings.useAutoLocation !== undefined ? settings.useAutoLocation : false
                weatherEnabled = settings.weatherEnabled !== undefined ? settings.weatherEnabled : true
                showLauncherButton = settings.showLauncherButton !== undefined ? settings.showLauncherButton : true
                showWorkspaceSwitcher = settings.showWorkspaceSwitcher !== undefined ? settings.showWorkspaceSwitcher : true
                showFocusedWindow = settings.showFocusedWindow !== undefined ? settings.showFocusedWindow : true
                showWeather = settings.showWeather !== undefined ? settings.showWeather : true
                showMusic = settings.showMusic !== undefined ? settings.showMusic : true
                showClipboard = settings.showClipboard !== undefined ? settings.showClipboard : true
                showCpuUsage = settings.showCpuUsage !== undefined ? settings.showCpuUsage : true
                showMemUsage = settings.showMemUsage !== undefined ? settings.showMemUsage : true
                showCpuTemp = settings.showCpuTemp !== undefined ? settings.showCpuTemp : true
                showGpuTemp = settings.showGpuTemp !== undefined ? settings.showGpuTemp : true
                selectedGpuIndex = settings.selectedGpuIndex !== undefined ? settings.selectedGpuIndex : 0
                enabledGpuPciIds = settings.enabledGpuPciIds !== undefined ? settings.enabledGpuPciIds : []
                showSystemTray = settings.showSystemTray !== undefined ? settings.showSystemTray : true
                showClock = settings.showClock !== undefined ? settings.showClock : true
                showNotificationButton = settings.showNotificationButton !== undefined ? settings.showNotificationButton : true
                showBattery = settings.showBattery !== undefined ? settings.showBattery : true
                showControlCenterButton = settings.showControlCenterButton !== undefined ? settings.showControlCenterButton : true
                controlCenterShowNetworkIcon = settings.controlCenterShowNetworkIcon !== undefined ? settings.controlCenterShowNetworkIcon : true
                controlCenterShowBluetoothIcon = settings.controlCenterShowBluetoothIcon !== undefined ? settings.controlCenterShowBluetoothIcon : true
                controlCenterShowAudioIcon = settings.controlCenterShowAudioIcon !== undefined ? settings.controlCenterShowAudioIcon : true
                showWorkspaceIndex = settings.showWorkspaceIndex !== undefined ? settings.showWorkspaceIndex : false
                showWorkspacePadding = settings.showWorkspacePadding !== undefined ? settings.showWorkspacePadding : false
                showWorkspaceApps = settings.showWorkspaceApps !== undefined ? settings.showWorkspaceApps : false
                maxWorkspaceIcons = settings.maxWorkspaceIcons !== undefined ? settings.maxWorkspaceIcons : 3
                workspaceNameIcons = settings.workspaceNameIcons !== undefined ? settings.workspaceNameIcons : ({})
                workspacesPerMonitor = settings.workspacesPerMonitor !== undefined ? settings.workspacesPerMonitor : true
                clockCompactMode = settings.clockCompactMode !== undefined ? settings.clockCompactMode : false
                focusedWindowCompactMode = settings.focusedWindowCompactMode !== undefined ? settings.focusedWindowCompactMode : false
                runningAppsCompactMode = settings.runningAppsCompactMode !== undefined ? settings.runningAppsCompactMode : true
                runningAppsCurrentWorkspace = settings.runningAppsCurrentWorkspace !== undefined ? settings.runningAppsCurrentWorkspace : false
                clockDateFormat = settings.clockDateFormat !== undefined ? settings.clockDateFormat : ""
                lockDateFormat = settings.lockDateFormat !== undefined ? settings.lockDateFormat : ""
                mediaSize = settings.mediaSize !== undefined ? settings.mediaSize : (settings.mediaCompactMode !== undefined ? (settings.mediaCompactMode ? 0 : 1) : 1)
                if (settings.topBarWidgetOrder) {
                    topBarLeftWidgets = settings.topBarWidgetOrder.filter(w => {
                                                                              return ["launcherButton", "workspaceSwitcher", "focusedWindow"].includes(w)
                                                                          })
                    topBarCenterWidgets = settings.topBarWidgetOrder.filter(w => {
                                                                                return ["clock", "music", "weather"].includes(w)
                                                                            })
                    topBarRightWidgets = settings.topBarWidgetOrder.filter(w => {
                                                                               return ["systemTray", "clipboard", "systemResources", "notificationButton", "battery", "controlCenterButton"].includes(w)
                                                                           })
                } else {
                    var leftWidgets = settings.topBarLeftWidgets !== undefined ? settings.topBarLeftWidgets : ["launcherButton", "workspaceSwitcher", "focusedWindow"]
                    var centerWidgets = settings.topBarCenterWidgets !== undefined ? settings.topBarCenterWidgets : ["music", "clock", "weather"]
                    var rightWidgets = settings.topBarRightWidgets !== undefined ? settings.topBarRightWidgets : ["systemTray", "clipboard", "cpuUsage", "memUsage", "notificationButton", "battery", "controlCenterButton"]
                    topBarLeftWidgets = leftWidgets
                    topBarCenterWidgets = centerWidgets
                    topBarRightWidgets = rightWidgets
                    updateListModel(leftWidgetsModel, leftWidgets)
                    updateListModel(centerWidgetsModel, centerWidgets)
                    updateListModel(rightWidgetsModel, rightWidgets)
                }
                appLauncherViewMode = settings.appLauncherViewMode !== undefined ? settings.appLauncherViewMode : "list"
                spotlightModalViewMode = settings.spotlightModalViewMode !== undefined ? settings.spotlightModalViewMode : "list"
                networkPreference = settings.networkPreference !== undefined ? settings.networkPreference : "auto"
                iconTheme = settings.iconTheme !== undefined ? settings.iconTheme : "System Default"
                useOSLogo = settings.useOSLogo !== undefined ? settings.useOSLogo : false
                osLogoColorOverride = settings.osLogoColorOverride !== undefined ? settings.osLogoColorOverride : ""
                osLogoBrightness = settings.osLogoBrightness !== undefined ? settings.osLogoBrightness : 0.5
                osLogoContrast = settings.osLogoContrast !== undefined ? settings.osLogoContrast : 1
                wallpaperDynamicTheming = settings.wallpaperDynamicTheming !== undefined ? settings.wallpaperDynamicTheming : true
                fontFamily = settings.fontFamily !== undefined ? settings.fontFamily : defaultFontFamily
                monoFontFamily = settings.monoFontFamily !== undefined ? settings.monoFontFamily : defaultMonoFontFamily
                fontWeight = settings.fontWeight !== undefined ? settings.fontWeight : Font.Normal
                gtkThemingEnabled = settings.gtkThemingEnabled !== undefined ? settings.gtkThemingEnabled : false
                qtThemingEnabled = settings.qtThemingEnabled !== undefined ? settings.qtThemingEnabled : false
                showDock = settings.showDock !== undefined ? settings.showDock : false
                dockAutoHide = settings.dockAutoHide !== undefined ? settings.dockAutoHide : false
                cornerRadius = settings.cornerRadius !== undefined ? settings.cornerRadius : 12
                notificationOverlayEnabled = settings.notificationOverlayEnabled !== undefined ? settings.notificationOverlayEnabled : false
                topBarAutoHide = settings.topBarAutoHide !== undefined ? settings.topBarAutoHide : false
                topBarVisible = settings.topBarVisible !== undefined ? settings.topBarVisible : true
                notificationTimeoutLow = settings.notificationTimeoutLow !== undefined ? settings.notificationTimeoutLow : 5000
                notificationTimeoutNormal = settings.notificationTimeoutNormal !== undefined ? settings.notificationTimeoutNormal : 5000
                notificationTimeoutCritical = settings.notificationTimeoutCritical !== undefined ? settings.notificationTimeoutCritical : 0
                topBarSpacing = settings.topBarSpacing !== undefined ? settings.topBarSpacing : 4
                topBarBottomGap = settings.topBarBottomGap !== undefined ? settings.topBarBottomGap : 0
                topBarInnerPadding = settings.topBarInnerPadding !== undefined ? settings.topBarInnerPadding : 8
                topBarSquareCorners = settings.topBarSquareCorners !== undefined ? settings.topBarSquareCorners : false
                topBarNoBackground = settings.topBarNoBackground !== undefined ? settings.topBarNoBackground : false
                screenPreferences = settings.screenPreferences !== undefined ? settings.screenPreferences : ({})
                applyStoredTheme()
                detectAvailableIconThemes()
                detectQtTools()
                updateGtkIconTheme(iconTheme)
                applyStoredIconTheme()
            } else {
                applyStoredTheme()
            }
        } catch (e) {
            applyStoredTheme()
        }
    }

    function saveSettings() {
        settingsFile.setText(JSON.stringify({
                                                "currentThemeName": currentThemeName,
                                                "customThemeFile": customThemeFile,
                                                "topBarTransparency": topBarTransparency,
                                                "topBarWidgetTransparency": topBarWidgetTransparency,
                                                "popupTransparency": popupTransparency,
                                                "dockTransparency": dockTransparency,
                                                "use24HourClock": use24HourClock,
                                                "useFahrenheit": useFahrenheit,
                                                "nightModeEnabled": nightModeEnabled,
                                                "weatherLocation": weatherLocation,
                                                "weatherCoordinates": weatherCoordinates,
                                                "useAutoLocation": useAutoLocation,
                                                "weatherEnabled": weatherEnabled,
                                                "showLauncherButton": showLauncherButton,
                                                "showWorkspaceSwitcher": showWorkspaceSwitcher,
                                                "showFocusedWindow": showFocusedWindow,
                                                "showWeather": showWeather,
                                                "showMusic": showMusic,
                                                "showClipboard": showClipboard,
                                                "showCpuUsage": showCpuUsage,
                                                "showMemUsage": showMemUsage,
                                                "showCpuTemp": showCpuTemp,
                                                "showGpuTemp": showGpuTemp,
                                                "selectedGpuIndex": selectedGpuIndex,
                                                "enabledGpuPciIds": enabledGpuPciIds,
                                                "showSystemTray": showSystemTray,
                                                "showClock": showClock,
                                                "showNotificationButton": showNotificationButton,
                                                "showBattery": showBattery,
                                                "showControlCenterButton": showControlCenterButton,
                                                "controlCenterShowNetworkIcon": controlCenterShowNetworkIcon,
                                                "controlCenterShowBluetoothIcon": controlCenterShowBluetoothIcon,
                                                "controlCenterShowAudioIcon": controlCenterShowAudioIcon,
                                                "showWorkspaceIndex": showWorkspaceIndex,
                                                "showWorkspacePadding": showWorkspacePadding,
                                                "showWorkspaceApps": showWorkspaceApps,
                                                "maxWorkspaceIcons": maxWorkspaceIcons,
                                                "workspacesPerMonitor": workspacesPerMonitor,
                                                "workspaceNameIcons": workspaceNameIcons,
                                                "clockCompactMode": clockCompactMode,
                                                "focusedWindowCompactMode": focusedWindowCompactMode,
                                                "runningAppsCompactMode": runningAppsCompactMode,
                                                "runningAppsCurrentWorkspace": runningAppsCurrentWorkspace,
                                                "clockDateFormat": clockDateFormat,
                                                "lockDateFormat": lockDateFormat,
                                                "mediaSize": mediaSize,
                                                "topBarLeftWidgets": topBarLeftWidgets,
                                                "topBarCenterWidgets": topBarCenterWidgets,
                                                "topBarRightWidgets": topBarRightWidgets,
                                                "appLauncherViewMode": appLauncherViewMode,
                                                "spotlightModalViewMode": spotlightModalViewMode,
                                                "networkPreference": networkPreference,
                                                "iconTheme": iconTheme,
                                                "useOSLogo": useOSLogo,
                                                "osLogoColorOverride": osLogoColorOverride,
                                                "osLogoBrightness": osLogoBrightness,
                                                "osLogoContrast": osLogoContrast,
                                                "wallpaperDynamicTheming": wallpaperDynamicTheming,
                                                "fontFamily": fontFamily,
                                                "monoFontFamily": monoFontFamily,
                                                "fontWeight": fontWeight,
                                                "gtkThemingEnabled": gtkThemingEnabled,
                                                "qtThemingEnabled": qtThemingEnabled,
                                                "showDock": showDock,
                                                "dockAutoHide": dockAutoHide,
                                                "cornerRadius": cornerRadius,
                                                "notificationOverlayEnabled": notificationOverlayEnabled,
                                                "topBarAutoHide": topBarAutoHide,
                                                "topBarVisible": topBarVisible,
                                                "topBarSpacing": topBarSpacing,
                                                "topBarBottomGap": topBarBottomGap,
                                                "topBarInnerPadding": topBarInnerPadding,
                                                "topBarSquareCorners": topBarSquareCorners,
                                                "topBarNoBackground": topBarNoBackground,
                                                "notificationTimeoutLow": notificationTimeoutLow,
                                                "notificationTimeoutNormal": notificationTimeoutNormal,
                                                "notificationTimeoutCritical": notificationTimeoutCritical,
                                                "screenPreferences": screenPreferences
                                            }, null, 2))
    }

    function setShowWorkspaceIndex(enabled) {
        showWorkspaceIndex = enabled
        saveSettings()
    }

    function setShowWorkspacePadding(enabled) {
        showWorkspacePadding = enabled
        saveSettings()
    }

    function setShowWorkspaceApps(enabled) {
        showWorkspaceApps = enabled
        saveSettings()
    }

    function setMaxWorkspaceIcons(maxIcons) {
        maxWorkspaceIcons = maxIcons
        saveSettings()
    }

    function setWorkspacesPerMonitor(enabled) {
        workspacesPerMonitor = enabled
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

    function hasNamedWorkspaces() {
        if (typeof NiriService === "undefined" || !CompositorService.isNiri)
            return false

        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
            var ws = NiriService.allWorkspaces[i]
            if (ws.name && ws.name.trim() !== "")
                return true
        }
        return false
    }

    function getNamedWorkspaces() {
        var namedWorkspaces = []
        if (typeof NiriService === "undefined" || !CompositorService.isNiri)
            return namedWorkspaces

        for (const ws of NiriService.allWorkspaces) {
            if (ws.name && ws.name.trim() !== "") {
                namedWorkspaces.push(ws.name)
            }
        }
        return namedWorkspaces
    }

    function setClockCompactMode(enabled) {
        clockCompactMode = enabled
        saveSettings()
    }

    function setFocusedWindowCompactMode(enabled) {
        focusedWindowCompactMode = enabled
        saveSettings()
    }

    function setRunningAppsCompactMode(enabled) {
        runningAppsCompactMode = enabled
        saveSettings()
    }

    function setRunningAppsCurrentWorkspace(enabled) {
        runningAppsCurrentWorkspace = enabled
        saveSettings()
    }

    function setClockDateFormat(format) {
        clockDateFormat = format || ""
        saveSettings()
    }

    function setLockDateFormat(format) {
        lockDateFormat = format || ""
        saveSettings()
    }

    function setMediaSize(size) {
        mediaSize = size
        saveSettings()
    }

    function applyStoredTheme() {
        if (typeof Theme !== "undefined")
            Theme.switchTheme(currentThemeName, false)
        else
            Qt.callLater(() => {
                             if (typeof Theme !== "undefined")
                             Theme.switchTheme(currentThemeName, false)
                         })
    }

    function setTheme(themeName) {
        currentThemeName = themeName
        saveSettings()
    }

    function setCustomThemeFile(filePath) {
        customThemeFile = filePath
        saveSettings()
    }

    function setTopBarTransparency(transparency) {
        topBarTransparency = transparency
        saveSettings()
    }

    function setTopBarWidgetTransparency(transparency) {
        topBarWidgetTransparency = transparency
        saveSettings()
    }

    function setPopupTransparency(transparency) {
        popupTransparency = transparency
        saveSettings()
    }

    function setDockTransparency(transparency) {
        dockTransparency = transparency
        saveSettings()
    }

    // New preference setters
    function setClockFormat(use24Hour) {
        use24HourClock = use24Hour
        saveSettings()
    }

    function setTemperatureUnit(fahrenheit) {
        useFahrenheit = fahrenheit
        saveSettings()
    }

    function setNightModeEnabled(enabled) {
        nightModeEnabled = enabled
        saveSettings()
    }

    // Widget visibility setters
    function setShowLauncherButton(enabled) {
        showLauncherButton = enabled
        saveSettings()
    }

    function setShowWorkspaceSwitcher(enabled) {
        showWorkspaceSwitcher = enabled
        saveSettings()
    }

    function setShowFocusedWindow(enabled) {
        showFocusedWindow = enabled
        saveSettings()
    }

    function setShowWeather(enabled) {
        showWeather = enabled
        saveSettings()
    }

    function setShowMusic(enabled) {
        showMusic = enabled
        saveSettings()
    }

    function setShowClipboard(enabled) {
        showClipboard = enabled
        saveSettings()
    }

    function setShowCpuUsage(enabled) {
        showCpuUsage = enabled
        saveSettings()
    }

    function setShowMemUsage(enabled) {
        showMemUsage = enabled
        saveSettings()
    }

    function setShowCpuTemp(enabled) {
        showCpuTemp = enabled
        saveSettings()
    }

    function setShowGpuTemp(enabled) {
        showGpuTemp = enabled
        saveSettings()
    }

    function setSelectedGpuIndex(index) {
        selectedGpuIndex = index
        saveSettings()
    }

    function setEnabledGpuPciIds(pciIds) {
        enabledGpuPciIds = pciIds
        saveSettings()
    }

    function setShowSystemTray(enabled) {
        showSystemTray = enabled
        saveSettings()
    }

    function setShowClock(enabled) {
        showClock = enabled
        saveSettings()
    }

    function setShowNotificationButton(enabled) {
        showNotificationButton = enabled
        saveSettings()
    }

    function setShowBattery(enabled) {
        showBattery = enabled
        saveSettings()
    }

    function setShowControlCenterButton(enabled) {
        showControlCenterButton = enabled
        saveSettings()
    }

    function setControlCenterShowNetworkIcon(enabled) {
        controlCenterShowNetworkIcon = enabled
        saveSettings()
    }

    function setControlCenterShowBluetoothIcon(enabled) {
        controlCenterShowBluetoothIcon = enabled
        saveSettings()
    }

    function setControlCenterShowAudioIcon(enabled) {
        controlCenterShowAudioIcon = enabled
        saveSettings()
    }

    function setTopBarWidgetOrder(order) {
        topBarWidgetOrder = order
        saveSettings()
    }

    function setTopBarLeftWidgets(order) {
        topBarLeftWidgets = order
        updateListModel(leftWidgetsModel, order)
        saveSettings()
    }

    function setTopBarCenterWidgets(order) {
        topBarCenterWidgets = order
        updateListModel(centerWidgetsModel, order)
        saveSettings()
    }

    function setTopBarRightWidgets(order) {
        topBarRightWidgets = order
        updateListModel(rightWidgetsModel, order)
        saveSettings()
    }

    function updateListModel(listModel, order) {
        listModel.clear()
        for (var i = 0; i < order.length; i++) {
            var widgetId = typeof order[i] === "string" ? order[i] : order[i].id
            var enabled = typeof order[i] === "string" ? true : order[i].enabled
            var size = typeof order[i] === "string" ? undefined : order[i].size
            var selectedGpuIndex = typeof order[i] === "string" ? undefined : order[i].selectedGpuIndex
            var pciId = typeof order[i] === "string" ? undefined : order[i].pciId
            var item = {
                "widgetId": widgetId,
                "enabled": enabled
            }
            if (size !== undefined)
                item.size = size
            if (selectedGpuIndex !== undefined)
                item.selectedGpuIndex = selectedGpuIndex
            if (pciId !== undefined)
                item.pciId = pciId

            listModel.append(item)
        }
        // Emit signal to notify widgets that data has changed
        widgetDataChanged()
    }

    function resetTopBarWidgetsToDefault() {
        var defaultLeft = ["launcherButton", "workspaceSwitcher", "focusedWindow"]
        var defaultCenter = ["music", "clock", "weather"]
        var defaultRight = ["systemTray", "clipboard", "notificationButton", "battery", "controlCenterButton"]
        topBarLeftWidgets = defaultLeft
        topBarCenterWidgets = defaultCenter
        topBarRightWidgets = defaultRight
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

    // View mode setters
    function setAppLauncherViewMode(mode) {
        appLauncherViewMode = mode
        saveSettings()
    }

    function setSpotlightModalViewMode(mode) {
        spotlightModalViewMode = mode
        saveSettings()
    }

    // Weather location setter
    function setWeatherLocation(displayName, coordinates) {
        weatherLocation = displayName
        weatherCoordinates = coordinates
        saveSettings()
    }

    function setAutoLocation(enabled) {
        useAutoLocation = enabled
        saveSettings()
    }

    function setWeatherEnabled(enabled) {
        weatherEnabled = enabled
        saveSettings()
    }

    // Network preference setter
    function setNetworkPreference(preference) {
        networkPreference = preference
        saveSettings()
    }

    function detectAvailableIconThemes() {
        // First detect system default, then available themes
        systemDefaultDetectionProcess.running = true
    }

    function detectQtTools() {
        qtToolsDetectionProcess.running = true
    }

    function setIconTheme(themeName) {
        iconTheme = themeName
        updateGtkIconTheme(themeName)
        updateQtIconTheme(themeName)
        saveSettings()
        if (typeof Theme !== "undefined" && Theme.currentTheme === Theme.dynamic)
            Theme.generateSystemThemes()
    }

    function updateGtkIconTheme(themeName) {
        var gtkThemeName = (themeName === "System Default") ? systemDefaultIconTheme : themeName
        if (gtkThemeName !== "System Default" && gtkThemeName !== "") {
            var script = "if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -q org.gnome.desktop.interface; then\n"
                    + "    gsettings set org.gnome.desktop.interface icon-theme '" + gtkThemeName + "'\n" + "    echo 'Updated via gsettings'\n" + "elif command -v dconf >/dev/null 2>&1; then\n" + "    dconf write /org/gnome/desktop/interface/icon-theme \\\"" + gtkThemeName + "\\\"\n"
                    + "    echo 'Updated via dconf'\n" + "fi\n" + "\n" + "# Ensure config directories exist\n" + "mkdir -p " + _configDir + "/gtk-3.0 " + _configDir
                    + "/gtk-4.0\n" + "\n" + "# Update settings.ini files (keep existing gtk-theme-name)\n" + "for config_dir in " + _configDir + "/gtk-3.0 " + _configDir + "/gtk-4.0; do\n"
                    + "    settings_file=\"$config_dir/settings.ini\"\n" + "    if [ -f \"$settings_file\" ]; then\n" + "        # Update existing icon-theme-name line or add it\n" + "        if grep -q '^gtk-icon-theme-name=' \"$settings_file\"; then\n" + "            sed -i 's/^gtk-icon-theme-name=.*/gtk-icon-theme-name=" + gtkThemeName + "/' \"$settings_file\"\n" + "        else\n"
                    + "            # Add icon theme setting to [Settings] section or create it\n" + "            if grep -q '\\[Settings\\]' \"$settings_file\"; then\n" + "                sed -i '/\\[Settings\\]/a gtk-icon-theme-name=" + gtkThemeName + "' \"$settings_file\"\n" + "            else\n" + "                echo -e '\\n[Settings]\\ngtk-icon-theme-name=" + gtkThemeName
                    + "' >> \"$settings_file\"\n" + "            fi\n" + "        fi\n" + "    else\n" + "        # Create new settings.ini file\n" + "        echo -e '[Settings]\\ngtk-icon-theme-name=" + gtkThemeName + "' > \"$settings_file\"\n"
                    + "    fi\n" + "    echo \"Updated $settings_file\"\n" + "done\n" + "\n" + "# Clear icon cache and force refresh\n" + "rm -rf ~/.cache/icon-cache ~/.cache/thumbnails 2>/dev/null || true\n" + "# Send SIGHUP to running GTK applications to reload themes (Fedora-specific)\n" + "pkill -HUP -f 'gtk' 2>/dev/null || true\n"
            Quickshell.execDetached(["sh", "-lc", script])
        }
    }

    function updateQtIconTheme(themeName) {
        var qtThemeName = (themeName === "System Default") ? "" : themeName
        var home = _shq(root._homeUrl.replace("file://", ""))
        if (!qtThemeName) {
            // When "System Default" is selected, don't modify the config files at all
            // This preserves the user's existing qt6ct configuration
            return
        }
        var script = "mkdir -p " + _configDir + "/qt5ct " + _configDir + "/qt6ct " + _configDir + "/environment.d 2>/dev/null || true\n" + "update_qt_config() {\n" + "  local config_file=\"$1\"\n"
                + "  local theme_name=\"$2\"\n" + "  if [ -f \"$config_file\" ]; then\n" + "    if grep -q '^\\[Appearance\\]' \"$config_file\"; then\n" + "      awk -v theme=\"$theme_name\" '\n" + "        BEGIN { in_appearance = 0; icon_theme_added = 0 }\n" + "        /^\\[Appearance\\]/ { in_appearance = 1; print; next }\n" + "        /^\\[/ && !/^\\[Appearance\\]/ { \n" + "          if (in_appearance && !icon_theme_added) { \n"
                + "            print \"icon_theme=\" theme; icon_theme_added = 1 \n" + "          } \n" + "          in_appearance = 0; print; next \n" + "        }\n" + "        in_appearance && /^icon_theme=/ { \n" + "          if (!icon_theme_added) { \n" + "            print \"icon_theme=\" theme; icon_theme_added = 1 \n" + "          } \n"
                + "          next \n" + "        }\n" + "        { print }\n" + "        END { if (in_appearance && !icon_theme_added) print \"icon_theme=\" theme }\n" + "      ' \"$config_file\" > \"$config_file.tmp\" && mv \"$config_file.tmp\" \"$config_file\"\n" + "    else\n" + "      printf '\\n[Appearance]\\nicon_theme=%s\\n' \"$theme_name\" >> \"$config_file\"\n" + "    fi\n"
                + "  else\n" + "    printf '[Appearance]\\nicon_theme=%s\\n' \"$theme_name\" > \"$config_file\"\n" + "  fi\n" + "}\n" + "update_qt_config " + _configDir + "/qt5ct/qt5ct.conf " + _shq(
                    qtThemeName) + "\n" + "update_qt_config " + _configDir + "/qt6ct/qt6ct.conf " + _shq(qtThemeName) + "\n" + "rm -rf " + home + "/.cache/icon-cache " + home + "/.cache/thumbnails 2>/dev/null || true\n"
        Quickshell.execDetached(["sh", "-lc", script])
    }

    function applyStoredIconTheme() {
        updateGtkIconTheme(iconTheme)
        updateQtIconTheme(iconTheme)
    }

    function setUseOSLogo(enabled) {
        useOSLogo = enabled
        saveSettings()
    }

    function setOSLogoColorOverride(color) {
        osLogoColorOverride = color
        saveSettings()
    }

    function setOSLogoBrightness(brightness) {
        osLogoBrightness = brightness
        saveSettings()
    }

    function setOSLogoContrast(contrast) {
        osLogoContrast = contrast
        saveSettings()
    }

    function setWallpaperDynamicTheming(enabled) {
        wallpaperDynamicTheming = enabled
        saveSettings()
    }

    function setFontFamily(family) {
        fontFamily = family
        saveSettings()
    }

    function setFontWeight(weight) {
        fontWeight = weight
        saveSettings()
    }

    function setMonoFontFamily(family) {
        monoFontFamily = family
        saveSettings()
    }

    function setGtkThemingEnabled(enabled) {
        gtkThemingEnabled = enabled
        saveSettings()
        if (enabled && typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setQtThemingEnabled(enabled) {
        qtThemingEnabled = enabled
        saveSettings()
        if (enabled && typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setShowDock(enabled) {
        showDock = enabled
        saveSettings()
    }

    function setDockAutoHide(enabled) {
        dockAutoHide = enabled
        saveSettings()
    }

    function setCornerRadius(radius) {
        cornerRadius = radius
        saveSettings()
    }

    function setNotificationOverlayEnabled(enabled) {
        notificationOverlayEnabled = enabled
        saveSettings()
    }

    function setTopBarAutoHide(enabled) {
        topBarAutoHide = enabled
        saveSettings()
    }

    function setTopBarVisible(visible) {
        topBarVisible = visible
        saveSettings()
    }

    function toggleTopBarVisible() {
        topBarVisible = !topBarVisible
        saveSettings()
    }

    function setNotificationTimeoutLow(timeout) {
        notificationTimeoutLow = timeout
        saveSettings()
    }

    function setNotificationTimeoutNormal(timeout) {
        notificationTimeoutNormal = timeout
        saveSettings()
    }

    function setNotificationTimeoutCritical(timeout) {
        notificationTimeoutCritical = timeout
        saveSettings()
    }

    function setTopBarSpacing(spacing) {
        topBarSpacing = spacing
        saveSettings()
    }

    function setTopBarBottomGap(gap) {
        topBarBottomGap = gap
        saveSettings()
    }

    function setTopBarInnerPadding(padding) {
        topBarInnerPadding = padding
        saveSettings()
    }

    function setTopBarSquareCorners(enabled) {
        topBarSquareCorners = enabled
        saveSettings()
    }

    function setTopBarNoBackground(enabled) {
        topBarNoBackground = enabled
        saveSettings()
    }

    function setScreenPreferences(prefs) {
        screenPreferences = prefs
        saveSettings()
    }

    function getFilteredScreens(componentId) {
        var prefs = screenPreferences && screenPreferences[componentId] || ["all"]
        if (prefs.includes("all")) {
            return Quickshell.screens
        }
        return Quickshell.screens.filter(screen => prefs.includes(screen.name))
    }

    function _shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    Component.onCompleted: {
        loadSettings()
        fontCheckTimer.start()
        initializeListModels()
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

    Timer {
        id: fontCheckTimer

        interval: 3000
        repeat: false
        onTriggered: {
            var availableFonts = Qt.fontFamilies()
            var missingFonts = []
            if (fontFamily === defaultFontFamily && !availableFonts.includes(defaultFontFamily))
            missingFonts.push(defaultFontFamily)

            if (monoFontFamily === defaultMonoFontFamily && !availableFonts.includes(defaultMonoFontFamily))
            missingFonts.push(defaultMonoFontFamily)

            if (missingFonts.length > 0) {
                var message = "Missing fonts: " + missingFonts.join(", ") + ". Using system defaults."
                ToastService.showWarning(message)
            }
        }
    }

    property bool hasTriedDefaultSettings: false

    FileView {
        id: settingsFile

        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell/settings.json"
        blockLoading: true
        blockWrites: true
        watchChanges: true
        onLoaded: {
            parseSettings(settingsFile.text())
            hasTriedDefaultSettings = false
        }
        onLoadFailed: error => {
            if (!hasTriedDefaultSettings) {
                hasTriedDefaultSettings = true
                defaultSettingsCheckProcess.running = true
            } else {
                applyStoredTheme()
            }
        }
    }

    Process {
        id: systemDefaultDetectionProcess

        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | sed \"s/'//g\" || echo ''"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0 && stdout && stdout.length > 0)
            systemDefaultIconTheme = stdout.trim()
            else
            systemDefaultIconTheme = ""
            iconThemeDetectionProcess.running = true
        }
    }

    Process {
        id: iconThemeDetectionProcess

        command: ["sh", "-c", "find /usr/share/icons ~/.local/share/icons ~/.icons -maxdepth 1 -type d 2>/dev/null | sed 's|.*/||' | grep -v '^icons$' | sort -u"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var detectedThemes = ["System Default"]
                if (text && text.trim()) {
                    var themes = text.trim().split('\n')
                    for (var i = 0; i < themes.length; i++) {
                        var theme = themes[i].trim()
                        if (theme && theme !== "" && theme !== "default" && theme !== "hicolor" && theme !== "locolor")
                        detectedThemes.push(theme)
                    }
                }
                availableIconThemes = detectedThemes
            }
        }
    }

    Process {
        id: qtToolsDetectionProcess

        command: ["sh", "-c", "echo -n 'qt5ct:'; command -v qt5ct >/dev/null && echo 'true' || echo 'false'; echo -n 'qt6ct:'; command -v qt6ct >/dev/null && echo 'true' || echo 'false'; echo -n 'gtk:'; (command -v gsettings >/dev/null || command -v dconf >/dev/null) && echo 'true' || echo 'false'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    var lines = text.trim().split('\n')
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i]
                        if (line.startsWith('qt5ct:'))
                        qt5ctAvailable = line.split(':')[1] === 'true'
                        else if (line.startsWith('qt6ct:'))
                        qt6ctAvailable = line.split(':')[1] === 'true'
                        else if (line.startsWith('gtk:'))
                        gtkAvailable = line.split(':')[1] === 'true'
                    }
                }
            }
        }
    }

    Process {
        id: defaultSettingsCheckProcess

        command: ["sh", "-c", "CONFIG_DIR=\"" + _configDir
            + "/DankMaterialShell\"; if [ -f \"$CONFIG_DIR/default-settings.json\" ] && [ ! -f \"$CONFIG_DIR/settings.json\" ]; then cp \"$CONFIG_DIR/default-settings.json\" \"$CONFIG_DIR/settings.json\" && echo 'copied'; else echo 'not_found'; fi"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Copied default-settings.json to settings.json")
                settingsFile.reload()
            } else {
                // No default settings file found, just apply stored theme
                applyStoredTheme()
            }
        }
    }

    IpcHandler {
        function reveal(): string {
            root.setTopBarVisible(true)
            return "BAR_SHOW_SUCCESS"
        }

        function hide(): string {
            root.setTopBarVisible(false)
            return "BAR_HIDE_SUCCESS"
        }

        function toggle(): string {
            root.toggleTopBarVisible()
            return topBarVisible ? "BAR_SHOW_SUCCESS" : "BAR_HIDE_SUCCESS"
        }

        function status(): string {
            return topBarVisible ? "visible" : "hidden"
        }

        target: "bar"
    }
}
