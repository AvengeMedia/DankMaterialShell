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

    readonly property int settingsConfigVersion: 5

    readonly property bool isGreeterMode: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"

    enum Position {
        Top,
        Bottom,
        Left,
        Right,
        TopCenter,
        BottomCenter,
        LeftCenter,
        RightCenter
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

    enum WidgetColorMode {
        Default,
        Colorful
    }

    readonly property string _homeUrl: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string _configUrl: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string _configDir: Paths.strip(_configUrl)
    readonly property string pluginSettingsPath: _configDir + "/DankMaterialShell/plugin_settings.json"

    property bool _loading: false
    property bool _pluginSettingsLoading: false
    property bool _parseError: false
    property bool _pluginParseError: false
    property bool _hasLoaded: false
    property bool _isReadOnly: false
    property bool _hasUnsavedChanges: false
    property bool _selfWrite: false
    property var _loadedSettingsSnapshot: null
    property var pluginSettings: ({})
    property var builtInPluginSettings: ({})

    function getBuiltInPluginSetting(pluginId, key, defaultValue) {
        if (!builtInPluginSettings[pluginId])
            return defaultValue;
        return builtInPluginSettings[pluginId][key] !== undefined ? builtInPluginSettings[pluginId][key] : defaultValue;
    }

    function setBuiltInPluginSetting(pluginId, key, value) {
        const updated = JSON.parse(JSON.stringify(builtInPluginSettings));
        if (!updated[pluginId])
            updated[pluginId] = {};
        updated[pluginId][key] = value;
        builtInPluginSettings = updated;
        saveSettings();
    }

    property bool clipboardEnterToPaste: false

    property var launcherPluginVisibility: ({})

    function getPluginAllowWithoutTrigger(pluginId) {
        if (!launcherPluginVisibility[pluginId])
            return true;
        return launcherPluginVisibility[pluginId].allowWithoutTrigger !== false;
    }

    function setPluginAllowWithoutTrigger(pluginId, allow) {
        const updated = JSON.parse(JSON.stringify(launcherPluginVisibility));
        if (!updated[pluginId])
            updated[pluginId] = {};
        updated[pluginId].allowWithoutTrigger = allow;
        launcherPluginVisibility = updated;
        saveSettings();
    }

    property var launcherPluginOrder: []
    onLauncherPluginOrderChanged: saveSettings()

    function setLauncherPluginOrder(order) {
        launcherPluginOrder = order;
    }

    function getOrderedLauncherPlugins(allPlugins) {
        if (!launcherPluginOrder || launcherPluginOrder.length === 0)
            return allPlugins;
        const orderMap = {};
        for (let i = 0; i < launcherPluginOrder.length; i++)
            orderMap[launcherPluginOrder[i]] = i;
        return allPlugins.slice().sort((a, b) => {
            const aOrder = orderMap[a.id] ?? 9999;
            const bOrder = orderMap[b.id] ?? 9999;
            if (aOrder !== bOrder)
                return aOrder - bOrder;
            return a.name.localeCompare(b.name);
        });
    }

    property alias dankBarLeftWidgetsModel: leftWidgetsModel
    property alias dankBarCenterWidgetsModel: centerWidgetsModel
    property alias dankBarRightWidgetsModel: rightWidgetsModel

    property string currentThemeName: "purple"
    property string currentThemeCategory: "generic"
    property string customThemeFile: ""
    property var registryThemeVariants: ({})
    property string matugenScheme: "scheme-tonal-spot"
    property bool runUserMatugenTemplates: true
    property string matugenTargetMonitor: ""
    property real popupTransparency: 1.0
    property real dockTransparency: 1
    property string widgetBackgroundColor: "sch"
    property string widgetColorMode: "default"
    property string controlCenterTileColorMode: "primary"
    property string buttonColorMode: "primary"
    property real cornerRadius: 12
    property int niriLayoutGapsOverride: -1
    property int niriLayoutRadiusOverride: -1
    property int niriLayoutBorderSize: -1
    property int hyprlandLayoutGapsOverride: -1
    property int hyprlandLayoutRadiusOverride: -1
    property int hyprlandLayoutBorderSize: -1
    property int mangoLayoutGapsOverride: -1
    property int mangoLayoutRadiusOverride: -1
    property int mangoLayoutBorderSize: -1

    property bool use24HourClock: true
    property bool showSeconds: false
    property bool padHours12Hour: false
    property bool useFahrenheit: false
    property string windSpeedUnit: "kmh"
    property bool nightModeEnabled: false
    property int animationSpeed: SettingsData.AnimationSpeed.Short
    property int customAnimationDuration: 500
    property bool syncComponentAnimationSpeeds: true
    onSyncComponentAnimationSpeedsChanged: saveSettings()
    property int popoutAnimationSpeed: SettingsData.AnimationSpeed.Short
    property int popoutCustomAnimationDuration: 150
    property int modalAnimationSpeed: SettingsData.AnimationSpeed.Short
    property int modalCustomAnimationDuration: 150
    property bool enableRippleEffects: true
    onEnableRippleEffectsChanged: saveSettings()
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
    property bool showCapsLockIndicator: true

    property bool controlCenterShowNetworkIcon: true
    property bool controlCenterShowBluetoothIcon: true
    property bool controlCenterShowAudioIcon: true
    property bool controlCenterShowAudioPercent: false
    property bool controlCenterShowVpnIcon: true
    property bool controlCenterShowBrightnessIcon: false
    property bool controlCenterShowBrightnessPercent: false
    property bool controlCenterShowMicIcon: false
    property bool controlCenterShowMicPercent: true
    property bool controlCenterShowBatteryIcon: false
    property bool controlCenterShowPrinterIcon: false
    property bool controlCenterShowScreenSharingIcon: true
    property bool showPrivacyButton: true
    property bool privacyShowMicIcon: false
    property bool privacyShowCameraIcon: false
    property bool privacyShowScreenShareIcon: false

    property var controlCenterWidgets: [
        {
            "id": "volumeSlider",
            "enabled": true,
            "width": 50
        },
        {
            "id": "brightnessSlider",
            "enabled": true,
            "width": 50
        },
        {
            "id": "wifi",
            "enabled": true,
            "width": 50
        },
        {
            "id": "bluetooth",
            "enabled": true,
            "width": 50
        },
        {
            "id": "audioOutput",
            "enabled": true,
            "width": 50
        },
        {
            "id": "audioInput",
            "enabled": true,
            "width": 50
        },
        {
            "id": "nightMode",
            "enabled": true,
            "width": 50
        },
        {
            "id": "darkMode",
            "enabled": true,
            "width": 50
        }
    ]

    property bool showWorkspaceIndex: false
    property bool showWorkspaceName: false
    property bool showWorkspacePadding: false
    property bool workspaceScrolling: false
    property bool showWorkspaceApps: false
    property bool workspaceDragReorder: true
    property bool groupWorkspaceApps: true
    property int maxWorkspaceIcons: 3
    property int workspaceAppIconSizeOffset: 0
    property bool workspaceFollowFocus: false
    property bool showOccupiedWorkspacesOnly: false
    property bool reverseScrolling: false
    property bool dwlShowAllTags: false
    property string workspaceColorMode: "default"
    property string workspaceOccupiedColorMode: "none"
    property string workspaceUnfocusedColorMode: "default"
    property string workspaceUrgentColorMode: "default"
    property bool workspaceFocusedBorderEnabled: false
    property string workspaceFocusedBorderColor: "primary"
    property int workspaceFocusedBorderThickness: 2
    property var workspaceNameIcons: ({})
    property bool waveProgressEnabled: true
    property bool scrollTitleEnabled: true
    property bool audioVisualizerEnabled: true
    property string audioScrollMode: "volume"
    property int audioWheelScrollAmount: 5
    property bool clockCompactMode: false
    property bool focusedWindowCompactMode: false
    property bool runningAppsCompactMode: true
    property int barMaxVisibleApps: 0
    property int barMaxVisibleRunningApps: 0
    property bool barShowOverflowBadge: true
    property bool appsDockHideIndicators: false
    property bool appsDockColorizeActive: false
    property string appsDockActiveColorMode: "primary"
    property bool appsDockEnlargeOnHover: false
    property int appsDockEnlargePercentage: 125
    property int appsDockIconSizePercentage: 100
    property bool keyboardLayoutNameCompactMode: false
    property bool runningAppsCurrentWorkspace: true
    property bool runningAppsGroupByApp: false
    property bool runningAppsCurrentMonitor: false
    property var appIdSubstitutions: []
    property string centeringMode: "index"
    property string clockDateFormat: ""
    property string lockDateFormat: ""
    property int mediaSize: 1

    property string appLauncherViewMode: "list"
    property string spotlightModalViewMode: "list"
    property string browserPickerViewMode: "grid"
    property var browserUsageHistory: ({})
    property string appPickerViewMode: "grid"
    property var filePickerUsageHistory: ({})
    property bool sortAppsAlphabetically: false
    property int appLauncherGridColumns: 4
    property bool spotlightCloseNiriOverview: true
    property var spotlightSectionViewModes: ({})
    onSpotlightSectionViewModesChanged: saveSettings()
    property var appDrawerSectionViewModes: ({})
    onAppDrawerSectionViewModesChanged: saveSettings()
    property bool niriOverviewOverlayEnabled: true
    property string dankLauncherV2Size: "compact"
    property bool dankLauncherV2BorderEnabled: false
    property int dankLauncherV2BorderThickness: 2
    property string dankLauncherV2BorderColor: "primary"
    property bool dankLauncherV2ShowFooter: true
    property bool dankLauncherV2UnloadOnClose: false

    property string _legacyWeatherLocation: "New York, NY"
    property string _legacyWeatherCoordinates: "40.7128,-74.0060"
    property string _legacyVpnLastConnected: ""
    readonly property string weatherLocation: SessionData.weatherLocation
    readonly property string weatherCoordinates: SessionData.weatherCoordinates
    property bool useAutoLocation: false
    property bool weatherEnabled: true

    property string networkPreference: "auto"

    property string iconTheme: "System Default"
    property var availableIconThemes: ["System Default"]
    property string systemDefaultIconTheme: ""
    property bool qt5ctAvailable: false
    property bool qt6ctAvailable: false
    property bool gtkAvailable: false

    property var cursorSettings: ({
            "theme": "System Default",
            "size": 24,
            "niri": {
                "hideWhenTyping": false,
                "hideAfterInactiveMs": 0
            },
            "hyprland": {
                "hideOnKeyPress": false,
                "hideOnTouch": false,
                "inactiveTimeout": 0
            },
            "dwl": {
                "cursorHideTimeout": 0
            }
        })
    property var availableCursorThemes: ["System Default"]
    property string systemDefaultCursorTheme: ""

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
    // onCenteringModeChanged: saveSettings()
    onNotepadTransparencyOverrideChanged: {
        if (notepadTransparencyOverride > 0) {
            notepadLastCustomTransparency = notepadTransparencyOverride;
        }
        saveSettings();
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
    property string acProfileName: ""
    property int batteryMonitorTimeout: 0
    property int batteryLockTimeout: 0
    property int batterySuspendTimeout: 0
    property int batterySuspendBehavior: SettingsData.SuspendBehavior.Suspend
    property string batteryProfileName: ""
    property int batteryChargeLimit: 100
    property bool lockBeforeSuspend: false
    property bool loginctlLockIntegration: true
    property bool fadeToLockEnabled: true
    property int fadeToLockGracePeriod: 5
    property bool fadeToDpmsEnabled: true
    property int fadeToDpmsGracePeriod: 5
    property string launchPrefix: ""
    property var brightnessDevicePins: ({})
    property var wifiNetworkPins: ({})
    property var bluetoothDevicePins: ({})
    property var audioInputDevicePins: ({})
    property var audioOutputDevicePins: ({})

    property bool gtkThemingEnabled: false
    property bool qtThemingEnabled: false
    property bool syncModeWithPortal: true
    property bool terminalsAlwaysDark: false

    property bool runDmsMatugenTemplates: true
    property bool matugenTemplateGtk: true
    property bool matugenTemplateNiri: true
    property bool matugenTemplateHyprland: true
    property bool matugenTemplateMangowc: true
    property bool matugenTemplateQt5ct: true
    property bool matugenTemplateQt6ct: true
    property bool matugenTemplateFirefox: true
    property bool matugenTemplatePywalfox: true
    property bool matugenTemplateZenBrowser: true
    property bool matugenTemplateVesktop: true
    property bool matugenTemplateEquibop: true
    property bool matugenTemplateGhostty: true
    property bool matugenTemplateKitty: true
    property bool matugenTemplateFoot: true
    property bool matugenTemplateNeovim: true
    property bool matugenTemplateAlacritty: true
    property bool matugenTemplateWezterm: true
    property bool matugenTemplateDgop: true
    property bool matugenTemplateKcolorscheme: true
    property bool matugenTemplateVscode: true
    property bool matugenTemplateEmacs: true

    property bool showDock: false
    property bool dockAutoHide: false
    property bool dockSmartAutoHide: false
    property bool dockGroupByApp: false
    property bool dockOpenOnOverview: false
    property int dockPosition: SettingsData.Position.Bottom
    property real dockSpacing: 4
    property real dockBottomGap: 0
    property real dockMargin: 0
    property real dockIconSize: 40
    property string dockIndicatorStyle: "circle"
    property bool dockBorderEnabled: false
    property string dockBorderColor: "surfaceText"
    property real dockBorderOpacity: 1.0
    property int dockBorderThickness: 1
    property bool dockIsolateDisplays: false
    property bool dockLauncherEnabled: false
    property string dockLauncherLogoMode: "apps"
    property string dockLauncherLogoCustomPath: ""
    property string dockLauncherLogoColorOverride: ""
    property int dockLauncherLogoSizeOffset: 0
    property real dockLauncherLogoBrightness: 0.5
    property real dockLauncherLogoContrast: 1
    property int dockMaxVisibleApps: 0
    property int dockMaxVisibleRunningApps: 0
    property bool dockShowOverflowBadge: true

    property bool notificationOverlayEnabled: false
    property bool notificationPopupShadowEnabled: true
    property bool notificationPopupPrivacyMode: false
    property int overviewRows: 2
    property int overviewColumns: 5
    property real overviewScale: 0.16

    property bool modalDarkenBackground: true

    property bool lockScreenShowPowerActions: true
    property bool lockScreenShowSystemIcons: true
    property bool lockScreenShowTime: true
    property bool lockScreenShowDate: true
    property bool lockScreenShowProfileImage: true
    property bool lockScreenShowPasswordField: true
    property bool lockScreenShowMediaPlayer: true
    property bool lockScreenPowerOffMonitorsOnLock: false
    property bool lockAtStartup: false

    property bool enableFprint: false
    property int maxFprintTries: 15
    property bool fprintdAvailable: false
    property string lockScreenActiveMonitor: "all"
    property string lockScreenInactiveColor: "#000000"
    property int lockScreenNotificationMode: 0
    property bool hideBrightnessSlider: false

    property int notificationTimeoutLow: 5000
    property int notificationTimeoutNormal: 5000
    property int notificationTimeoutCritical: 0
    property bool notificationCompactMode: false
    property int notificationPopupPosition: SettingsData.Position.Top
    property int notificationAnimationSpeed: SettingsData.AnimationSpeed.Short
    property int notificationCustomAnimationDuration: 400
    property bool notificationHistoryEnabled: true
    property int notificationHistoryMaxCount: 50
    property int notificationHistoryMaxAgeDays: 7
    property bool notificationHistorySaveLow: true
    property bool notificationHistorySaveNormal: true
    property bool notificationHistorySaveCritical: true
    property var notificationRules: []

    property bool osdAlwaysShowValue: false
    property int osdPosition: SettingsData.Position.BottomCenter
    property bool osdVolumeEnabled: true
    property bool osdMediaVolumeEnabled: true
    property bool osdMediaPlaybackEnabled: false
    property bool osdBrightnessEnabled: true
    property bool osdIdleInhibitorEnabled: true
    property bool osdMicMuteEnabled: true
    property bool osdCapsLockEnabled: true
    property bool osdPowerProfileEnabled: true
    property bool osdAudioOutputEnabled: true

    property bool powerActionConfirm: true
    property real powerActionHoldDuration: 0.5
    property var powerMenuActions: ["reboot", "logout", "poweroff", "lock", "suspend", "restart"]
    property string powerMenuDefaultAction: "logout"
    property bool powerMenuGridLayout: false
    property string customPowerActionLock: ""
    property string customPowerActionLogout: ""
    property string customPowerActionSuspend: ""
    property string customPowerActionHibernate: ""
    property string customPowerActionReboot: ""
    property string customPowerActionPowerOff: ""

    property bool updaterHideWidget: false
    property bool updaterUseCustomCommand: false
    property string updaterCustomCommand: ""
    property string updaterTerminalAdditionalParams: ""

    property string displayNameMode: "system"
    property var screenPreferences: ({})
    property var showOnLastDisplay: ({})
    property var niriOutputSettings: ({})
    property var hyprlandOutputSettings: ({})
    property var displayProfiles: ({})
    property var activeDisplayProfile: ({})
    property bool displayProfileAutoSelect: false
    property bool displayShowDisconnected: false
    property bool displaySnapToEdge: true

    property var barConfigs: [
        {
            "id": "default",
            "name": "Main Bar",
            "enabled": true,
            "position": 0,
            "screenPreferences": ["all"],
            "showOnLastDisplay": true,
            "leftWidgets": ["launcherButton", "workspaceSwitcher", "focusedWindow"],
            "centerWidgets": ["music", "clock", "weather"],
            "rightWidgets": ["systemTray", "clipboard", "cpuUsage", "memUsage", "notificationButton", "battery", "controlCenterButton"],
            "spacing": 4,
            "innerPadding": 4,
            "bottomGap": 0,
            "transparency": 1.0,
            "widgetTransparency": 1.0,
            "squareCorners": false,
            "noBackground": false,
            "maximizeWidgetIcons": false,
            "maximizeWidgetText": false,
            "removeWidgetPadding": false,
            "widgetPadding": 8,
            "gothCornersEnabled": false,
            "gothCornerRadiusOverride": false,
            "gothCornerRadiusValue": 12,
            "borderEnabled": false,
            "borderColor": "surfaceText",
            "borderOpacity": 1.0,
            "borderThickness": 1,
            "widgetOutlineEnabled": false,
            "widgetOutlineColor": "primary",
            "widgetOutlineOpacity": 1.0,
            "widgetOutlineThickness": 1,
            "fontScale": 1.0,
            "iconScale": 1.0,
            "autoHide": false,
            "autoHideDelay": 250,
            "showOnWindowsOpen": false,
            "openOnOverview": false,
            "visible": true,
            "popupGapsAuto": true,
            "popupGapsManual": 4,
            "maximizeDetection": true,
            "scrollEnabled": true,
            "scrollXBehavior": "column",
            "scrollYBehavior": "workspace",
            "shadowIntensity": 0,
            "shadowOpacity": 60,
            "shadowColorMode": "text",
            "shadowCustomColor": "#000000",
            "clickThrough": false
        }
    ]

    property bool desktopClockEnabled: false
    property string desktopClockStyle: "analog"
    property real desktopClockTransparency: 0.8
    property string desktopClockColorMode: "primary"
    property color desktopClockCustomColor: "#ffffff"
    property bool desktopClockShowDate: true
    property bool desktopClockShowAnalogNumbers: false
    property bool desktopClockShowAnalogSeconds: true
    property real desktopClockX: -1
    property real desktopClockY: -1
    property real desktopClockWidth: 280
    property real desktopClockHeight: 180
    property var desktopClockDisplayPreferences: ["all"]

    property bool systemMonitorEnabled: false
    property bool systemMonitorShowHeader: true
    property real systemMonitorTransparency: 0.8
    property string systemMonitorColorMode: "primary"
    property color systemMonitorCustomColor: "#ffffff"
    property bool systemMonitorShowCpu: true
    property bool systemMonitorShowCpuGraph: true
    property bool systemMonitorShowCpuTemp: true
    property bool systemMonitorShowGpuTemp: false
    property string systemMonitorGpuPciId: ""
    property bool systemMonitorShowMemory: true
    property bool systemMonitorShowMemoryGraph: true
    property bool systemMonitorShowNetwork: true
    property bool systemMonitorShowNetworkGraph: true
    property bool systemMonitorShowDisk: true
    property bool systemMonitorShowTopProcesses: false
    property int systemMonitorTopProcessCount: 3
    property string systemMonitorTopProcessSortBy: "cpu"
    property string systemMonitorLayoutMode: "auto"
    property int systemMonitorGraphInterval: 60
    property real systemMonitorX: -1
    property real systemMonitorY: -1
    property real systemMonitorWidth: 320
    property real systemMonitorHeight: 480
    property var systemMonitorDisplayPreferences: ["all"]
    property var systemMonitorVariants: []
    property var desktopWidgetPositions: ({})
    property var desktopWidgetGridSettings: ({})
    property var desktopWidgetInstances: []
    property var desktopWidgetGroups: []

    function getDesktopWidgetGridSetting(screenKey, property, defaultValue) {
        const val = desktopWidgetGridSettings?.[screenKey]?.[property];
        return val !== undefined ? val : defaultValue;
    }

    function setDesktopWidgetGridSetting(screenKey, property, value) {
        const allSettings = JSON.parse(JSON.stringify(desktopWidgetGridSettings || {}));
        if (!allSettings[screenKey])
            allSettings[screenKey] = {};
        allSettings[screenKey][property] = value;
        desktopWidgetGridSettings = allSettings;
        saveSettings();
    }

    function getDesktopWidgetPosition(pluginId, screenKey, property, defaultValue) {
        const pos = desktopWidgetPositions?.[pluginId]?.[screenKey]?.[property];
        return pos !== undefined ? pos : defaultValue;
    }

    function updateDesktopWidgetPosition(pluginId, screenKey, updates) {
        const allPositions = JSON.parse(JSON.stringify(desktopWidgetPositions || {}));
        if (!allPositions[pluginId])
            allPositions[pluginId] = {};
        allPositions[pluginId][screenKey] = Object.assign({}, allPositions[pluginId][screenKey] || {}, updates);
        desktopWidgetPositions = allPositions;
        saveSettings();
    }

    function getSystemMonitorVariants() {
        return systemMonitorVariants || [];
    }

    function createSystemMonitorVariant(name, config) {
        const id = "sysmon_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        const variant = {
            id: id,
            name: name,
            config: config || getDefaultSystemMonitorConfig()
        };
        const variants = JSON.parse(JSON.stringify(systemMonitorVariants || []));
        variants.push(variant);
        systemMonitorVariants = variants;
        saveSettings();
        return variant;
    }

    function updateSystemMonitorVariant(variantId, updates) {
        const variants = JSON.parse(JSON.stringify(systemMonitorVariants || []));
        const idx = variants.findIndex(v => v.id === variantId);
        if (idx === -1)
            return;
        Object.assign(variants[idx], updates);
        systemMonitorVariants = variants;
        saveSettings();
    }

    function removeSystemMonitorVariant(variantId) {
        const variants = (systemMonitorVariants || []).filter(v => v.id !== variantId);
        systemMonitorVariants = variants;
        saveSettings();
    }

    function getSystemMonitorVariant(variantId) {
        return (systemMonitorVariants || []).find(v => v.id === variantId) || null;
    }

    function getDefaultSystemMonitorConfig() {
        return {
            showHeader: true,
            transparency: 0.8,
            colorMode: "primary",
            customColor: "#ffffff",
            showCpu: true,
            showCpuGraph: true,
            showCpuTemp: true,
            showGpuTemp: false,
            gpuPciId: "",
            showMemory: true,
            showMemoryGraph: true,
            showNetwork: true,
            showNetworkGraph: true,
            showDisk: true,
            showTopProcesses: false,
            topProcessCount: 3,
            topProcessSortBy: "cpu",
            layoutMode: "auto",
            graphInterval: 60,
            x: -1,
            y: -1,
            width: 320,
            height: 480,
            displayPreferences: ["all"]
        };
    }

    function createDesktopWidgetInstance(widgetType, name, config) {
        const id = "dw_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        const instance = {
            id: id,
            widgetType: widgetType,
            name: name || widgetType,
            enabled: true,
            config: config || {},
            positions: {}
        };
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        instances.push(instance);
        desktopWidgetInstances = instances;
        saveSettings();
        return instance;
    }

    function updateDesktopWidgetInstance(instanceId, updates) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        const idx = instances.findIndex(inst => inst.id === instanceId);
        if (idx === -1)
            return;
        Object.assign(instances[idx], updates);
        desktopWidgetInstances = instances;
        saveSettings();
    }

    function updateDesktopWidgetInstanceConfig(instanceId, configUpdates) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        const idx = instances.findIndex(inst => inst.id === instanceId);
        if (idx === -1)
            return;
        instances[idx].config = Object.assign({}, instances[idx].config || {}, configUpdates);
        desktopWidgetInstances = instances;
        saveSettings();
    }

    function updateDesktopWidgetInstancePosition(instanceId, screenKey, positionUpdates) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        const idx = instances.findIndex(inst => inst.id === instanceId);
        if (idx === -1)
            return;
        if (!instances[idx].positions)
            instances[idx].positions = {};
        instances[idx].positions[screenKey] = Object.assign({}, instances[idx].positions[screenKey] || {}, positionUpdates);
        desktopWidgetInstances = instances;
        saveSettings();
    }

    function removeDesktopWidgetInstance(instanceId) {
        const instances = (desktopWidgetInstances || []).filter(inst => inst.id !== instanceId);
        desktopWidgetInstances = instances;
        saveSettings();
    }

    function syncDesktopWidgetPositionToAllScreens(instanceId) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        const idx = instances.findIndex(inst => inst.id === instanceId);
        if (idx === -1)
            return;
        const positions = instances[idx].positions || {};
        const screenKeys = Object.keys(positions).filter(k => k !== "_synced");
        if (screenKeys.length === 0)
            return;
        const sourceKey = screenKeys[0];
        const sourcePos = positions[sourceKey];
        if (!sourcePos)
            return;
        const screen = Array.from(Quickshell.screens.values()).find(s => getScreenDisplayName(s) === sourceKey);
        if (!screen)
            return;
        const screenW = screen.width;
        const screenH = screen.height;
        const synced = {};
        if (sourcePos.x !== undefined)
            synced.x = sourcePos.x / screenW;
        if (sourcePos.y !== undefined)
            synced.y = sourcePos.y / screenH;
        if (sourcePos.width !== undefined)
            synced.width = sourcePos.width;
        if (sourcePos.height !== undefined)
            synced.height = sourcePos.height;
        instances[idx].positions["_synced"] = synced;
        desktopWidgetInstances = instances;
        saveSettings();
    }

    function duplicateDesktopWidgetInstance(instanceId) {
        const source = getDesktopWidgetInstance(instanceId);
        if (!source)
            return null;
        const newId = "dw_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        const instance = {
            id: newId,
            widgetType: source.widgetType,
            name: source.name + " (Copy)",
            enabled: source.enabled,
            config: JSON.parse(JSON.stringify(source.config || {})),
            positions: {}
        };
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        instances.push(instance);
        desktopWidgetInstances = instances;
        saveSettings();
        return instance;
    }

    function getDesktopWidgetInstance(instanceId) {
        return (desktopWidgetInstances || []).find(inst => inst.id === instanceId) || null;
    }

    function getDesktopWidgetInstancesOfType(widgetType) {
        return (desktopWidgetInstances || []).filter(inst => inst.widgetType === widgetType);
    }

    function getEnabledDesktopWidgetInstances() {
        return (desktopWidgetInstances || []).filter(inst => inst.enabled);
    }

    function moveDesktopWidgetInstance(instanceId, direction) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        const idx = instances.findIndex(inst => inst.id === instanceId);
        if (idx === -1)
            return false;
        const targetIdx = direction === "up" ? idx - 1 : idx + 1;
        if (targetIdx < 0 || targetIdx >= instances.length)
            return false;
        const temp = instances[idx];
        instances[idx] = instances[targetIdx];
        instances[targetIdx] = temp;
        desktopWidgetInstances = instances;
        saveSettings();
        return true;
    }

    function reorderDesktopWidgetInstance(instanceId, newIndex) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        const idx = instances.findIndex(inst => inst.id === instanceId);
        if (idx === -1 || newIndex < 0 || newIndex >= instances.length)
            return false;
        const [item] = instances.splice(idx, 1);
        instances.splice(newIndex, 0, item);
        desktopWidgetInstances = instances;
        saveSettings();
        return true;
    }

    function reorderDesktopWidgetInstanceInGroup(instanceId, groupId, newIndexInGroup) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        const groups = desktopWidgetGroups || [];
        const groupMatches = inst => {
            if (groupId === null)
                return !inst.group || !groups.some(g => g.id === inst.group);
            return inst.group === groupId;
        };
        const groupInstances = instances.filter(groupMatches);
        const currentGroupIdx = groupInstances.findIndex(inst => inst.id === instanceId);
        if (currentGroupIdx === -1 || currentGroupIdx === newIndexInGroup)
            return false;
        if (newIndexInGroup < 0 || newIndexInGroup >= groupInstances.length)
            return false;
        const globalIdx = instances.findIndex(inst => inst.id === instanceId);
        if (globalIdx === -1)
            return false;
        const [item] = instances.splice(globalIdx, 1);
        const targetInstance = groupInstances[newIndexInGroup];
        let targetGlobalIdx = instances.findIndex(inst => inst.id === targetInstance.id);
        if (newIndexInGroup > currentGroupIdx)
            targetGlobalIdx++;
        instances.splice(targetGlobalIdx, 0, item);
        desktopWidgetInstances = instances;
        saveSettings();
        return true;
    }

    function createDesktopWidgetGroup(name) {
        const id = "dwg_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        const group = {
            id: id,
            name: name,
            collapsed: false
        };
        const groups = JSON.parse(JSON.stringify(desktopWidgetGroups || []));
        groups.push(group);
        desktopWidgetGroups = groups;
        saveSettings();
        return group;
    }

    function updateDesktopWidgetGroup(groupId, updates) {
        const groups = JSON.parse(JSON.stringify(desktopWidgetGroups || []));
        const idx = groups.findIndex(g => g.id === groupId);
        if (idx === -1)
            return;
        Object.assign(groups[idx], updates);
        desktopWidgetGroups = groups;
        saveSettings();
    }

    function removeDesktopWidgetGroup(groupId) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        for (let i = 0; i < instances.length; i++) {
            if (instances[i].group === groupId)
                instances[i].group = null;
        }
        desktopWidgetInstances = instances;
        const groups = (desktopWidgetGroups || []).filter(g => g.id !== groupId);
        desktopWidgetGroups = groups;
        saveSettings();
    }

    function getDesktopWidgetGroup(groupId) {
        return (desktopWidgetGroups || []).find(g => g.id === groupId) || null;
    }

    function getDesktopWidgetInstancesByGroup(groupId) {
        return (desktopWidgetInstances || []).filter(inst => inst.group === groupId);
    }

    function getUngroupedDesktopWidgetInstances() {
        return (desktopWidgetInstances || []).filter(inst => !inst.group);
    }

    signal forceDankBarLayoutRefresh
    signal forceDockLayoutRefresh
    signal widgetDataChanged
    signal workspaceIconsUpdated

    Component.onCompleted: {
        if (!isGreeterMode) {
            Processes.settingsRoot = root;
            loadSettings();
            initializeListModels();
            Processes.detectFprintd();
            Processes.checkPluginSettings();
        }
    }

    function applyStoredTheme() {
        if (typeof Theme !== "undefined") {
            Theme.currentThemeCategory = currentThemeCategory;
            Theme.switchTheme(currentThemeName, false, false);
        } else {
            Qt.callLater(function () {
                if (typeof Theme !== "undefined") {
                    Theme.currentThemeCategory = currentThemeCategory;
                    Theme.switchTheme(currentThemeName, false, false);
                }
            });
        }
    }

    function regenSystemThemes() {
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function updateCompositorLayout() {
        if (typeof CompositorService === "undefined")
            return;
        if (CompositorService.isNiri && typeof NiriService !== "undefined")
            NiriService.generateNiriLayoutConfig();
        if (CompositorService.isHyprland && typeof HyprlandService !== "undefined")
            HyprlandService.generateLayoutConfig();
        if (CompositorService.isDwl && typeof DwlService !== "undefined")
            DwlService.generateLayoutConfig();
    }

    function applyStoredIconTheme() {
        updateGtkIconTheme();
        updateQtIconTheme();
        updateCosmicIconTheme();
    }

    function updateCosmicIconTheme() {
        let cosmicThemeName = (iconTheme === "System Default") ? systemDefaultIconTheme : iconTheme;
        if (!cosmicThemeName || cosmicThemeName === "System Default") {
            const detectScript = `if command -v gsettings >/dev/null 2>&1; then
            gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | sed "s/'//g"
            elif command -v dconf >/dev/null 2>&1; then
            dconf read /org/gnome/desktop/interface/icon-theme 2>/dev/null | sed "s/'//g"
            fi`;

            Proc.runCommand("detectCosmicIconTheme", ["sh", "-c", detectScript], (output, exitCode) => {
                if (exitCode !== 0)
                    return;
                const detected = (output || "").trim();
                if (!detected || detected === "System Default")
                    return;
                const detectedEscaped = detected.replace(/'/g, "'\\''");
                const writeScript = `mkdir -p ${_configDir}/cosmic/com.system76.CosmicTk/v1
                printf '"%s"\\n' '${detectedEscaped}' > ${_configDir}/cosmic/com.system76.CosmicTk/v1/icon_theme 2>/dev/null || true`;
                Quickshell.execDetached(["sh", "-lc", writeScript]);
            });
            return;
        }

        const cosmicThemeNameEscaped = cosmicThemeName.replace(/'/g, "'\\''");
        const script = `mkdir -p ${_configDir}/cosmic/com.system76.CosmicTk/v1
        printf '"%s"\\n' '${cosmicThemeNameEscaped}' > ${_configDir}/cosmic/com.system76.CosmicTk/v1/icon_theme 2>/dev/null || true`;
        Quickshell.execDetached(["sh", "-lc", script]);
    }

    function updateCosmicThemeMode(isLightMode) {
        const isDark = isLightMode ? "false" : "true";
        const script = `mkdir -p ${_configDir}/cosmic/com.system76.CosmicTheme.Mode/v1
        printf '%s\\n' ${isDark} > ${_configDir}/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark 2>/dev/null || true`;
        Quickshell.execDetached(["sh", "-lc", script]);
    }

    function updateGtkIconTheme() {
        const gtkThemeName = (iconTheme === "System Default") ? systemDefaultIconTheme : iconTheme;
        if (gtkThemeName === "System Default" || gtkThemeName === "")
            return;
        if (typeof DMSService !== "undefined" && DMSService.apiVersion >= 3 && typeof PortalService !== "undefined") {
            PortalService.setSystemIconTheme(gtkThemeName);
        }

        const configScript = `mkdir -p ${_configDir}/gtk-3.0 ${_configDir}/gtk-4.0

        for config_dir in ${_configDir}/gtk-3.0 ${_configDir}/gtk-4.0; do
        settings_file="$config_dir/settings.ini"
        [ -f "$settings_file" ] && [ ! -w "$settings_file" ] && continue
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

        pkill -HUP -f 'gtk' 2>/dev/null || true`;

        Quickshell.execDetached(["sh", "-lc", configScript]);
    }

    function updateQtIconTheme() {
        const qtThemeName = (iconTheme === "System Default") ? "" : iconTheme;
        if (!qtThemeName)
            return;
        const home = _homeUrl.replace("file://", "").replace(/'/g, "'\\''");
        const qtThemeNameEscaped = qtThemeName.replace(/'/g, "'\\''");

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
        update_qt_icon_theme ${_configDir}/qt6ct/qt6ct.conf '${qtThemeNameEscaped}'`;

        Quickshell.execDetached(["sh", "-lc", script]);
    }

    readonly property var _hooks: ({
            "applyStoredTheme": applyStoredTheme,
            "regenSystemThemes": regenSystemThemes,
            "updateCompositorLayout": updateCompositorLayout,
            "applyStoredIconTheme": applyStoredIconTheme,
            "updateBarConfigs": updateBarConfigs,
            "updateCompositorCursor": updateCompositorCursor
        })

    function set(key, value) {
        Spec.set(root, key, value, saveSettings, _hooks);
    }

    function loadSettings() {
        _loading = true;
        _parseError = false;
        _hasUnsavedChanges = false;
        _pendingMigration = null;

        try {
            const txt = settingsFile.text();
            let obj = (txt && txt.trim()) ? JSON.parse(txt) : null;

            const oldVersion = obj?.configVersion ?? 0;
            if (oldVersion < settingsConfigVersion) {
                const migrated = Store.migrateToVersion(obj, settingsConfigVersion);
                if (migrated) {
                    _pendingMigration = migrated;
                    obj = migrated;
                }
            }

            Store.parse(root, obj);

            if (obj?.weatherLocation !== undefined)
                _legacyWeatherLocation = obj.weatherLocation;
            if (obj?.weatherCoordinates !== undefined)
                _legacyWeatherCoordinates = obj.weatherCoordinates;
            if (obj?.vpnLastConnected !== undefined && obj.vpnLastConnected !== "") {
                _legacyVpnLastConnected = obj.vpnLastConnected;
                SessionData.vpnLastConnected = _legacyVpnLastConnected;
                SessionData.saveSettings();
            }

            _loadedSettingsSnapshot = JSON.stringify(Store.toJson(root));
            _hasLoaded = true;
            applyStoredTheme();
            updateCompositorCursor();
            Processes.detectQtTools();

            _checkSettingsWritable();
        } catch (e) {
            _parseError = true;
            const msg = e.message;
            console.error("SettingsData: Failed to parse settings.json - file will not be overwritten. Error:", msg);
            Qt.callLater(() => ToastService.showError(I18n.tr("Failed to parse settings.json"), msg));
            applyStoredTheme();
        } finally {
            _loading = false;
        }
        loadPluginSettings();
    }

    property var _pendingMigration: null

    function _checkSettingsWritable() {
        settingsWritableCheckProcess.running = true;
    }

    function _onWritableCheckComplete(writable) {
        const wasReadOnly = _isReadOnly;
        _isReadOnly = !writable;
        if (_isReadOnly) {
            _hasUnsavedChanges = _checkForUnsavedChanges();
            if (!wasReadOnly)
                console.info("SettingsData: settings.json is now read-only");
        } else {
            _loadedSettingsSnapshot = JSON.stringify(Store.toJson(root));
            _hasUnsavedChanges = false;
            if (wasReadOnly)
                console.info("SettingsData: settings.json is now writable");
            if (_pendingMigration)
                settingsFile.setText(JSON.stringify(_pendingMigration, null, 2));
        }
        _pendingMigration = null;
    }

    function _checkForUnsavedChanges() {
        if (!_hasLoaded || !_loadedSettingsSnapshot)
            return false;
        const current = JSON.stringify(Store.toJson(root));
        return current !== _loadedSettingsSnapshot;
    }

    function getCurrentSettingsJson() {
        return JSON.stringify(Store.toJson(root), null, 2);
    }

    function loadPluginSettings() {
        _pluginSettingsLoading = true;
        parsePluginSettings(pluginSettingsFile.text());
        _pluginSettingsLoading = false;
    }

    function parsePluginSettings(content) {
        _pluginSettingsLoading = true;
        _pluginParseError = false;
        try {
            if (content && content.trim()) {
                pluginSettings = JSON.parse(content);
            } else {
                pluginSettings = {};
            }
        } catch (e) {
            _pluginParseError = true;
            const msg = e.message;
            console.error("SettingsData: Failed to parse plugin_settings.json - file will not be overwritten. Error:", msg);
            Qt.callLater(() => ToastService.showError(I18n.tr("Failed to parse plugin_settings.json"), msg));
            pluginSettings = {};
        } finally {
            _pluginSettingsLoading = false;
        }
    }

    function saveSettings() {
        if (_loading || _parseError || !_hasLoaded)
            return;
        _selfWrite = true;
        settingsFile.setText(JSON.stringify(Store.toJson(root), null, 2));
        if (_isReadOnly)
            _checkSettingsWritable();
    }

    function savePluginSettings() {
        if (_pluginSettingsLoading || _pluginParseError)
            return;
        pluginSettingsFile.setText(JSON.stringify(pluginSettings, null, 2));
    }

    function detectAvailableIconThemes() {
        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS") || "";
        const localData = Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation));
        const homeDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation));

        const dataDirs = xdgDataDirs.trim() !== "" ? xdgDataDirs.split(":").concat([localData]) : ["/usr/share", "/usr/local/share", localData];

        const iconPaths = dataDirs.map(d => d + "/icons").concat([homeDir + "/.icons"]);
        const pathsArg = iconPaths.join(" ");

        const script = `
            echo "SYSDEFAULT:$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | sed "s/'//g" || echo '')"
            for dir in ${pathsArg}; do
                [ -d "$dir" ] || continue
                for theme in "$dir"/*/; do
                    [ -d "$theme" ] || continue
                    basename "$theme"
                done
            done | grep -v '^icons$' | grep -v '^default$' | grep -v '^hicolor$' | grep -v '^locolor$' | sort -u
        `;

        Proc.runCommand("detectIconThemes", ["sh", "-c", script], (output, exitCode) => {
            const themes = ["System Default"];
            if (output && output.trim()) {
                const lines = output.trim().split('\n');
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (line.startsWith("SYSDEFAULT:")) {
                        systemDefaultIconTheme = line.substring(11).trim();
                        continue;
                    }
                    if (line)
                        themes.push(line);
                }
            }
            availableIconThemes = themes;
        });
    }

    function detectAvailableCursorThemes() {
        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS") || "";
        const localData = Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation));
        const homeDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation));

        const dataDirs = xdgDataDirs.trim() !== "" ? xdgDataDirs.split(":").concat([localData]) : ["/usr/share", "/usr/local/share", localData];

        const cursorPaths = dataDirs.map(d => d + "/icons").concat([homeDir + "/.icons", homeDir + "/.local/share/icons"]);
        const pathsArg = cursorPaths.join(" ");

        const script = `
            echo "SYSDEFAULT:$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | sed "s/'//g" || echo '')"
            for dir in ${pathsArg}; do
                [ -d "$dir" ] || continue
                for theme in "$dir"/*/; do
                    [ -d "$theme" ] || continue
                    [ -d "$theme/cursors" ] || continue
                    basename "$theme"
                done
            done | grep -v '^icons$' | grep -v '^default$' | sort -u
        `;

        Proc.runCommand("detectCursorThemes", ["sh", "-c", script], (output, exitCode) => {
            const themes = ["System Default"];
            if (output && output.trim()) {
                const lines = output.trim().split('\n');
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (line.startsWith("SYSDEFAULT:")) {
                        systemDefaultCursorTheme = line.substring(11).trim();
                        continue;
                    }
                    if (line)
                        themes.push(line);
                }
            }
            availableCursorThemes = themes;
        });
    }

    function getEffectiveTimeFormat() {
        if (use24HourClock)
            return showSeconds ? "hh:mm:ss" : "hh:mm";
        if (padHours12Hour)
            return showSeconds ? "hh:mm:ss AP" : "hh:mm AP";
        return showSeconds ? "h:mm:ss AP" : "h:mm AP";
    }

    function getEffectiveClockDateFormat() {
        return clockDateFormat && clockDateFormat.length > 0 ? clockDateFormat : "ddd d";
    }

    function getEffectiveLockDateFormat() {
        return lockDateFormat && lockDateFormat.length > 0 ? lockDateFormat : Locale.LongFormat;
    }

    function initializeListModels() {
        const defaultBar = barConfigs[0] || getBarConfig("default");
        if (defaultBar) {
            Lists.init(leftWidgetsModel, centerWidgetsModel, rightWidgetsModel, defaultBar.leftWidgets, defaultBar.centerWidgets, defaultBar.rightWidgets);
        }
    }

    function updateListModel(listModel, order) {
        Lists.update(listModel, order);
        widgetDataChanged();
    }

    function hasNamedWorkspaces() {
        if (typeof NiriService === "undefined" || !CompositorService.isNiri)
            return false;

        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
            var ws = NiriService.allWorkspaces[i];
            if (ws.name && ws.name.trim() !== "")
                return true;
        }
        return false;
    }

    function getNamedWorkspaces() {
        var namedWorkspaces = [];
        if (typeof NiriService === "undefined" || !CompositorService.isNiri)
            return namedWorkspaces;

        for (const ws of NiriService.allWorkspaces) {
            if (ws.name && ws.name.trim() !== "") {
                namedWorkspaces.push(ws.name);
            }
        }
        return namedWorkspaces;
    }

    function getPopupYPosition(barHeight) {
        const defaultBar = barConfigs[0] || getBarConfig("default");
        const gothOffset = defaultBar?.gothCornersEnabled ? Theme.cornerRadius : 0;
        const spacing = defaultBar?.spacing ?? 4;
        const bottomGap = defaultBar?.bottomGap ?? 0;
        return barHeight + spacing + bottomGap - gothOffset + Theme.popupDistance;
    }

    function getPopupTriggerPosition(pos, screen, barThickness, widgetWidth, barSpacing, barPosition, barConfig) {
        const relativeX = pos.x;
        const relativeY = pos.y;
        const defaultBar = barConfigs[0] || getBarConfig("default");
        const spacing = barSpacing !== undefined ? barSpacing : (defaultBar?.spacing ?? 4);
        const position = barPosition !== undefined ? barPosition : (defaultBar?.position ?? SettingsData.Position.Top);
        const rawBottomGap = barConfig ? (barConfig.bottomGap !== undefined ? barConfig.bottomGap : (defaultBar?.bottomGap ?? 0)) : (defaultBar?.bottomGap ?? 0);
        const bottomGap = Math.max(0, rawBottomGap);

        const useAutoGaps = (barConfig && barConfig.popupGapsAuto !== undefined) ? barConfig.popupGapsAuto : (defaultBar?.popupGapsAuto ?? true);
        const manualGapValue = (barConfig && barConfig.popupGapsManual !== undefined) ? barConfig.popupGapsManual : (defaultBar?.popupGapsManual ?? 4);
        const popupGap = useAutoGaps ? Math.max(4, spacing) : manualGapValue;

        switch (position) {
        case SettingsData.Position.Left:
            return {
                "x": barThickness + spacing + popupGap,
                "y": relativeY,
                "width": widgetWidth
            };
        case SettingsData.Position.Right:
            return {
                "x": (screen?.width || 0) - (barThickness + spacing + popupGap),
                "y": relativeY,
                "width": widgetWidth
            };
        case SettingsData.Position.Bottom:
            return {
                "x": relativeX,
                "y": (screen?.height || 0) - (barThickness + spacing + bottomGap + popupGap),
                "width": widgetWidth
            };
        default:
            return {
                "x": relativeX,
                "y": barThickness + spacing + bottomGap + popupGap,
                "width": widgetWidth
            };
        }
    }

    function getAdjacentBarInfo(screen, barPosition, barConfig) {
        if (!screen || !barConfig) {
            return {
                "topBar": 0,
                "bottomBar": 0,
                "leftBar": 0,
                "rightBar": 0
            };
        }

        if (barConfig.autoHide) {
            return {
                "topBar": 0,
                "bottomBar": 0,
                "leftBar": 0,
                "rightBar": 0
            };
        }

        const enabledBars = getEnabledBarConfigs();
        const defaultBar = barConfigs[0] || getBarConfig("default");
        const position = barPosition !== undefined ? barPosition : (defaultBar?.position ?? SettingsData.Position.Top);
        let topBar = 0;
        let bottomBar = 0;
        let leftBar = 0;
        let rightBar = 0;

        for (var i = 0; i < enabledBars.length; i++) {
            const other = enabledBars[i];
            if (other.id === barConfig.id)
                continue;
            if (other.autoHide)
                continue;
            const otherScreens = other.screenPreferences || ["all"];
            const barScreens = barConfig.screenPreferences || ["all"];
            const onSameScreen = otherScreens.includes("all") || barScreens.includes("all") || otherScreens.some(s => isScreenInPreferences(screen, [s]));

            if (!onSameScreen)
                continue;
            const otherSpacing = other.spacing !== undefined ? other.spacing : (defaultBar?.spacing ?? 4);
            const otherPadding = other.innerPadding !== undefined ? other.innerPadding : (defaultBar?.innerPadding ?? 4);
            const otherThickness = Math.max(26 + otherPadding * 0.6, Theme.barHeight - 4 - (8 - otherPadding)) + otherSpacing;

            const useAutoGaps = other.popupGapsAuto !== undefined ? other.popupGapsAuto : (defaultBar?.popupGapsAuto ?? true);
            const manualGap = other.popupGapsManual !== undefined ? other.popupGapsManual : (defaultBar?.popupGapsManual ?? 4);
            const popupGap = useAutoGaps ? Math.max(4, otherSpacing) : manualGap;

            switch (other.position) {
            case SettingsData.Position.Top:
                topBar = Math.max(topBar, otherThickness + popupGap);
                break;
            case SettingsData.Position.Bottom:
                bottomBar = Math.max(bottomBar, otherThickness + popupGap);
                break;
            case SettingsData.Position.Left:
                leftBar = Math.max(leftBar, otherThickness + popupGap);
                break;
            case SettingsData.Position.Right:
                rightBar = Math.max(rightBar, otherThickness + popupGap);
                break;
            }
        }

        return {
            "topBar": topBar,
            "bottomBar": bottomBar,
            "leftBar": leftBar,
            "rightBar": rightBar
        };
    }

    function getBarBounds(screen, barThickness, barPosition, barConfig) {
        if (!screen) {
            return {
                "x": 0,
                "y": 0,
                "width": 0,
                "height": 0,
                "wingSize": 0
            };
        }

        const defaultBar = barConfigs[0] || getBarConfig("default");
        const wingRadius = (defaultBar?.gothCornerRadiusOverride ?? false) ? (defaultBar?.gothCornerRadiusValue ?? 12) : Theme.cornerRadius;
        const wingSize = (defaultBar?.gothCornersEnabled ?? false) ? Math.max(0, wingRadius) : 0;
        const screenWidth = screen.width;
        const screenHeight = screen.height;
        const position = barPosition !== undefined ? barPosition : (defaultBar?.position ?? SettingsData.Position.Top);
        const bottomGap = barConfig ? (barConfig.bottomGap !== undefined ? barConfig.bottomGap : (defaultBar?.bottomGap ?? 0)) : (defaultBar?.bottomGap ?? 0);

        let topOffset = 0;
        let bottomOffset = 0;
        let leftOffset = 0;
        let rightOffset = 0;

        if (barConfig) {
            const enabledBars = getEnabledBarConfigs();
            for (var i = 0; i < enabledBars.length; i++) {
                const other = enabledBars[i];
                if (other.id === barConfig.id)
                    continue;
                const otherScreens = other.screenPreferences || ["all"];
                const barScreens = barConfig.screenPreferences || ["all"];
                const onSameScreen = otherScreens.includes("all") || barScreens.includes("all") || otherScreens.some(s => isScreenInPreferences(screen, [s]));

                if (!onSameScreen)
                    continue;
                const otherSpacing = other.spacing !== undefined ? other.spacing : (defaultBar?.spacing ?? 4);
                const otherPadding = other.innerPadding !== undefined ? other.innerPadding : (defaultBar?.innerPadding ?? 4);
                const otherThickness = Math.max(26 + otherPadding * 0.6, Theme.barHeight - 4 - (8 - otherPadding)) + otherSpacing + wingSize;
                const otherBottomGap = other.bottomGap !== undefined ? other.bottomGap : (defaultBar?.bottomGap ?? 0);

                switch (other.position) {
                case SettingsData.Position.Top:
                    if (position === SettingsData.Position.Top && other.id < barConfig.id) {
                        topOffset += otherThickness; // Simple stacking for same pos
                    } else if (position === SettingsData.Position.Left || position === SettingsData.Position.Right) {
                        topOffset = Math.max(topOffset, otherThickness);
                    }
                    break;
                case SettingsData.Position.Bottom:
                    if (position === SettingsData.Position.Bottom && other.id < barConfig.id) {
                        bottomOffset += (otherThickness + otherBottomGap);
                    } else if (position === SettingsData.Position.Left || position === SettingsData.Position.Right) {
                        bottomOffset = Math.max(bottomOffset, otherThickness + otherBottomGap);
                    }
                    break;
                case SettingsData.Position.Left:
                    if (position === SettingsData.Position.Top || position === SettingsData.Position.Bottom) {
                        leftOffset = Math.max(leftOffset, otherThickness);
                    } else if (position === SettingsData.Position.Left && other.id < barConfig.id) {
                        leftOffset += otherThickness;
                    }
                    break;
                case SettingsData.Position.Right:
                    if (position === SettingsData.Position.Top || position === SettingsData.Position.Bottom) {
                        rightOffset = Math.max(rightOffset, otherThickness);
                    } else if (position === SettingsData.Position.Right && other.id < barConfig.id) {
                        rightOffset += otherThickness;
                    }
                    break;
                }
            }
        }

        switch (position) {
        case SettingsData.Position.Top:
            return {
                "x": leftOffset,
                "y": topOffset + bottomGap,
                "width": screenWidth - leftOffset - rightOffset,
                "height": barThickness + wingSize,
                "wingSize": wingSize
            };
        case SettingsData.Position.Bottom:
            return {
                "x": leftOffset,
                "y": screenHeight - barThickness - wingSize - bottomGap - bottomOffset,
                "width": screenWidth - leftOffset - rightOffset,
                "height": barThickness + wingSize,
                "wingSize": wingSize
            };
        case SettingsData.Position.Left:
            return {
                "x": 0,
                "y": topOffset,
                "width": barThickness + wingSize,
                "height": screenHeight - topOffset - bottomOffset,
                "wingSize": wingSize
            };
        case SettingsData.Position.Right:
            return {
                "x": screenWidth - barThickness - wingSize,
                "y": topOffset,
                "width": barThickness + wingSize,
                "height": screenHeight - topOffset - bottomOffset,
                "wingSize": wingSize
            };
        }

        return {
            "x": 0,
            "y": 0,
            "width": 0,
            "height": 0,
            "wingSize": 0
        };
    }

    function updateBarConfigs() {
        barConfigsChanged();
        saveSettings();
    }

    function getBarConfig(barId) {
        return barConfigs.find(cfg => cfg.id === barId) || null;
    }

    function addBarConfig(config) {
        const configs = JSON.parse(JSON.stringify(barConfigs));
        configs.push(config);
        barConfigs = configs;
        updateBarConfigs();
    }

    function updateBarConfig(barId, updates) {
        const configs = JSON.parse(JSON.stringify(barConfigs));
        const index = configs.findIndex(cfg => cfg.id === barId);
        if (index === -1)
            return;
        const positionChanged = updates.position !== undefined && configs[index].position !== updates.position;

        Object.assign(configs[index], updates);
        barConfigs = configs;
        updateBarConfigs();

        if (positionChanged) {
            NotificationService.dismissAllPopups();
        }
    }

    function checkBarCollisions(barId) {
        const bar = getBarConfig(barId);
        if (!bar || !bar.enabled)
            return [];

        const conflicts = [];
        const enabledBars = getEnabledBarConfigs();

        for (var i = 0; i < enabledBars.length; i++) {
            const other = enabledBars[i];
            if (other.id === barId)
                continue;
            const samePosition = bar.position === other.position;
            if (!samePosition)
                continue;
            const barScreens = bar.screenPreferences || ["all"];
            const otherScreens = other.screenPreferences || ["all"];

            const hasAll = barScreens.includes("all") || otherScreens.includes("all");
            if (hasAll) {
                conflicts.push({
                    "barId": other.id,
                    "barName": other.name,
                    "reason": "Same position on all screens"
                });
                continue;
            }

            const overlapping = barScreens.some(screen => otherScreens.includes(screen));
            if (overlapping) {
                conflicts.push({
                    "barId": other.id,
                    "barName": other.name,
                    "reason": "Same position on overlapping screens"
                });
            }
        }

        return conflicts;
    }

    function deleteBarConfig(barId) {
        if (barId === "default")
            return;
        const configs = barConfigs.filter(cfg => cfg.id !== barId);
        barConfigs = configs;
        updateBarConfigs();
    }

    function getEnabledBarConfigs() {
        return barConfigs.filter(cfg => cfg.enabled);
    }

    function getScreensSortedByPosition() {
        const screens = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            screens.push(Quickshell.screens[i]);
        }
        screens.sort((a, b) => {
            if (a.x !== b.x)
                return a.x - b.x;
            return a.y - b.y;
        });
        return screens;
    }

    function getScreenModelIndex(screen) {
        if (!screen || !screen.model)
            return -1;
        const sorted = getScreensSortedByPosition();
        let modelCount = 0;
        let screenIndex = -1;
        for (var i = 0; i < sorted.length; i++) {
            if (sorted[i].model === screen.model) {
                if (sorted[i].name === screen.name) {
                    screenIndex = modelCount;
                }
                modelCount++;
            }
        }
        if (modelCount <= 1)
            return -1;
        return screenIndex;
    }

    function getScreenDisplayName(screen) {
        if (!screen)
            return "";
        if (displayNameMode === "model" && screen.model) {
            const modelIndex = getScreenModelIndex(screen);
            if (modelIndex >= 0) {
                return screen.model + "-" + modelIndex;
            }
            return screen.model;
        }
        return screen.name;
    }

    function isScreenInPreferences(screen, prefs) {
        if (!screen)
            return false;

        const screenDisplayName = getScreenDisplayName(screen);

        return prefs.some(pref => {
            if (typeof pref === "string") {
                if (pref === "all" || pref === screen.name)
                    return true;
                if (displayNameMode === "model") {
                    return pref === screenDisplayName;
                }
                return pref === screen.model;
            }

            if (displayNameMode === "model") {
                if (pref.model && screen.model) {
                    if (pref.modelIndex !== undefined) {
                        const screenModelIndex = getScreenModelIndex(screen);
                        return pref.model === screen.model && pref.modelIndex === screenModelIndex;
                    }
                    return pref.model === screen.model;
                }
                return false;
            }
            return pref.name === screen.name;
        });
    }

    function getFilteredScreens(componentId) {
        var prefs = screenPreferences && screenPreferences[componentId] || ["all"];
        if (prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all")) {
            return Quickshell.screens;
        }
        var filtered = Quickshell.screens.filter(screen => isScreenInPreferences(screen, prefs));
        if (filtered.length === 0 && showOnLastDisplay && showOnLastDisplay[componentId] && Quickshell.screens.length === 1) {
            return Quickshell.screens;
        }
        return filtered;
    }

    function sendTestNotifications() {
        NotificationService.dismissAllPopups();
        sendTestNotification(0);
        testNotifTimer1.start();
        testNotifTimer2.start();
    }

    function sendTestNotification(index) {
        const notifications = [["Notification Position Test", "DMS test notification 1 of 3 ~ Hi there!", "preferences-system"], ["Second Test", "DMS Notification 2 of 3 ~ Check it out!", "applications-graphics"], ["Third Test", "DMS notification 3 of 3 ~ Enjoy!", "face-smile"]];

        if (index < 0 || index >= notifications.length) {
            return;
        }

        const notif = notifications[index];
        testNotificationProcess.command = ["notify-send", "-h", "int:transient:1", "-a", "DMS", "-i", notif[2], notif[0], notif[1]];
        testNotificationProcess.running = true;
    }

    function setMatugenScheme(scheme) {
        var normalized = scheme || "scheme-tonal-spot";
        if (matugenScheme === normalized)
            return;
        set("matugenScheme", normalized);
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function setRunUserMatugenTemplates(enabled) {
        if (runUserMatugenTemplates === enabled)
            return;
        set("runUserMatugenTemplates", enabled);
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function setMatugenTargetMonitor(monitorName) {
        if (matugenTargetMonitor === monitorName)
            return;
        set("matugenTargetMonitor", monitorName);
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function setCornerRadius(radius) {
        set("cornerRadius", radius);
        updateCompositorLayout();
    }

    function setWeatherLocation(displayName, coordinates) {
        SessionData.setWeatherLocation(displayName, coordinates);
    }

    function setIconTheme(themeName) {
        iconTheme = themeName;
        updateGtkIconTheme();
        updateQtIconTheme();
        updateCosmicIconTheme();
        saveSettings();
        if (typeof Theme !== "undefined" && Theme.currentTheme === Theme.dynamic)
            Theme.generateSystemThemesFromCurrentTheme();
    }

    function setCursorTheme(themeName) {
        const updated = JSON.parse(JSON.stringify(cursorSettings));
        if (updated.theme === themeName)
            return;
        updated.theme = themeName;
        cursorSettings = updated;
        saveSettings();
        updateXResources();
        updateCompositorCursor();
    }

    function setCursorSize(size) {
        const updated = JSON.parse(JSON.stringify(cursorSettings));
        if (updated.size === size)
            return;
        updated.size = size;
        cursorSettings = updated;
        saveSettings();
        updateXResources();
        updateCompositorCursor();
    }

    // This solution for xwayland cursor themes is from the xwls discussion:
    // https://github.com/Supreeeme/xwayland-satellite/issues/104
    // no idea if this matters on other compositors but we also set XCURSOR stuff in the launcher
    function updateCompositorCursor() {
        if (typeof CompositorService === "undefined")
            return;
        if (CompositorService.isNiri && typeof NiriService !== "undefined") {
            NiriService.generateNiriCursorConfig();
            return;
        }
        if (CompositorService.isHyprland && typeof HyprlandService !== "undefined") {
            HyprlandService.generateCursorConfig();
            return;
        }
        if (CompositorService.isDwl && typeof DwlService !== "undefined") {
            DwlService.generateCursorConfig();
            return;
        }
    }

    function updateXResources() {
        const homeDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation));
        const xresourcesPath = homeDir + "/.Xresources";
        const themeName = cursorSettings.theme === "System Default" ? systemDefaultCursorTheme : cursorSettings.theme;
        const size = cursorSettings.size || 24;

        if (!themeName)
            return;

        const script = `
            xresources_file="${xresourcesPath}"
            [ -f "$xresources_file" ] && [ ! -w "$xresources_file" ] && exit 0
            theme_name="${themeName}"
            cursor_size="${size}"

            current_theme=""
            current_size=""
            if [ -f "$xresources_file" ]; then
                current_theme=$(grep -E '^[[:space:]]*Xcursor\\.theme:' "$xresources_file" 2>/dev/null | sed 's/.*:[[:space:]]*//' | head -1)
                current_size=$(grep -E '^[[:space:]]*Xcursor\\.size:' "$xresources_file" 2>/dev/null | sed 's/.*:[[:space:]]*//' | head -1)
            fi

            [ "$current_theme" = "$theme_name" ] && [ "$current_size" = "$cursor_size" ] && exit 0

            if [ -f "$xresources_file" ]; then
                cp "$xresources_file" "\${xresources_file}.backup$(date +%s)"
            fi

            temp_file="\${xresources_file}.tmp.$$"
            if [ -f "$xresources_file" ]; then
                grep -v '^[[:space:]]*Xcursor\\.theme:' "$xresources_file" | grep -v '^[[:space:]]*Xcursor\\.size:' > "$temp_file" 2>/dev/null || true
            else
                touch "$temp_file"
            fi

            echo "Xcursor.theme: $theme_name" >> "$temp_file"
            echo "Xcursor.size: $cursor_size" >> "$temp_file"
            mv "$temp_file" "$xresources_file"
            xrdb -merge "$xresources_file" 2>/dev/null || true
        `;

        Quickshell.execDetached(["sh", "-c", script]);
    }

    function getCursorEnvironment() {
        const isSystemDefault = cursorSettings.theme === "System Default";
        const isDefaultSize = !cursorSettings.size || cursorSettings.size === 24;
        if (isSystemDefault && isDefaultSize)
            return {};

        const themeName = isSystemDefault ? "" : cursorSettings.theme;
        const size = String(cursorSettings.size || 24);
        const env = {};

        if (!isDefaultSize) {
            env["XCURSOR_SIZE"] = size;
            env["HYPRCURSOR_SIZE"] = size;
        }
        if (themeName) {
            env["XCURSOR_THEME"] = themeName;
            env["HYPRCURSOR_THEME"] = themeName;
        }
        return env;
    }

    function setGtkThemingEnabled(enabled) {
        set("gtkThemingEnabled", enabled);
        if (enabled && typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function setQtThemingEnabled(enabled) {
        set("qtThemingEnabled", enabled);
        if (enabled && typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function setShowDock(enabled) {
        showDock = enabled;
        const defaultBar = barConfigs[0] || getBarConfig("default");
        const barPos = defaultBar?.position ?? SettingsData.Position.Top;
        if (enabled && dockPosition === barPos) {
            if (barPos === SettingsData.Position.Top) {
                setDockPosition(SettingsData.Position.Bottom);
                return;
            }
            if (barPos === SettingsData.Position.Bottom) {
                setDockPosition(SettingsData.Position.Top);
                return;
            }
            if (barPos === SettingsData.Position.Left) {
                setDockPosition(SettingsData.Position.Right);
                return;
            }
            if (barPos === SettingsData.Position.Right) {
                setDockPosition(SettingsData.Position.Left);
                return;
            }
        }
        saveSettings();
    }

    function setDockPosition(position) {
        dockPosition = position;
        const defaultBar = barConfigs[0] || getBarConfig("default");
        const barPos = defaultBar?.position ?? SettingsData.Position.Top;
        if (position === SettingsData.Position.Bottom && barPos === SettingsData.Position.Bottom && showDock) {
            setDankBarPosition(SettingsData.Position.Top);
        }
        if (position === SettingsData.Position.Top && barPos === SettingsData.Position.Top && showDock) {
            setDankBarPosition(SettingsData.Position.Bottom);
        }
        if (position === SettingsData.Position.Left && barPos === SettingsData.Position.Left && showDock) {
            setDankBarPosition(SettingsData.Position.Right);
        }
        if (position === SettingsData.Position.Right && barPos === SettingsData.Position.Right && showDock) {
            setDankBarPosition(SettingsData.Position.Left);
        }
        saveSettings();
        Qt.callLater(() => forceDockLayoutRefresh());
    }

    function setDankBarSpacing(spacing) {
        const defaultBar = barConfigs[0] || getBarConfig("default");
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "spacing": spacing
            });
        }
        updateCompositorLayout();
    }

    function setDankBarPosition(position) {
        const defaultBar = barConfigs[0] || getBarConfig("default");
        if (!defaultBar)
            return;
        if (position === SettingsData.Position.Bottom && dockPosition === SettingsData.Position.Bottom && showDock) {
            setDockPosition(SettingsData.Position.Top);
            return;
        }
        if (position === SettingsData.Position.Top && dockPosition === SettingsData.Position.Top && showDock) {
            setDockPosition(SettingsData.Position.Bottom);
            return;
        }
        if (position === SettingsData.Position.Left && dockPosition === SettingsData.Position.Left && showDock) {
            setDockPosition(SettingsData.Position.Right);
            return;
        }
        if (position === SettingsData.Position.Right && dockPosition === SettingsData.Position.Right && showDock) {
            setDockPosition(SettingsData.Position.Left);
            return;
        }
        updateBarConfig(defaultBar.id, {
            "position": position
        });
    }

    function setDankBarLeftWidgets(order) {
        const defaultBar = barConfigs[0] || getBarConfig("default");
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "leftWidgets": order
            });
            updateListModel(leftWidgetsModel, order);
        }
    }

    function setDankBarCenterWidgets(order) {
        const defaultBar = barConfigs[0] || getBarConfig("default");
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "centerWidgets": order
            });
            updateListModel(centerWidgetsModel, order);
        }
    }

    function setDankBarRightWidgets(order) {
        const defaultBar = barConfigs[0] || getBarConfig("default");
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "rightWidgets": order
            });
            updateListModel(rightWidgetsModel, order);
        }
    }

    function resetDankBarWidgetsToDefault() {
        var defaultLeft = ["launcherButton", "workspaceSwitcher", "focusedWindow"];
        var defaultCenter = ["music", "clock", "weather"];
        var defaultRight = ["systemTray", "clipboard", "notificationButton", "battery", "controlCenterButton"];
        const defaultBar = barConfigs[0] || getBarConfig("default");
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "leftWidgets": defaultLeft,
                "centerWidgets": defaultCenter,
                "rightWidgets": defaultRight
            });
        }
        updateListModel(leftWidgetsModel, defaultLeft);
        updateListModel(centerWidgetsModel, defaultCenter);
        updateListModel(rightWidgetsModel, defaultRight);
        showLauncherButton = true;
        showWorkspaceSwitcher = true;
        showFocusedWindow = true;
        showWeather = true;
        showMusic = true;
        showClipboard = true;
        showCpuUsage = true;
        showMemUsage = true;
        showCpuTemp = true;
        showGpuTemp = true;
        showSystemTray = true;
        showClock = true;
        showNotificationButton = true;
        showBattery = true;
        showControlCenterButton = true;
        showCapsLockIndicator = true;
    }

    function setWorkspaceNameIcon(workspaceName, iconData) {
        var iconMap = JSON.parse(JSON.stringify(workspaceNameIcons));
        iconMap[workspaceName] = iconData;
        workspaceNameIcons = iconMap;
        saveSettings();
        workspaceIconsUpdated();
    }

    function removeWorkspaceNameIcon(workspaceName) {
        var iconMap = JSON.parse(JSON.stringify(workspaceNameIcons));
        delete iconMap[workspaceName];
        workspaceNameIcons = iconMap;
        saveSettings();
        workspaceIconsUpdated();
    }

    function getWorkspaceNameIcon(workspaceName) {
        return workspaceNameIcons[workspaceName] || null;
    }

    function addAppIdSubstitution(pattern, replacement, type) {
        var subs = JSON.parse(JSON.stringify(appIdSubstitutions));
        subs.push({
            pattern: pattern,
            replacement: replacement,
            type: type
        });
        appIdSubstitutions = subs;
        saveSettings();
    }

    function updateAppIdSubstitution(index, pattern, replacement, type) {
        var subs = JSON.parse(JSON.stringify(appIdSubstitutions));
        if (index < 0 || index >= subs.length)
            return;
        subs[index] = {
            pattern: pattern,
            replacement: replacement,
            type: type
        };
        appIdSubstitutions = subs;
        saveSettings();
    }

    function removeAppIdSubstitution(index) {
        var subs = JSON.parse(JSON.stringify(appIdSubstitutions));
        if (index < 0 || index >= subs.length)
            return;
        subs.splice(index, 1);
        appIdSubstitutions = subs;
        saveSettings();
    }

    property bool _pendingExpandNotificationRules: false
    property int _pendingNotificationRuleIndex: -1

    function addNotificationRule() {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        rules.push({
            enabled: true,
            field: "appName",
            pattern: "",
            matchType: "contains",
            action: "default",
            urgency: "default"
        });
        notificationRules = rules;
        saveSettings();
    }

    function addNotificationRuleForNotification(appName, desktopEntry) {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        var pattern = (desktopEntry && desktopEntry !== "") ? desktopEntry : (appName || "");
        var field = (desktopEntry && desktopEntry !== "") ? "desktopEntry" : "appName";
        var rule = {
            enabled: true,
            field: pattern ? field : "appName",
            pattern: pattern || "",
            matchType: pattern ? "exact" : "contains",
            action: "default",
            urgency: "default"
        };
        rules.push(rule);
        notificationRules = rules;
        saveSettings();
        var index = rules.length - 1;
        _pendingExpandNotificationRules = true;
        _pendingNotificationRuleIndex = index;
        return index;
    }

    function addMuteRuleForApp(appName, desktopEntry) {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        var pattern = (desktopEntry && desktopEntry !== "") ? desktopEntry : (appName || "");
        var field = (desktopEntry && desktopEntry !== "") ? "desktopEntry" : "appName";
        if (pattern === "")
            return;
        rules.push({
            enabled: true,
            field: field,
            pattern: pattern,
            matchType: "exact",
            action: "mute",
            urgency: "default"
        });
        notificationRules = rules;
        saveSettings();
    }

    function isAppMuted(appName, desktopEntry) {
        const rules = notificationRules || [];
        const pat = (desktopEntry && desktopEntry !== "" ? desktopEntry : appName || "").toString().toLowerCase();
        if (!pat)
            return false;
        for (let i = 0; i < rules.length; i++) {
            const r = rules[i];
            if ((r.action || "").toString().toLowerCase() !== "mute" || r.enabled === false)
                continue;
            const field = (r.field || "appName").toString().toLowerCase();
            const rulePat = (r.pattern || "").toString().toLowerCase();
            if (!rulePat)
                continue;
            const useDesktop = field === "desktopentry";
            const matches = (useDesktop && desktopEntry) ? (desktopEntry.toString().toLowerCase() === rulePat) : (appName && appName.toString().toLowerCase() === rulePat);
            if (matches)
                return true;
            if (rulePat === pat)
                return true;
        }
        return false;
    }

    function removeMuteRuleForApp(appName, desktopEntry) {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        const app = (appName || "").toString().toLowerCase();
        const desktop = (desktopEntry || "").toString().toLowerCase();
        if (!app && !desktop)
            return;
        for (let i = rules.length - 1; i >= 0; i--) {
            const r = rules[i];
            if ((r.action || "").toString().toLowerCase() !== "mute")
                continue;
            const rulePat = (r.pattern || "").toString().toLowerCase();
            if (!rulePat)
                continue;
            if (rulePat === app || rulePat === desktop) {
                rules.splice(i, 1);
                notificationRules = rules;
                saveSettings();
                return;
            }
        }
    }

    function updateNotificationRule(index, ruleData) {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        if (index < 0 || index >= rules.length)
            return;
        var existing = rules[index] || {};
        rules[index] = Object.assign({}, existing, ruleData || {});
        notificationRules = rules;
        saveSettings();
    }

    function updateNotificationRuleField(index, key, value) {
        if (key === undefined || key === null || key === "")
            return;
        var patch = {};
        patch[key] = value;
        updateNotificationRule(index, patch);
    }

    function removeNotificationRule(index) {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        if (index < 0 || index >= rules.length)
            return;
        rules.splice(index, 1);
        notificationRules = rules;
        saveSettings();
    }

    function getDefaultNotificationRules() {
        return Spec.SPEC.notificationRules.def;
    }

    function resetNotificationRules() {
        notificationRules = JSON.parse(JSON.stringify(Spec.SPEC.notificationRules.def));
        saveSettings();
    }

    function getDefaultAppIdSubstitutions() {
        return Spec.SPEC.appIdSubstitutions.def;
    }

    function resetAppIdSubstitutions() {
        appIdSubstitutions = JSON.parse(JSON.stringify(Spec.SPEC.appIdSubstitutions.def));
        saveSettings();
    }

    function getRegistryThemeVariant(themeId, defaultVariant) {
        var stored = registryThemeVariants[themeId];
        if (typeof stored === "string")
            return stored || defaultVariant || "";
        return defaultVariant || "";
    }

    function setRegistryThemeVariant(themeId, variantId) {
        var variants = JSON.parse(JSON.stringify(registryThemeVariants));
        variants[themeId] = variantId;
        registryThemeVariants = variants;
        saveSettings();
        if (typeof Theme !== "undefined")
            Theme.reloadCustomThemeVariant();
    }

    function getRegistryThemeMultiVariant(themeId, defaults, mode) {
        var stored = registryThemeVariants[themeId];
        if (!stored || typeof stored !== "object")
            return defaults || {};
        if ((stored.dark && typeof stored.dark === "object") || (stored.light && typeof stored.light === "object")) {
            if (!mode)
                return stored.dark || stored.light || defaults || {};
            var modeData = stored[mode];
            if (modeData && typeof modeData === "object")
                return modeData;
            return defaults || {};
        }
        return stored;
    }

    function setRegistryThemeMultiVariant(themeId, flavor, accent, mode) {
        var variants = JSON.parse(JSON.stringify(registryThemeVariants));
        var existing = variants[themeId];
        var perMode = {};
        if (existing && typeof existing === "object") {
            if ((existing.dark && typeof existing.dark === "object") || (existing.light && typeof existing.light === "object")) {
                perMode = existing;
            } else if (typeof existing.flavor === "string") {
                perMode.dark = {
                    flavor: existing.flavor,
                    accent: existing.accent || ""
                };
            }
        }
        perMode[mode || "dark"] = {
            flavor: flavor,
            accent: accent
        };
        variants[themeId] = perMode;
        registryThemeVariants = variants;
        saveSettings();
        if (typeof Theme !== "undefined")
            Theme.reloadCustomThemeVariant();
    }

    function toggleDankBarVisible() {
        const defaultBar = barConfigs[0] || getBarConfig("default");
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "visible": !defaultBar.visible
            });
        }
    }

    function toggleShowDock() {
        setShowDock(!showDock);
    }

    function getPluginSetting(pluginId, key, defaultValue) {
        if (!pluginSettings[pluginId]) {
            return defaultValue;
        }
        return pluginSettings[pluginId][key] !== undefined ? pluginSettings[pluginId][key] : defaultValue;
    }

    function setPluginSetting(pluginId, key, value) {
        const updated = JSON.parse(JSON.stringify(pluginSettings));
        if (!updated[pluginId]) {
            updated[pluginId] = {};
        }
        updated[pluginId][key] = value;
        pluginSettings = updated;
        savePluginSettings();
    }

    function removePluginSettings(pluginId) {
        if (pluginSettings[pluginId]) {
            delete pluginSettings[pluginId];
            savePluginSettings();
        }
    }

    function getPluginSettingsForPlugin(pluginId) {
        const settings = pluginSettings[pluginId];
        return settings ? JSON.parse(JSON.stringify(settings)) : {};
    }

    function getNiriOutputSetting(outputId, key, defaultValue) {
        if (!niriOutputSettings[outputId])
            return defaultValue;
        return niriOutputSettings[outputId][key] !== undefined ? niriOutputSettings[outputId][key] : defaultValue;
    }

    function setNiriOutputSetting(outputId, key, value) {
        const updated = JSON.parse(JSON.stringify(niriOutputSettings));
        if (!updated[outputId])
            updated[outputId] = {};
        updated[outputId][key] = value;
        niriOutputSettings = updated;
        saveSettings();
    }

    function getNiriOutputSettings(outputId) {
        const settings = niriOutputSettings[outputId];
        return settings ? JSON.parse(JSON.stringify(settings)) : {};
    }

    function setNiriOutputSettings(outputId, settings) {
        const updated = JSON.parse(JSON.stringify(niriOutputSettings));
        updated[outputId] = settings;
        niriOutputSettings = updated;
        saveSettings();
    }

    function removeNiriOutputSettings(outputId) {
        if (!niriOutputSettings[outputId])
            return;
        const updated = JSON.parse(JSON.stringify(niriOutputSettings));
        delete updated[outputId];
        niriOutputSettings = updated;
        saveSettings();
    }

    function getHyprlandOutputSetting(outputId, key, defaultValue) {
        if (!hyprlandOutputSettings[outputId])
            return defaultValue;
        return hyprlandOutputSettings[outputId][key] !== undefined ? hyprlandOutputSettings[outputId][key] : defaultValue;
    }

    function setHyprlandOutputSetting(outputId, key, value) {
        const updated = JSON.parse(JSON.stringify(hyprlandOutputSettings));
        if (!updated[outputId])
            updated[outputId] = {};
        updated[outputId][key] = value;
        hyprlandOutputSettings = updated;
        saveSettings();
    }

    function removeHyprlandOutputSetting(outputId, key) {
        if (!hyprlandOutputSettings[outputId] || !(key in hyprlandOutputSettings[outputId]))
            return;
        const updated = JSON.parse(JSON.stringify(hyprlandOutputSettings));
        delete updated[outputId][key];
        hyprlandOutputSettings = updated;
        saveSettings();
    }

    function getHyprlandOutputSettings(outputId) {
        const settings = hyprlandOutputSettings[outputId];
        return settings ? JSON.parse(JSON.stringify(settings)) : {};
    }

    function setHyprlandOutputSettings(outputId, settings) {
        const updated = JSON.parse(JSON.stringify(hyprlandOutputSettings));
        updated[outputId] = settings;
        hyprlandOutputSettings = updated;
        saveSettings();
    }

    function removeHyprlandOutputSettings(outputId) {
        if (!hyprlandOutputSettings[outputId])
            return;
        const updated = JSON.parse(JSON.stringify(hyprlandOutputSettings));
        delete updated[outputId];
        hyprlandOutputSettings = updated;
        saveSettings();
    }

    function getDisplayProfiles(compositor) {
        return displayProfiles[compositor] || {};
    }

    function setDisplayProfile(compositor, profileId, data) {
        const updated = JSON.parse(JSON.stringify(displayProfiles));
        if (!updated[compositor])
            updated[compositor] = {};
        updated[compositor][profileId] = data;
        displayProfiles = updated;
        saveSettings();
    }

    function removeDisplayProfile(compositor, profileId) {
        if (!displayProfiles[compositor] || !displayProfiles[compositor][profileId])
            return;
        const updated = JSON.parse(JSON.stringify(displayProfiles));
        delete updated[compositor][profileId];
        displayProfiles = updated;
        saveSettings();
    }

    function getActiveDisplayProfile(compositor) {
        return activeDisplayProfile[compositor] || "";
    }

    function setActiveDisplayProfile(compositor, profileId) {
        const updated = JSON.parse(JSON.stringify(activeDisplayProfile));
        updated[compositor] = profileId;
        activeDisplayProfile = updated;
        saveSettings();
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

    Timer {
        id: settingsFileReloadDebounce
        interval: 50
        onTriggered: settingsFile.reload()
        repeat: false
    }

    FileView {
        id: settingsFile

        path: isGreeterMode ? "" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell/settings.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            if (_selfWrite) {
                _selfWrite = false;
                return;
            }
            settingsFileReloadDebounce.restart();
        }
        onLoaded: {
            if (isGreeterMode)
                return;
            _loading = true;
            _hasUnsavedChanges = false;
            try {
                const txt = settingsFile.text();
                if (!txt || !txt.trim()) {
                    _parseError = true;
                    return;
                }
                const obj = JSON.parse(txt);
                _parseError = false;
                Store.parse(root, obj);

                if (obj.weatherLocation !== undefined)
                    _legacyWeatherLocation = obj.weatherLocation;
                if (obj.weatherCoordinates !== undefined)
                    _legacyWeatherCoordinates = obj.weatherCoordinates;
                if (obj.vpnLastConnected !== undefined && obj.vpnLastConnected !== "") {
                    _legacyVpnLastConnected = obj.vpnLastConnected;
                    SessionData.vpnLastConnected = _legacyVpnLastConnected;
                    SessionData.saveSettings();
                }

                _loadedSettingsSnapshot = JSON.stringify(Store.toJson(root));
                _hasLoaded = true;
                applyStoredTheme();
                updateCompositorCursor();
            } catch (e) {
                _parseError = true;
                const msg = e.message;
                console.error("SettingsData: Failed to reload settings.json - file will not be overwritten. Error:", msg);
                Qt.callLater(() => ToastService.showError(I18n.tr("Failed to parse settings.json"), msg));
            } finally {
                _loading = false;
            }
        }
        onLoadFailed: error => {
            if (!isGreeterMode) {
                applyStoredTheme();
            }
        }
        onSaveFailed: error => {
            root._isReadOnly = true;
            root._hasUnsavedChanges = root._checkForUnsavedChanges();
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
                parsePluginSettings(pluginSettingsFile.text());
            }
        }
        onLoadFailed: error => {
            if (!isGreeterMode) {
                pluginSettings = {};
            }
        }
    }

    property bool pluginSettingsFileExists: false

    Process {
        id: settingsWritableCheckProcess

        property string settingsPath: Paths.strip(settingsFile.path)

        command: ["sh", "-c", "[ ! -f \"" + settingsPath + "\" ] || [ -w \"" + settingsPath + "\" ] && echo 'writable' || echo 'readonly'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim();
                root._onWritableCheckComplete(result === "writable");
            }
        }
    }
}
