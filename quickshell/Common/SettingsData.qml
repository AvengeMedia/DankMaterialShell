pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import Qt.labs.folderlistmodel
import QtQuick
import "../DankCommon/Common/Shape.js" as Shape
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Common.settings
import qs.Services
import "GSettings.js" as GSettings
import "LayoutResolver.js" as LayoutResolver
import "settings/SettingsSpec.js" as Spec
import "settings/SettingsStore.js" as Store
import "../DankCommon/Common/settings/SpecUtil.js" as SpecUtil
import "settings/BarWidgetDefaults.js" as WidgetDefaults
import "settings/DockConfig.js" as DockConfig

Singleton {
    id: root
    readonly property var log: Log.scoped("SettingsData")

    readonly property int settingsConfigVersion: 28

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

    enum AnimationEffect {
        Standard,     // 0 — M3: scale-in, rises from below
        Directional,  // 1 — pure large slide, no scale
        Depth,        // 2 — medium slide with deep depth scale pop
        Fluid
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

    enum TextRenderType {
        Qt,
        Native,
        Curve
    }

    enum TextRenderQuality {
        Default,
        Low,
        Normal,
        High,
        VeryHigh
    }

    readonly property string _homeUrl: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string _configUrl: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string _configDir: Paths.strip(_configUrl)
    readonly property string pluginSettingsPath: _configDir + "/DankMaterialShell/plugin_settings.json"
    readonly property bool qtengineActive: Quickshell.env("QT_QPA_PLATFORMTHEME") === "qtengine" || Quickshell.env("QT_QPA_PLATFORMTHEME_QT6") === "qtengine"

    property bool _loading: false
    property bool _pluginSettingsLoading: false
    property bool _parseError: false
    property bool _pluginParseError: false
    property bool _hasLoaded: false
    property bool isReadOnly: false
    property var pluginSettings: ({})
    property var builtInPluginSettings: Spec.SPEC.builtInPluginSettings.def

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
        if (Store.SESSION_BACKED_PLUGIN_IDS.includes(pluginId)) {
            SessionData.setBuiltInPluginState(pluginId, updated[pluginId]);
            return;
        }
        saveSettings();
    }

    property bool clipboardClickToPaste: Spec.SPEC.clipboardClickToPaste.def
    property bool clipboardEnterToPaste: Spec.SPEC.clipboardEnterToPaste.def
    property bool clipboardRememberTypeFilter: Spec.SPEC.clipboardRememberTypeFilter.def
    property bool clipboardUseOverlayLayer: Spec.SPEC.clipboardUseOverlayLayer.def
    property string clipboardSize: Spec.SPEC.clipboardSize.def
    property string clipboardTypeFilter: Spec.SPEC.clipboardTypeFilter.def
    property var clipboardVisibleEntryActions: Spec.SPEC.clipboardVisibleEntryActions.def

    property var launcherPluginVisibility: Spec.SPEC.launcherPluginVisibility.def

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

    property var launcherPluginOrder: Spec.SPEC.launcherPluginOrder.def
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

    property string currentThemeName: Spec.SPEC.currentThemeName.def
    property string currentThemeCategory: Spec.SPEC.currentThemeCategory.def
    property string customThemeFile: Spec.SPEC.customThemeFile.def
    property var registryThemeVariants: Spec.SPEC.registryThemeVariants.def
    property string matugenScheme: Spec.SPEC.matugenScheme.def
    property bool matugenSmartMode: Spec.SPEC.matugenSmartMode.def
    property string matugenSourceMode: Spec.SPEC.matugenSourceMode.def
    property real matugenContrast: Spec.SPEC.matugenContrast.def
    property string matugenSeedColor: Spec.SPEC.matugenSeedColor.def
    property string matugenSpec: Spec.SPEC.matugenSpec.def
    property bool runUserMatugenTemplates: Spec.SPEC.runUserMatugenTemplates.def
    property string matugenTargetMonitor: Spec.SPEC.matugenTargetMonitor.def
    property real popupTransparency: Spec.SPEC.popupTransparency.def
    property bool floatingWindowSyncGlobal: Spec.SPEC.floatingWindowSyncGlobal.def
    property real floatingWindowTransparency: Spec.SPEC.floatingWindowTransparency.def
    property bool floatingWindowForegroundLayers: Spec.SPEC.floatingWindowForegroundLayers.def
    property real floatingWindowForegroundTransparency: Spec.SPEC.floatingWindowForegroundTransparency.def
    property bool dmsWindowsFloating: Spec.SPEC.dmsWindowsFloating.def
    property string widgetBackgroundColor: Spec.SPEC.widgetBackgroundColor.def
    property string widgetBackgroundCustomColor: Spec.SPEC.widgetBackgroundCustomColor.def
    property real widgetBackgroundCustomStrength: Spec.SPEC.widgetBackgroundCustomStrength.def
    property string widgetColorMode: Spec.SPEC.widgetColorMode.def
    property string controlCenterTileColorMode: Spec.SPEC.controlCenterTileColorMode.def
    property string buttonColorMode: Spec.SPEC.buttonColorMode.def
    property int radiusStrength: Spec.SPEC.radiusStrength.def
    readonly property real cornerRadius: Shape.radius("m", Shape.scaleForStrength(radiusStrength))
    property int niriLayoutGapsOverride: Spec.SPEC.niriLayoutGapsOverride.def
    property int niriLayoutRadiusOverride: Spec.SPEC.niriLayoutRadiusOverride.def
    property int niriLayoutBorderSize: Spec.SPEC.niriLayoutBorderSize.def
    property int hyprlandLayoutGapsOverride: Spec.SPEC.hyprlandLayoutGapsOverride.def
    property int hyprlandLayoutGapsOutOverride: Spec.SPEC.hyprlandLayoutGapsOutOverride.def
    property int hyprlandLayoutRadiusOverride: Spec.SPEC.hyprlandLayoutRadiusOverride.def
    property int hyprlandLayoutBorderSize: Spec.SPEC.hyprlandLayoutBorderSize.def
    property bool hyprlandResizeOnBorder: Spec.SPEC.hyprlandResizeOnBorder.def
    property string hyprlandTilingLayout: Spec.SPEC.hyprlandTilingLayout.def
    property bool hyprlandDwindlePreserveSplit: Spec.SPEC.hyprlandDwindlePreserveSplit.def
    property bool hyprlandDwindleSmartSplit: Spec.SPEC.hyprlandDwindleSmartSplit.def
    property int hyprlandDwindleForceSplit: Spec.SPEC.hyprlandDwindleForceSplit.def
    property string hyprlandMasterOrientation: Spec.SPEC.hyprlandMasterOrientation.def
    property string hyprlandMasterNewStatus: Spec.SPEC.hyprlandMasterNewStatus.def
    property bool hyprlandMasterNewOnTop: Spec.SPEC.hyprlandMasterNewOnTop.def
    property int hyprlandMasterSize: Spec.SPEC.hyprlandMasterSize.def
    property string hyprlandScrollingDirection: Spec.SPEC.hyprlandScrollingDirection.def
    property int hyprlandScrollingColumnWidth: Spec.SPEC.hyprlandScrollingColumnWidth.def
    property bool hyprlandScrollingFullscreenOneColumn: Spec.SPEC.hyprlandScrollingFullscreenOneColumn.def
    property bool hyprlandScrollingFollowFocus: Spec.SPEC.hyprlandScrollingFollowFocus.def
    property int mangoLayoutGapsOverride: Spec.SPEC.mangoLayoutGapsOverride.def
    property int mangoLayoutGapsOutOverride: Spec.SPEC.mangoLayoutGapsOutOverride.def
    property int mangoLayoutRadiusOverride: Spec.SPEC.mangoLayoutRadiusOverride.def
    property int mangoLayoutBorderSize: Spec.SPEC.mangoLayoutBorderSize.def
    property bool mangoTrackpadNaturalScrolling: Spec.SPEC.mangoTrackpadNaturalScrolling.def
    property string mouseAccelProfile: Spec.SPEC.mouseAccelProfile.def
    property real mouseAccelSpeed: Spec.SPEC.mouseAccelSpeed.def
    property bool mouseLeftHanded: Spec.SPEC.mouseLeftHanded.def
    property bool mouseMiddleEmulation: Spec.SPEC.mouseMiddleEmulation.def
    property bool mouseNaturalScroll: Spec.SPEC.mouseNaturalScroll.def
    property real mouseScrollFactor: Spec.SPEC.mouseScrollFactor.def
    property string mouseScrollMethod: Spec.SPEC.mouseScrollMethod.def
    property string touchpadAccelProfile: Spec.SPEC.touchpadAccelProfile.def
    property real touchpadAccelSpeed: Spec.SPEC.touchpadAccelSpeed.def
    property string touchpadClickMethod: Spec.SPEC.touchpadClickMethod.def
    property bool touchpadDisableOnExternalMouse: Spec.SPEC.touchpadDisableOnExternalMouse.def
    property bool touchpadDisableWhileTyping: Spec.SPEC.touchpadDisableWhileTyping.def
    property bool touchpadDragLock: Spec.SPEC.touchpadDragLock.def
    property bool touchpadMiddleEmulation: Spec.SPEC.touchpadMiddleEmulation.def
    property bool touchpadNaturalScroll: Spec.SPEC.touchpadNaturalScroll.def
    property real touchpadScrollFactor: Spec.SPEC.touchpadScrollFactor.def
    property string touchpadScrollMethod: Spec.SPEC.touchpadScrollMethod.def
    property bool touchpadTapAndDrag: Spec.SPEC.touchpadTapAndDrag.def
    property bool touchpadTapToClick: Spec.SPEC.touchpadTapToClick.def

    property string keyboardLayouts: Spec.SPEC.keyboardLayouts.def
    property string keyboardVariants: Spec.SPEC.keyboardVariants.def
    property string keyboardModel: Spec.SPEC.keyboardModel.def
    property string keyboardOptions: Spec.SPEC.keyboardOptions.def
    property string keyboardKeymapFile: Spec.SPEC.keyboardKeymapFile.def
    property string keyboardTrackLayout: Spec.SPEC.keyboardTrackLayout.def
    property int keyboardRepeatDelay: Spec.SPEC.keyboardRepeatDelay.def
    property int keyboardRepeatRate: Spec.SPEC.keyboardRepeatRate.def
    property bool keyboardNumlock: Spec.SPEC.keyboardNumlock.def

    property int firstDayOfWeek: Spec.SPEC.firstDayOfWeek.def
    property bool showWeekNumber: Spec.SPEC.showWeekNumber.def
    property string calendarBackend: Spec.SPEC.calendarBackend.def
    property string defaultTaskCalendarId: Spec.SPEC.defaultTaskCalendarId.def
    property bool audioShowStreamDevices: Spec.SPEC.audioShowStreamDevices.def
    property string clockFormat: Spec.SPEC.clockFormat.def
    readonly property bool localeUses24Hour: {
        const fmt = Qt.locale().timeFormat(Locale.ShortFormat).replace(/'[^']*'/g, "");
        return !/[aA]/.test(fmt);
    }
    readonly property bool use24HourClock: clockFormat === "24h" ? true : (clockFormat === "12h" ? false : localeUses24Hour)
    property bool showSeconds: Spec.SPEC.showSeconds.def
    property bool padHours12Hour: Spec.SPEC.padHours12Hour.def
    property bool useFahrenheit: Spec.SPEC.useFahrenheit.def
    property string windSpeedUnit: Spec.SPEC.windSpeedUnit.def
    property int animationDuration: Spec.SPEC.animationDuration.def
    property bool syncComponentAnimationSpeeds: Spec.SPEC.syncComponentAnimationSpeeds.def
    onSyncComponentAnimationSpeedsChanged: saveSettings()
    property int popoutAnimationDuration: Spec.SPEC.popoutAnimationDuration.def
    property int modalAnimationDuration: Spec.SPEC.modalAnimationDuration.def
    property bool reduceMotion: Spec.SPEC.reduceMotion.def
    onReduceMotionChanged: saveSettings()
    property int springBounce: Spec.SPEC.springBounce.def
    onSpringBounceChanged: saveSettings()
    property bool enableRippleEffects: Spec.SPEC.enableRippleEffects.def
    onEnableRippleEffectsChanged: saveSettings()
    property int motionEffect: SettingsData.AnimationEffect.Standard
    onMotionEffectChanged: saveSettings()
    property bool m3ElevationEnabled: Spec.SPEC.m3ElevationEnabled.def
    onM3ElevationEnabledChanged: saveSettings()
    property int m3ElevationIntensity: Spec.SPEC.m3ElevationIntensity.def
    onM3ElevationIntensityChanged: saveSettings()
    property int m3ElevationOpacity: Spec.SPEC.m3ElevationOpacity.def
    onM3ElevationOpacityChanged: saveSettings()
    property string m3ElevationColorMode: Spec.SPEC.m3ElevationColorMode.def
    onM3ElevationColorModeChanged: saveSettings()
    property string m3ElevationLightDirection: Spec.SPEC.m3ElevationLightDirection.def
    onM3ElevationLightDirectionChanged: saveSettings()
    property string m3ElevationCustomColor: Spec.SPEC.m3ElevationCustomColor.def
    onM3ElevationCustomColorChanged: saveSettings()
    property bool modalElevationEnabled: Spec.SPEC.modalElevationEnabled.def
    onModalElevationEnabledChanged: saveSettings()
    property bool popoutElevationEnabled: Spec.SPEC.popoutElevationEnabled.def
    onPopoutElevationEnabledChanged: saveSettings()
    property bool barElevationEnabled: Spec.SPEC.barElevationEnabled.def
    onBarElevationEnabledChanged: saveSettings()

    property bool blurEnabled: Spec.SPEC.blurEnabled.def
    onBlurEnabledChanged: saveSettings()
    property bool blurForegroundLayers: Spec.SPEC.blurForegroundLayers.def
    onBlurForegroundLayersChanged: saveSettings()
    property real foregroundLayerTransparency: Spec.SPEC.foregroundLayerTransparency.def
    property real blurLayerOutlineOpacity: Spec.SPEC.blurLayerOutlineOpacity.def
    onBlurLayerOutlineOpacityChanged: saveSettings()
    property bool blurBorderEnabled: Spec.SPEC.blurBorderEnabled.def
    onBlurBorderEnabledChanged: saveSettings()
    property string blurBorderColor: Spec.SPEC.blurBorderColor.def
    onBlurBorderColorChanged: saveSettings()
    property string blurBorderCustomColor: Spec.SPEC.blurBorderCustomColor.def
    onBlurBorderCustomColorChanged: saveSettings()
    property real blurBorderOpacity: Spec.SPEC.blurBorderOpacity.def
    onBlurBorderOpacityChanged: saveSettings()
    property bool focusRingEnabled: Spec.SPEC.focusRingEnabled.def
    property real focusRingWidth: Spec.SPEC.focusRingWidth.def
    property string focusRingColor: Spec.SPEC.focusRingColor.def
    property string wallpaperFillMode: Spec.SPEC.wallpaperFillMode.def
    property bool blurredWallpaperLayer: Spec.SPEC.blurredWallpaperLayer.def
    property bool blurWallpaperOnOverview: Spec.SPEC.blurWallpaperOnOverview.def
    property string wallpaperBackgroundColorMode: Spec.SPEC.wallpaperBackgroundColorMode.def
    property string wallpaperBackgroundCustomColor: Spec.SPEC.wallpaperBackgroundCustomColor.def
    readonly property color effectiveWallpaperBackgroundColor: wallpaperBackgroundColorFor(wallpaperBackgroundColorMode)

    function wallpaperBackgroundColorFor(mode) {
        switch (mode) {
        case "white":
            return "#ffffff";
        case "primary":
            return Theme.primary;
        case "surface":
            return Theme.surfaceContainer;
        case "custom":
            return wallpaperBackgroundCustomColor;
        default:
            return "#000000";
        }
    }

    property bool frameEnabled: Spec.SPEC.frameEnabled.def
    onFrameEnabledChanged: {
        saveSettings();
        if (!_loading)
            updateFrameCompositorLayout();
    }
    property real frameThickness: Spec.SPEC.frameThickness.def
    onFrameThicknessChanged: saveSettings()
    property int barInsetPaddingShared: Spec.SPEC.barInsetPaddingShared.def
    onBarInsetPaddingSharedChanged: saveSettings()
    property bool barInsetPaddingSyncAll: Spec.SPEC.barInsetPaddingSyncAll.def
    onBarInsetPaddingSyncAllChanged: saveSettings()
    property int frameBarInsetPadding: Spec.SPEC.frameBarInsetPadding.def
    onFrameBarInsetPaddingChanged: saveSettings()
    property real frameRounding: Spec.SPEC.frameRounding.def
    onFrameRoundingChanged: saveSettings()
    property var frameScreenPreferences: Spec.SPEC.frameScreenPreferences.def
    onFrameScreenPreferencesChanged: saveSettings()
    property real frameBarSize: Spec.SPEC.frameBarSize.def
    onFrameBarSizeChanged: saveSettings()
    property bool frameShowOnOverview: Spec.SPEC.frameShowOnOverview.def
    onFrameShowOnOverviewChanged: saveSettings()
    property bool frameBlurEnabled: Spec.SPEC.frameBlurEnabled.def
    onFrameBlurEnabledChanged: saveSettings()
    property bool frameCloseGaps: Spec.SPEC.frameCloseGaps.def
    onFrameCloseGapsChanged: saveSettings()
    property string frameLauncherEmergeSide: Spec.SPEC.frameLauncherEmergeSide.def
    onFrameLauncherEmergeSideChanged: saveSettings()
    property bool frameLauncherArcExtender: Spec.SPEC.frameLauncherArcExtender.def
    onFrameLauncherArcExtenderChanged: saveSettings()
    property bool frameLauncherEdgeHover: Spec.SPEC.frameLauncherEdgeHover.def
    onFrameLauncherEdgeHoverChanged: saveSettings()
    readonly property string frameModalEmergeSide: frameLauncherEmergeSide === "top" ? "bottom" : "top"
    property string frameMode: Spec.SPEC.frameMode.def
    onFrameModeChanged: {
        saveSettings();
        if (!_loading && frameEnabled)
            updateFrameCompositorLayout();
    }
    property var connectedFrameBarStyleBackups: Spec.SPEC.connectedFrameBarStyleBackups.def
    onConnectedFrameBarStyleBackupsChanged: saveSettings()
    readonly property bool connectedFrameModeActive: frameEnabled && frameMode === "connected"
    onConnectedFrameModeActiveChanged: {
        if (_loading)
            return;
        _reconcileConnectedFrameBarStyles();
    }

    readonly property real frameSurfaceOpacity: {
        barConfigs;
        return barTransparency(barConfigs.find(bc => bc.enabled !== false && !isIslandBarConfig(bc)));
    }

    property string systemTrayIconTintMode: Spec.SPEC.systemTrayIconTintMode.def
    property int systemTrayIconTintSaturation: Spec.SPEC.systemTrayIconTintSaturation.def
    property int systemTrayIconTintStrength: Spec.SPEC.systemTrayIconTintStrength.def

    property int controlCenterColumns: Spec.SPEC.controlCenterColumns.def
    property real controlCenterIconScale: Spec.SPEC.controlCenterIconScale.def
    property var controlCenterWidgets: Spec.SPEC.controlCenterWidgets.def

    property var workspaceNameIcons: Spec.SPEC.workspaceNameIcons.def
    property bool scrollTitleEnabled: Spec.SPEC.scrollTitleEnabled.def
    property bool audioVisualizerEnabled: Spec.SPEC.audioVisualizerEnabled.def
    property int audioWheelScrollAmount: Spec.SPEC.audioWheelScrollAmount.def
    property bool bluetoothMprisEnabled: Spec.SPEC.bluetoothMprisEnabled.def
    property var mediaExcludePlayers: Spec.SPEC.mediaExcludePlayers.def
    property var mediaLyricsProviders: Spec.SPEC.mediaLyricsProviders.def
    property var appIdSubstitutions: Spec.SPEC.appIdSubstitutions.def
    property string centeringMode: Spec.SPEC.centeringMode.def
    property string clockDateFormat: Spec.SPEC.clockDateFormat.def
    property string lockDateFormat: Spec.SPEC.lockDateFormat.def
    property bool greeterRememberLastSession: Spec.SPEC.greeterRememberLastSession.def
    property bool greeterRememberLastUser: Spec.SPEC.greeterRememberLastUser.def
    property bool greeterAutoLogin: Spec.SPEC.greeterAutoLogin.def
    property bool greeterEnableFprint: Spec.SPEC.greeterEnableFprint.def
    property bool greeterEnableU2f: Spec.SPEC.greeterEnableU2f.def

    property string browserPickerViewMode: Spec.SPEC.browserPickerViewMode.def
    property string appPickerViewMode: Spec.SPEC.appPickerViewMode.def
    property bool sortAppsAlphabetically: Spec.SPEC.sortAppsAlphabetically.def
    property int appLauncherGridColumns: Spec.SPEC.appLauncherGridColumns.def
    property bool closeNiriOverviewOnWindowFocus: Spec.SPEC.closeNiriOverviewOnWindowFocus.def
    property bool rememberLastQuery: Spec.SPEC.rememberLastQuery.def
    property bool rememberLastMode: Spec.SPEC.rememberLastMode.def
    property var spotlightSectionViewModes: Spec.SPEC.spotlightSectionViewModes.def
    onSpotlightSectionViewModesChanged: saveSettings()
    property var appDrawerSectionViewModes: Spec.SPEC.appDrawerSectionViewModes.def
    onAppDrawerSectionViewModesChanged: saveSettings()
    property bool niriOverviewOverlayEnabled: Spec.SPEC.niriOverviewOverlayEnabled.def
    property string niriOverviewLauncherStyle: Spec.SPEC.niriOverviewLauncherStyle.def
    property string dankLauncherV2Size: Spec.SPEC.dankLauncherV2Size.def
    property bool dankLauncherV2ShowSourceBadges: Spec.SPEC.dankLauncherV2ShowSourceBadges.def
    property bool dankLauncherV2BorderEnabled: Spec.SPEC.dankLauncherV2BorderEnabled.def
    property int dankLauncherV2BorderThickness: Spec.SPEC.dankLauncherV2BorderThickness.def
    property string dankLauncherV2BorderColor: Spec.SPEC.dankLauncherV2BorderColor.def
    property bool dankLauncherV2ShowFooter: Spec.SPEC.dankLauncherV2ShowFooter.def
    property bool dankLauncherV2UnloadOnClose: Spec.SPEC.dankLauncherV2UnloadOnClose.def
    property bool dankLauncherV2IncludeFilesInAll: Spec.SPEC.dankLauncherV2IncludeFilesInAll.def
    property bool dankLauncherV2IncludeFoldersInAll: Spec.SPEC.dankLauncherV2IncludeFoldersInAll.def
    property bool launcherUseOverlayLayer: Spec.SPEC.launcherUseOverlayLayer.def
    property string launcherStyle: Spec.SPEC.launcherStyle.def
    property bool spotlightBarShowModeChips: Spec.SPEC.spotlightBarShowModeChips.def
    property bool keybindsFloatingWindow: Spec.SPEC.keybindsFloatingWindow.def
    onKeybindsFloatingWindowChanged: saveSettings()

    property string _legacyWeatherLocation: "New York, NY"
    property string _legacyWeatherCoordinates: "40.7128,-74.0060"
    property string _legacyVpnLastConnected: ""
    readonly property string weatherLocation: SessionData.weatherLocation
    readonly property string weatherCoordinates: SessionData.weatherCoordinates
    property bool useAutoLocation: Spec.SPEC.useAutoLocation.def
    property bool weatherEnabled: Spec.SPEC.weatherEnabled.def

    readonly property var _dashTabsDefault: [
        {
            "id": "overview",
            "enabled": true
        },
        {
            "id": "media",
            "enabled": true
        },
        {
            "id": "wallpaper",
            "enabled": true
        },
        {
            "id": "weather",
            "enabled": true
        },
        {
            "id": "notifications",
            "enabled": false
        }
    ]
    property var dashTabs: Spec.SPEC.dashTabs.def
    onDashTabsChanged: saveSettings()

    readonly property var _dashCardsDefault: [
        {
            "id": "clock",
            "w": 2,
            "h": 1
        },
        {
            "id": "weather",
            "w": 1,
            "h": 1
        },
        {
            "id": "notifications",
            "w": 3,
            "h": 5
        },
        {
            "id": "calendar",
            "w": 3,
            "h": 3
        },
        {
            "id": "media",
            "w": 3,
            "h": 1
        }
    ]
    property var dashCards: Spec.SPEC.dashCards.def
    onDashCardsChanged: saveSettings()
    property var dashOptions: Spec.SPEC.dashOptions.def
    onDashOptionsChanged: saveSettings()

    function getDashTabs() {
        const stored = Array.isArray(dashTabs) ? dashTabs : [];
        const result = [];
        const seen = {};
        for (var i = 0; i < stored.length; i++) {
            const id = stored[i] && stored[i].id;
            if (typeof id !== "string" || id === "" || seen[id])
                continue;
            seen[id] = true;
            result.push({
                "id": id,
                "enabled": stored[i].enabled !== false
            });
        }
        for (var j = 0; j < _dashTabsDefault.length; j++) {
            if (seen[_dashTabsDefault[j].id])
                continue;
            result.push({
                "id": _dashTabsDefault[j].id,
                "enabled": _dashTabsDefault[j].enabled
            });
        }
        return result;
    }

    function setDashTabOrder(ids) {
        const current = getDashTabs();
        const ordered = [];
        for (var i = 0; i < ids.length; i++) {
            const existing = current.find(t => t.id === ids[i]);
            if (existing)
                ordered.push(existing);
        }
        for (var j = 0; j < current.length; j++) {
            if (ids.indexOf(current[j].id) < 0)
                ordered.push(current[j]);
        }
        dashTabs = ordered;
    }

    function setDashTabEnabled(id, on) {
        const current = getDashTabs();
        if (!current.some(t => t.id === id))
            current.push({
                "id": id,
                "enabled": true
            });
        dashTabs = current.map(t => t.id === id ? {
                "id": t.id,
                "enabled": on
            } : t);
    }

    function resetDashTabs() {
        dashTabs = _dashTabsDefault.map(t => ({
                    "id": t.id,
                    "enabled": t.enabled
                }));
    }

    function resetDashCards() {
        dashCards = _dashCardsDefault.map(c => ({
                    "id": c.id,
                    "w": c.w,
                    "h": c.h
                }));
        const options = Object.assign({}, dashOptions);
        delete options.overview;
        dashOptions = options;
    }

    property string networkPreference: Spec.SPEC.networkPreference.def

    property string iconThemeDark: Spec.SPEC.iconThemeDark.def
    property string iconThemeLight: Spec.SPEC.iconThemeLight.def
    property bool iconThemePerMode: Spec.SPEC.iconThemePerMode.def
    readonly property string iconTheme: resolveIconTheme()
    property var availableIconThemes: Spec.SPEC.availableIconThemes.def
    property string systemDefaultIconTheme: Spec.SPEC.systemDefaultIconTheme.def

    property var cursorSettings: Spec.SPEC.cursorSettings.def
    property var availableCursorThemes: Spec.SPEC.availableCursorThemes.def
    property string systemDefaultCursorTheme: Spec.SPEC.systemDefaultCursorTheme.def

    property string launcherLogoMode: Spec.SPEC.launcherLogoMode.def
    property string launcherLogoCustomPath: Spec.SPEC.launcherLogoCustomPath.def
    property string launcherLogoColorOverride: Spec.SPEC.launcherLogoColorOverride.def
    property bool launcherLogoColorInvertOnMode: Spec.SPEC.launcherLogoColorInvertOnMode.def
    property real launcherLogoBrightness: Spec.SPEC.launcherLogoBrightness.def
    property real launcherLogoContrast: Spec.SPEC.launcherLogoContrast.def
    property int launcherLogoSizeOffset: Spec.SPEC.launcherLogoSizeOffset.def

    property string fontFamily: Spec.SPEC.fontFamily.def
    property string monoFontFamily: Spec.SPEC.monoFontFamily.def
    property string displayFontFamily: Spec.SPEC.displayFontFamily.def
    property int fontWeight: Font.Normal
    property real fontScale: Spec.SPEC.fontScale.def
    property int textRenderType: SettingsData.TextRenderType.Qt
    property int textRenderQuality: SettingsData.TextRenderQuality.Default

    property bool notepadUseMonospace: Spec.SPEC.notepadUseMonospace.def
    property string notepadFontFamily: Spec.SPEC.notepadFontFamily.def
    property real notepadFontSize: Spec.SPEC.notepadFontSize.def
    property real notificationSummaryFontSize: Spec.SPEC.notificationSummaryFontSize.def
    property real notificationBodyFontSize: Spec.SPEC.notificationBodyFontSize.def
    property bool notepadShowLineNumbers: Spec.SPEC.notepadShowLineNumbers.def
    property bool notepadAutoSave: Spec.SPEC.notepadAutoSave.def
    property string notepadSlideoutSide: Spec.SPEC.notepadSlideoutSide.def
    property string notepadDefaultMode: Spec.SPEC.notepadDefaultMode.def
    property real notepadTransparencyOverride: Spec.SPEC.notepadTransparencyOverride.def
    property real notepadLastCustomTransparency: Spec.SPEC.notepadLastCustomTransparency.def
    property bool notepadUseCompositorGap: Spec.SPEC.notepadUseCompositorGap.def
    property int notepadEdgeGap: Spec.SPEC.notepadEdgeGap.def

    property string activeCompositor: ""

    // Compositor layout gap when enabled and available, else the manual value.
    readonly property int notepadEffectiveEdgeGap: {
        if (notepadUseCompositorGap) {
            var g = -1;
            switch (activeCompositor) {
            case "niri":
                g = niriLayoutGapsOverride;
                break;
            case "hyprland":
                g = hyprlandLayoutGapsOverride;
                break;
            case "mango":
                g = mangoLayoutGapsOverride;
                break;
            }
            if (g >= 0)
                return g;
        }
        return Math.max(0, notepadEdgeGap);
    }

    onNotepadUseMonospaceChanged: saveSettings()
    onNotepadFontFamilyChanged: saveSettings()
    onNotepadFontSizeChanged: saveSettings()
    onNotepadShowLineNumbersChanged: saveSettings()
    onNotepadAutoSaveChanged: saveSettings()
    onNotepadSlideoutSideChanged: saveSettings()
    onNotepadDefaultModeChanged: saveSettings()
    onNotepadUseCompositorGapChanged: saveSettings()
    onNotepadEdgeGapChanged: saveSettings()
    // onCenteringModeChanged: saveSettings()
    onNotepadTransparencyOverrideChanged: {
        if (notepadTransparencyOverride > 0) {
            notepadLastCustomTransparency = notepadTransparencyOverride;
        }
        saveSettings();
    }
    onNotepadLastCustomTransparencyChanged: saveSettings()

    property bool soundsEnabled: Spec.SPEC.soundsEnabled.def
    property bool useSystemSoundTheme: Spec.SPEC.useSystemSoundTheme.def
    property bool soundNewNotification: Spec.SPEC.soundNewNotification.def
    property bool soundVolumeChanged: Spec.SPEC.soundVolumeChanged.def
    property bool soundPluggedIn: Spec.SPEC.soundPluggedIn.def
    property bool soundLogin: Spec.SPEC.soundLogin.def
    property bool muteSoundsWhenMediaPlaying: Spec.SPEC.muteSoundsWhenMediaPlaying.def

    property int acMonitorTimeout: Spec.SPEC.acMonitorTimeout.def
    property int acLockTimeout: Spec.SPEC.acLockTimeout.def
    property int acSuspendTimeout: Spec.SPEC.acSuspendTimeout.def
    property int acSuspendBehavior: SettingsData.SuspendBehavior.Suspend
    property string acProfileName: Spec.SPEC.acProfileName.def
    property int acPostLockMonitorTimeout: Spec.SPEC.acPostLockMonitorTimeout.def
    property int batteryMonitorTimeout: Spec.SPEC.batteryMonitorTimeout.def
    property int batteryLockTimeout: Spec.SPEC.batteryLockTimeout.def
    property int batterySuspendTimeout: Spec.SPEC.batterySuspendTimeout.def
    property int batterySuspendBehavior: SettingsData.SuspendBehavior.Suspend
    property string batteryProfileName: Spec.SPEC.batteryProfileName.def
    property int batteryPostLockMonitorTimeout: Spec.SPEC.batteryPostLockMonitorTimeout.def
    property int batteryChargeLimit: Spec.SPEC.batteryChargeLimit.def
    property bool batteryNotifyChargeLimit: Spec.SPEC.batteryNotifyChargeLimit.def
    property int batteryCriticalThreshold: Spec.SPEC.batteryCriticalThreshold.def
    property bool batteryNotifyCritical: Spec.SPEC.batteryNotifyCritical.def
    property int batteryLowThreshold: Spec.SPEC.batteryLowThreshold.def
    property bool batteryNotifyLow: Spec.SPEC.batteryNotifyLow.def
    property int batteryChargeLimitNotificationType: Spec.SPEC.batteryChargeLimitNotificationType.def
    property int batteryLowNotificationType: Spec.SPEC.batteryLowNotificationType.def
    property int batteryCriticalNotificationType: Spec.SPEC.batteryCriticalNotificationType.def
    property bool batteryAutoPowerSaver: Spec.SPEC.batteryAutoPowerSaver.def
    property bool lowerDisplayRefreshRateOnBattery: Spec.SPEC.lowerDisplayRefreshRateOnBattery.def
    property bool lockBeforeSuspend: Spec.SPEC.lockBeforeSuspend.def
    property bool loginctlLockIntegration: Spec.SPEC.loginctlLockIntegration.def
    property bool fadeToLockEnabled: Spec.SPEC.fadeToLockEnabled.def
    property int fadeToLockGracePeriod: Spec.SPEC.fadeToLockGracePeriod.def
    property bool fadeToDpmsEnabled: Spec.SPEC.fadeToDpmsEnabled.def
    property int fadeToDpmsGracePeriod: Spec.SPEC.fadeToDpmsGracePeriod.def
    property string launchPrefix: Spec.SPEC.launchPrefix.def

    property bool syncModeWithPortal: Spec.SPEC.syncModeWithPortal.def
    property bool terminalsAlwaysDark: Spec.SPEC.terminalsAlwaysDark.def

    property string muxType: Spec.SPEC.muxType.def
    property bool muxUseCustomCommand: Spec.SPEC.muxUseCustomCommand.def
    property string muxCustomCommand: Spec.SPEC.muxCustomCommand.def
    property string muxSessionFilter: Spec.SPEC.muxSessionFilter.def

    property bool runDmsMatugenTemplates: Spec.SPEC.runDmsMatugenTemplates.def
    property bool matugenTemplateGtk: Spec.SPEC.matugenTemplateGtk.def
    property bool matugenTemplateNiri: Spec.SPEC.matugenTemplateNiri.def
    property bool matugenTemplateHyprland: Spec.SPEC.matugenTemplateHyprland.def
    property bool matugenTemplateMangowc: Spec.SPEC.matugenTemplateMangowc.def
    property bool matugenTemplateQt5ct: Spec.SPEC.matugenTemplateQt5ct.def
    property bool matugenTemplateQt6ct: Spec.SPEC.matugenTemplateQt6ct.def
    property bool matugenTemplateFcitx5: Spec.SPEC.matugenTemplateFcitx5.def
    property bool matugenTemplateQtengine: Spec.SPEC.matugenTemplateQtengine.def
    property bool matugenTemplateFirefox: Spec.SPEC.matugenTemplateFirefox.def
    property bool matugenTemplatePywalfox: Spec.SPEC.matugenTemplatePywalfox.def
    property bool matugenTemplateZenBrowser: Spec.SPEC.matugenTemplateZenBrowser.def
    property bool matugenTemplateVesktop: Spec.SPEC.matugenTemplateVesktop.def
    property bool matugenTemplateVencord: Spec.SPEC.matugenTemplateVencord.def
    property bool matugenTemplateEquibop: Spec.SPEC.matugenTemplateEquibop.def
    property bool matugenTemplateGhostty: Spec.SPEC.matugenTemplateGhostty.def
    property bool matugenTemplateKitty: Spec.SPEC.matugenTemplateKitty.def
    property bool matugenTemplateFoot: Spec.SPEC.matugenTemplateFoot.def
    property bool matugenTemplateNeovim: Spec.SPEC.matugenTemplateNeovim.def
    property bool matugenTemplateAlacritty: Spec.SPEC.matugenTemplateAlacritty.def
    property bool matugenTemplateWezterm: Spec.SPEC.matugenTemplateWezterm.def
    property bool matugenTemplateDgop: Spec.SPEC.matugenTemplateDgop.def
    property bool matugenTemplateKcolorscheme: Spec.SPEC.matugenTemplateKcolorscheme.def
    property bool matugenTemplateVscode: Spec.SPEC.matugenTemplateVscode.def
    property bool matugenTemplateEmacs: Spec.SPEC.matugenTemplateEmacs.def
    property bool matugenTemplateZed: Spec.SPEC.matugenTemplateZed.def

    property var matugenTemplateNeovimSettings: Spec.SPEC.matugenTemplateNeovimSettings.def
    property bool matugenTemplateNeovimSetBackground: Spec.SPEC.matugenTemplateNeovimSetBackground.def

    property bool notificationOverlayEnabled: Spec.SPEC.notificationOverlayEnabled.def
    property bool notificationPopupShadowEnabled: Spec.SPEC.notificationPopupShadowEnabled.def
    property bool notificationPopupPrivacyMode: Spec.SPEC.notificationPopupPrivacyMode.def
    property bool notificationPopupBodyInvokesAction: Spec.SPEC.notificationPopupBodyInvokesAction.def
    property bool notificationForegroundLayers: Spec.SPEC.notificationForegroundLayers.def
    property int overviewRows: Spec.SPEC.overviewRows.def
    property int overviewColumns: Spec.SPEC.overviewColumns.def
    property real overviewScale: Spec.SPEC.overviewScale.def

    property bool modalDarkenBackground: Spec.SPEC.modalDarkenBackground.def

    property bool lockScreenShowPowerActions: Spec.SPEC.lockScreenShowPowerActions.def
    property bool lockScreenShowSystemIcons: Spec.SPEC.lockScreenShowSystemIcons.def
    property bool lockScreenShowTime: Spec.SPEC.lockScreenShowTime.def
    property string lockScreenClockStyle: Spec.SPEC.lockScreenClockStyle.def
    property bool lockScreenShowDate: Spec.SPEC.lockScreenShowDate.def
    property bool lockScreenShowProfileImage: Spec.SPEC.lockScreenShowProfileImage.def
    property bool lockScreenShowPasswordField: Spec.SPEC.lockScreenShowPasswordField.def
    property bool lockScreenShowMediaPlayer: Spec.SPEC.lockScreenShowMediaPlayer.def
    property bool lockScreenShowWeather: Spec.SPEC.lockScreenShowWeather.def
    property bool lockScreenPowerOffMonitorsOnLock: Spec.SPEC.lockScreenPowerOffMonitorsOnLock.def
    property bool lockAtStartup: Spec.SPEC.lockAtStartup.def

    property bool enableFprint: Spec.SPEC.enableFprint.def
    property int maxFprintTries: Spec.SPEC.maxFprintTries.def
    readonly property bool fprintdAvailable: Processes.fprintdAvailable
    readonly property bool lockFingerprintCanEnable: Processes.lockFingerprintCanEnable
    readonly property bool lockFingerprintReady: Processes.lockFingerprintReady
    readonly property string lockFingerprintReason: Processes.lockFingerprintReason
    readonly property bool greeterFingerprintCanEnable: Processes.greeterFingerprintCanEnable
    readonly property bool greeterFingerprintReady: Processes.greeterFingerprintReady
    readonly property string greeterFingerprintReason: Processes.greeterFingerprintReason
    readonly property string greeterFingerprintSource: Processes.greeterFingerprintSource
    property bool enableU2f: Spec.SPEC.enableU2f.def
    property string u2fMode: Spec.SPEC.u2fMode.def
    readonly property bool u2fAvailable: Processes.u2fAvailable
    readonly property bool lockU2fCanEnable: Processes.lockU2fCanEnable
    readonly property bool lockU2fReady: Processes.lockU2fReady
    readonly property string lockU2fReason: Processes.lockU2fReason
    readonly property bool greeterU2fCanEnable: Processes.greeterU2fCanEnable
    readonly property bool greeterU2fReady: Processes.greeterU2fReady
    readonly property string greeterU2fReason: Processes.greeterU2fReason
    readonly property string greeterU2fSource: Processes.greeterU2fSource
    property string lockPamPath: Spec.SPEC.lockPamPath.def
    property bool lockPamInlineFprint: Spec.SPEC.lockPamInlineFprint.def
    property bool lockPamInlineU2f: Spec.SPEC.lockPamInlineU2f.def
    property bool lockPamExternallyManaged: Spec.SPEC.lockPamExternallyManaged.def
    property string lockU2fPamPath: Spec.SPEC.lockU2fPamPath.def
    property string lockScreenSecurityKeyShortcut: Spec.SPEC.lockScreenSecurityKeyShortcut.def
    property bool lockScreenSecurityKeyShortcutEnabled: Spec.SPEC.lockScreenSecurityKeyShortcutEnabled.def
    property bool greeterPamExternallyManaged: Spec.SPEC.greeterPamExternallyManaged.def
    property string lockScreenInactiveColor: Spec.SPEC.lockScreenInactiveColor.def
    property int lockScreenNotificationMode: Spec.SPEC.lockScreenNotificationMode.def
    property bool lockScreenVideoEnabled: Spec.SPEC.lockScreenVideoEnabled.def
    property string lockScreenVideoPath: Spec.SPEC.lockScreenVideoPath.def
    property bool lockScreenVideoCycling: Spec.SPEC.lockScreenVideoCycling.def
    property string lockScreenWallpaperPath: Spec.SPEC.lockScreenWallpaperPath.def
    property string lockScreenWallpaperFillMode: Spec.SPEC.lockScreenWallpaperFillMode.def
    property string lockScreenFontFamily: Spec.SPEC.lockScreenFontFamily.def

    property int notificationTimeoutLow: Spec.SPEC.notificationTimeoutLow.def
    property int notificationTimeoutNormal: Spec.SPEC.notificationTimeoutNormal.def
    property int notificationTimeoutCritical: Spec.SPEC.notificationTimeoutCritical.def
    property bool notificationIgnoreAppTimeout: Spec.SPEC.notificationIgnoreAppTimeout.def
    property bool notificationCompactMode: Spec.SPEC.notificationCompactMode.def
    property bool notificationShowTimeoutBar: Spec.SPEC.notificationShowTimeoutBar.def
    property bool notificationDedupeEnabled: Spec.SPEC.notificationDedupeEnabled.def
    property int notificationPopupPosition: SettingsData.Position.Top
    property int notificationAnimationDuration: Spec.SPEC.notificationAnimationDuration.def
    property bool notificationHistoryEnabled: Spec.SPEC.notificationHistoryEnabled.def
    property int notificationHistoryMaxCount: Spec.SPEC.notificationHistoryMaxCount.def
    property int notificationHistoryMaxAgeDays: Spec.SPEC.notificationHistoryMaxAgeDays.def
    property bool notificationHistorySaveLow: Spec.SPEC.notificationHistorySaveLow.def
    property bool notificationHistorySaveNormal: Spec.SPEC.notificationHistorySaveNormal.def
    property bool notificationHistorySaveCritical: Spec.SPEC.notificationHistorySaveCritical.def
    property var notificationRules: Spec.SPEC.notificationRules.def
    property bool notificationDndAllowCritical: Spec.SPEC.notificationDndAllowCritical.def
    property bool notificationDndWhileScreenSharing: Spec.SPEC.notificationDndWhileScreenSharing.def
    property bool notificationFocusedMonitor: Spec.SPEC.notificationFocusedMonitor.def
    readonly property var islandBarConfigs: {
        barConfigs;
        return (barConfigs || []).filter(cfg => cfg && cfg.island === true);
    }
    readonly property bool dankIslandEnabled: islandBarConfigs.some(cfg => cfg.enabled ?? false)
    readonly property var islandDefaults: ({
            "islandFloating": false,
            "islandUseOverlayLayer": false,
            "islandReserveThickness": 40,
            "islandCompactThickness": 38,
            "islandOuterGap": 4,
            "islandAlongOffset": 0,
            "islandInteractionMode": "hybrid",
            "islandHoverOpenDelay": 150,
            "islandHoverCloseDelay": 150,
            "islandPalette": "default",
            "islandHighContrast": false,
            "islandMediaClockVisible": true,
            "islandNotificationBadgeClearOnOpen": false,
            "islandNotificationExpand": false,
            "islandNotificationPopups": false,
            "islandHomeCompactTight": false,
            "islandHomeClockDisplay": "both",
            "islandHomeVolumeDisplay": "both",
            "islandHomeBrightnessDisplay": "both",
            "islandHomeStatusContent": "battery",
            "islandBatteryStyle": "solid",
            "islandSatellitesEnabled": true,
            "islandSatellitePosition": "edges",
            "islandSatelliteGap": 12,
            "islandSatelliteBackground": false,
            "islandSatelliteGothCorners": true,
            "islandSatelliteTransparency": 1,
            "islandSatelliteSwoopRadius": 24,
            "islandReducedMotion": false,
            "islandSpringStiffness": 560,
            "islandSpringDamping": 37,
            "islandSpringMass": 1
        })

    function islandSetting(bc, key) {
        const value = bc?.[key];
        return value === undefined || value === null ? islandDefaults[key] : value;
    }

    function islandLevelDisplay(bc, key) {
        const value = islandSetting(bc, key);
        return value === "icon" || value === "percentage" || value === "both" ? value : "both";
    }

    function islandClockDisplay(bc) {
        const value = islandSetting(bc, "islandHomeClockDisplay");
        return value === "time" || value === "date" || value === "both" ? value : "both";
    }

    function islandHomeStatusContent(bc) {
        const value = islandSetting(bc, "islandHomeStatusContent");
        return value === "battery" || value === "connectivity" ? value : "battery";
    }

    function islandEdge(bc) {
        return positionToSide(bc?.position ?? SettingsData.Position.Top) || "top";
    }

    function islandVertical(bc) {
        const edge = islandEdge(bc);
        return edge === "left" || edge === "right";
    }

    function islandStripThickness(bc) {
        return LayoutResolver.islandThickness(bc, islandDefaults);
    }
    readonly property var _islandHomeGroupIds: ["media", "clock", "weather", "status", "volume", "brightness", "notifications"]
    readonly property var _islandHomeLayoutDefault: [
        {
            "id": "media",
            "enabled": true
        },
        {
            "id": "clock",
            "enabled": true
        },
        {
            "id": "weather",
            "enabled": false
        },
        {
            "id": "status",
            "enabled": false
        },
        {
            "id": "volume",
            "enabled": false
        },
        {
            "id": "brightness",
            "enabled": false
        },
        {
            "id": "notifications",
            "enabled": true
        }
    ]
    function getIslandHomeLayout(bc) {
        const stored = Array.isArray(bc?.islandHomeLayout) ? bc.islandHomeLayout : [];
        const result = [];
        const seen = {};
        for (const entry of stored) {
            const id = entry && entry.id;
            if (_islandHomeGroupIds.indexOf(id) < 0 || seen[id])
                continue;
            seen[id] = true;
            result.push({
                "id": id,
                "enabled": id === "clock" || entry.enabled !== false
            });
        }
        for (const fallback of _islandHomeLayoutDefault) {
            if (!seen[fallback.id])
                result.push({
                    "id": fallback.id,
                    "enabled": fallback.enabled
                });
        }
        return result;
    }

    function islandHomeGroupEnabled(bc, id) {
        const entry = getIslandHomeLayout(bc).find(g => g.id === id);
        return entry ? entry.enabled : false;
    }

    function setIslandHomeLayoutOrder(barId, ids) {
        const current = getIslandHomeLayout(getBarConfig(barId));
        const ordered = ids.map(id => current.find(g => g.id === id)).filter(g => g);
        for (const entry of current) {
            if (ids.indexOf(entry.id) < 0)
                ordered.push(entry);
        }
        updateBarConfig(barId, {
            islandHomeLayout: ordered
        });
    }

    function setIslandHomeGroupEnabled(barId, id, on) {
        if (id === "clock")
            return;
        updateBarConfig(barId, {
            islandHomeLayout: getIslandHomeLayout(getBarConfig(barId)).map(g => g.id === id ? {
                    "id": g.id,
                    "enabled": on
                } : g)
        });
    }

    property bool osdAlwaysShowValue: Spec.SPEC.osdAlwaysShowValue.def
    property int osdPosition: SettingsData.Position.BottomCenter
    property bool osdVolumeEnabled: Spec.SPEC.osdVolumeEnabled.def
    property bool osdMediaVolumeEnabled: Spec.SPEC.osdMediaVolumeEnabled.def
    property bool osdMediaPlaybackEnabled: Spec.SPEC.osdMediaPlaybackEnabled.def
    property bool osdBrightnessEnabled: Spec.SPEC.osdBrightnessEnabled.def
    property bool osdIdleInhibitorEnabled: Spec.SPEC.osdIdleInhibitorEnabled.def
    property bool osdMicMuteEnabled: Spec.SPEC.osdMicMuteEnabled.def
    property bool osdMicVolumeEnabled: Spec.SPEC.osdMicVolumeEnabled.def
    property bool osdCapsLockEnabled: Spec.SPEC.osdCapsLockEnabled.def
    property bool osdPowerProfileEnabled: Spec.SPEC.osdPowerProfileEnabled.def
    property bool osdAudioOutputEnabled: Spec.SPEC.osdAudioOutputEnabled.def
    property bool osdWorkspaceEnabled: Spec.SPEC.osdWorkspaceEnabled.def

    property bool powerActionConfirm: Spec.SPEC.powerActionConfirm.def
    property real powerActionHoldDuration: Spec.SPEC.powerActionHoldDuration.def
    property var powerMenuActions: Spec.SPEC.powerMenuActions.def
    property string powerMenuDefaultAction: Spec.SPEC.powerMenuDefaultAction.def
    property bool powerMenuGridLayout: Spec.SPEC.powerMenuGridLayout.def
    property string customPowerActionLock: Spec.SPEC.customPowerActionLock.def
    property string customPowerActionLogout: Spec.SPEC.customPowerActionLogout.def
    property string customPowerActionSuspend: Spec.SPEC.customPowerActionSuspend.def
    property string customPowerActionHibernate: Spec.SPEC.customPowerActionHibernate.def
    property string customPowerActionReboot: Spec.SPEC.customPowerActionReboot.def
    property string customPowerActionPowerOff: Spec.SPEC.customPowerActionPowerOff.def
    property var customPowerButtons: Spec.SPEC.customPowerButtons.def

    property bool updaterCheckOnStart: Spec.SPEC.updaterCheckOnStart.def
    property bool updaterUseCustomCommand: Spec.SPEC.updaterUseCustomCommand.def
    property string updaterCustomCommand: Spec.SPEC.updaterCustomCommand.def
    property string updaterTerminalAdditionalParams: Spec.SPEC.updaterTerminalAdditionalParams.def
    property int updaterIntervalSeconds: Spec.SPEC.updaterIntervalSeconds.def
    property bool updaterIncludeFlatpak: Spec.SPEC.updaterIncludeFlatpak.def
    property bool updaterAllowAUR: Spec.SPEC.updaterAllowAUR.def
    property bool updaterReopenAfterUpgrade: Spec.SPEC.updaterReopenAfterUpgrade.def
    property var updaterIgnoredPackages: Spec.SPEC.updaterIgnoredPackages.def

    property string displayNameMode: Spec.SPEC.displayNameMode.def
    property var screenPreferences: Spec.SPEC.screenPreferences.def
    property var showOnLastDisplay: Spec.SPEC.showOnLastDisplay.def
    property var displayProfiles: Spec.SPEC.displayProfiles.def
    property var displayPreviousRefreshModes: Spec.SPEC.displayPreviousRefreshModes.def
    property bool displayProfileAutoSelect: Spec.SPEC.displayProfileAutoSelect.def
    property bool displayShowDisconnected: Spec.SPEC.displayShowDisconnected.def
    property bool displaySnapToEdge: Spec.SPEC.displaySnapToEdge.def
    property var barIpcRevealStates: ({})

    property var dockConfigs: Spec.SPEC.dockConfigs.def
    property var barConfigs: Spec.SPEC.barConfigs.def

    property var desktopWidgetInstances: Spec.SPEC.desktopWidgetInstances.def
    property var desktopWidgetGroups: Spec.SPEC.desktopWidgetGroups.def

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
            config: config || {}
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

    function removeDesktopWidgetInstance(instanceId) {
        const instances = (desktopWidgetInstances || []).filter(inst => inst.id !== instanceId);
        desktopWidgetInstances = instances;
        SessionData.removeDesktopWidgetInstancePositions(instanceId);
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
            config: JSON.parse(JSON.stringify(source.config || {}))
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

    function moveDesktopWidgetInstanceToGroup(instanceId, groupId, newIndexInGroup) {
        const instances = JSON.parse(JSON.stringify(desktopWidgetInstances || []));
        const groups = desktopWidgetGroups || [];
        const idx = instances.findIndex(inst => inst.id === instanceId);
        if (idx === -1)
            return false;
        const [item] = instances.splice(idx, 1);
        item.group = groupId || null;
        const groupMatches = inst => {
            if (!groupId)
                return !inst.group || !groups.some(g => g.id === inst.group);
            return inst.group === groupId;
        };
        const groupInstances = instances.filter(groupMatches);
        const clamped = Math.max(0, Math.min(newIndexInGroup, groupInstances.length));
        let targetGlobalIdx;
        if (clamped >= groupInstances.length) {
            const last = groupInstances[groupInstances.length - 1];
            targetGlobalIdx = last ? instances.findIndex(inst => inst.id === last.id) + 1 : instances.length;
        } else {
            const targetInstance = groupInstances[clamped];
            targetGlobalIdx = instances.findIndex(inst => inst.id === targetInstance.id);
        }
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

    signal forceDankBarLayoutRefresh
    signal forceDockLayoutRefresh
    signal widgetDataChanged
    signal workspaceIconsUpdated
    signal compositorLayoutRefreshNeeded(bool frame)
    signal compositorInputRefreshNeeded
    signal compositorCursorRefreshNeeded
    signal notificationPopupsInvalidated

    function refreshAuthAvailability() {
        if (isGreeterMode)
            return;
        Processes.detectAuthCapabilities();
    }

    function _runStartSequence() {
        Processes.settingsRoot = root;
        const unsaved = _loadSettings();
        initializeListModels();
        refreshAuthAvailability();
        Processes.checkPluginSettings();
        return unsaved;
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
        compositorLayoutRefreshNeeded(false);
    }

    function updateCompositorInput() {
        compositorInputRefreshNeeded();
    }

    function updateFrameCompositorLayout() {
        compositorLayoutRefreshNeeded(true);
        FrameTransitionState.begin();
    }

    function resolveIconTheme() {
        if (iconThemePerMode && typeof SessionData !== "undefined" && SessionData.isLightMode)
            return iconThemeLight;
        return iconThemeDark;
    }

    function applyStoredIconTheme() {
        updateGtkIconTheme();
        updateQtIconTheme();
        updateCosmicIconTheme();
    }

    function setIconThemeUnmanaged() {
        iconThemePerMode = false;
        iconThemeDark = "System Default";
        iconThemeLight = "System Default";
        SessionData.lastAppliedIconTheme = "";
        SessionData.saveSettings();
        saveSettings();
    }

    function checkIconThemeDrift() {
        if (isGreeterMode)
            return;
        if (resolveIconTheme() === "System Default")
            return;
        if (!SessionData.lastAppliedIconTheme)
            return;
        const script = GSettings.getCmd("org.gnome.desktop.interface", "icon-theme");

        Proc.runCommand("iconThemeDriftCheck", ["sh", "-c", script], (output, exitCode) => {
            const platform = (output || "").trim();
            if (!platform)
                return;
            if (platform === SessionData.lastAppliedIconTheme || platform === root.iconThemeDark || platform === root.iconThemeLight)
                return;
            root.setIconThemeUnmanaged();
            ToastService.showWarning(I18n.tr("Icon theme changed outside DMS; switched to System Default", "shown when an external tool overrides the icon theme DMS applied"));
        });
    }

    Connections {
        target: typeof SessionData !== "undefined" ? SessionData : null
        function onIsLightModeChanged() {
            if (!SessionData.isSwitchingMode)
                return;
            if (!root.iconThemePerMode)
                return;
            if (root.iconThemeLight === root.iconThemeDark)
                return;
            root.applyStoredIconTheme();
            root.saveSettings();
        }
    }

    function cosmicIntegrationAvailable() {
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toUpperCase();
        return desktop.includes("COSMIC");
    }

    function updateCosmicIconTheme() {
        if (!cosmicIntegrationAvailable())
            return;
        const resolved = resolveIconTheme();
        let cosmicThemeName = (resolved === "System Default") ? systemDefaultIconTheme : resolved;
        if (!cosmicThemeName || cosmicThemeName === "System Default") {
            const detectScript = GSettings.getCmd("org.gnome.desktop.interface", "icon-theme");

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
        if (!cosmicIntegrationAvailable())
            return;
        const isDark = isLightMode ? "false" : "true";
        const script = `mkdir -p ${_configDir}/cosmic/com.system76.CosmicTheme.Mode/v1
        printf '%s\\n' ${isDark} > ${_configDir}/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark 2>/dev/null || true`;
        Quickshell.execDetached(["sh", "-lc", script]);
    }

    function updateGtkIconTheme() {
        const resolved = resolveIconTheme();
        const gtkThemeName = (resolved === "System Default") ? systemDefaultIconTheme : resolved;
        if (gtkThemeName === "System Default" || gtkThemeName === "")
            return;
        SessionData.lastAppliedIconTheme = gtkThemeName;
        SessionData.saveSettings();
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

        ${GSettings.setCmd("org.gnome.desktop.interface", "icon-theme", gtkThemeName)} || true

        pkill -HUP -f 'gtk' 2>/dev/null || true`;

        Quickshell.execDetached(["sh", "-lc", configScript]);
    }

    function updateQtIconTheme() {
        const resolved = resolveIconTheme();
        const qtThemeName = (resolved === "System Default") ? "" : resolved;
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

        if (!qtengineActive || !runDmsMatugenTemplates || !matugenTemplateQtengine)
            return;
        Proc.runCommand("updateQtengineIconTheme", [Proc.dmsBin, "matugen", "qtengine", "--icon-theme", qtThemeName], () => {});
    }

    function scheduleAuthApply() {
        if (isGreeterMode)
            return;
        Qt.callLater(() => {
            Processes.settingsRoot = root;
            Processes.scheduleAuthApply();
        });
    }

    function scheduleGreeterAutoLoginSync() {
        if (isGreeterMode)
            return;
        Qt.callLater(() => {
            Processes.settingsRoot = root;
            Processes.scheduleGreeterAutoLoginSync();
        });
    }

    function markGreeterSyncPending(who, key, oldValue) {
        if (isGreeterMode)
            return;
        if (!(key in SessionData.greeterSyncBaseline)) {
            var baseline = Object.assign({}, SessionData.greeterSyncBaseline);
            baseline[key] = oldValue;
            SessionData.greeterSyncBaseline = baseline;
        }
        SessionData.greeterSyncPending = true;
        SessionData.saveSettings();
    }

    function clearGreeterSyncPending() {
        SessionData.greeterSyncBaseline = {};
        SessionData.greeterSyncPending = false;
        SessionData.saveSettings();
    }

    function revertGreeterSyncPending() {
        for (var key in SessionData.greeterSyncBaseline) {
            if (!(key in Spec.SPEC))
                continue;
            root[key] = SessionData.greeterSyncBaseline[key];
        }
        SessionData.greeterSyncBaseline = {};
        SessionData.greeterSyncPending = false;
        SessionData.saveSettings();
        saveSettings();
    }

    readonly property var _hooks: ({
            "applyStoredTheme": applyStoredTheme,
            "regenSystemThemes": regenSystemThemes,
            "updateCompositorLayout": updateCompositorLayout,
            "updateCompositorInput": updateCompositorInput,
            "applyStoredIconTheme": applyStoredIconTheme,
            "updateBarConfigs": updateBarConfigs,
            "updateCompositorCursor": updateCompositorCursor,
            "scheduleAuthApply": scheduleAuthApply,
            "scheduleGreeterAutoLoginSync": scheduleGreeterAutoLoginSync,
            "markGreeterSyncPending": markGreeterSyncPending
        })

    function set(key, value) {
        if (key === "cornerRadius") {
            setCornerRadius(value);
            return;
        }
        if (key === "radiusStrength")
            value = Shape.normalizeStrength(value);
        Spec.set(root, key, value, saveSettings, _hooks);
        if (key === "frameEnabled" && value)
            clearIslandBars();
    }

    function hasSetting(key) {
        return key in Spec.SPEC;
    }

    function specDefault(key) {
        return SpecUtil.cloneDef(Spec.SPEC[key]?.def);
    }

    function isDefault(keys) {
        return keys.every(key => !(key in Spec.SPEC) || SpecUtil.isDefault(root[key], Spec.SPEC[key].def));
    }

    function resetToDefault(keys) {
        for (const key of keys) {
            if (key in Spec.SPEC)
                Spec.set(root, key, null, saveSettings, _hooks);
        }
    }

    function barConfigDefault(field) {
        return Spec.SPEC.barConfigs.def[0][field];
    }

    function dockConfigDefaults() {
        return DockConfig.create("", "");
    }

    // Frame mode hosts bars inside the frame surface, which has nowhere to put an island.
    function clearIslandBars() {
        const islands = islandBarConfigs;
        if (islands.length === 0)
            return;
        const configs = JSON.parse(JSON.stringify(barConfigs));
        for (const cfg of configs)
            delete cfg.island;
        barConfigs = configs;
        updateBarConfigs();
    }

    function _loadSettings() {
        const isInitial = !_hasLoaded;
        let unsavedChanges;

        let obj = _getSettingsObjectFromFiles();
        let loadedSettings = JSON.stringify(obj);

        if (isInitial) {
            const oldVersion = obj?.configVersion ?? 0;
            const legacyPins = oldVersion < 13 ? Store.extractPins(obj) : null;
            const sessionPayload = oldVersion < 15 ? Store.extractSessionPayload(obj) : null;
            const cachePayload = oldVersion < 15 ? Store.extractCachePayload(obj) : null;
            if (oldVersion < settingsConfigVersion) {
                const migrated = Store.migrateToVersion(obj, settingsConfigVersion);
                if (migrated) {
                    obj = migrated;
                }
            }

            if (legacyPins) {
                Qt.callLater(() => CacheData.migratePins(legacyPins));
            }
            if (cachePayload) {
                Qt.callLater(() => CacheData.migrateUsageHistories(cachePayload));
            } if (sessionPayload) {
                Qt.callLater(() => {
                    SessionData.importFromSettings(sessionPayload);
                    _mergeSessionState();
                });
            }

            if (obj?.lockScreenActiveMonitor !== undefined) {
                var oldVal = obj.lockScreenActiveMonitor;
                if (oldVal && oldVal !== "all") {
                    if (!obj.screenPreferences) {
                        obj.screenPreferences = {};
                    }
                    if (obj.screenPreferences.lockScreen === undefined) {
                        obj.screenPreferences.lockScreen = [oldVal];
                    }
                }
                delete obj.lockScreenActiveMonitor;
            }

            if (obj?.use24HourClock !== undefined && obj?.clockFormat === undefined) {
                obj.clockFormat = obj.use24HourClock ? "24h" : "12h";
                delete obj.use24HourClock;
            }
        }

        const prevFrameEnabled = frameEnabled;
        const prevFrameMode = frameMode;
        unsavedChanges = loadedSettings !== JSON.stringify(obj);
        Store.parse(root, obj);

        // set() enforces this pair, but a hand-edited settings.json bypasses set() entirely.
        if (frameEnabled && islandBarConfigs.length > 0)
            clearIslandBars();

        if (obj?.directionalAnimationMode === 3 && frameMode !== "connected")
            frameMode = "connected";

        if (obj?.iconTheme !== undefined && obj?.iconThemeDark === undefined)
            iconThemeDark = obj.iconTheme;

        if (obj?.weatherLocation !== undefined)
            _legacyWeatherLocation = obj.weatherLocation;
        if (obj?.weatherCoordinates !== undefined)
            _legacyWeatherCoordinates = obj.weatherCoordinates;
        if (obj.vpnLastConnected !== undefined && obj.vpnLastConnected !== "") {
            _legacyVpnLastConnected = obj.vpnLastConnected;
            SessionData.vpnLastConnected = _legacyVpnLastConnected;
            SessionData.saveSettings();
        }

        _hasLoaded = true;

        if (isInitial) {
            _mergeSessionState();
            Qt.callLater(checkIconThemeDrift);
        }
        applyStoredTheme();
        updateCompositorCursor();
        if (!isInitial) {
            // External edits reload under _loading, which skips the per-property transition triggers
            const frameChanged = (frameEnabled !== prevFrameEnabled || (frameEnabled && frameMode !== prevFrameMode));
            if (!_parseError && frameChanged) {
                updateFrameCompositorLayout();
            }
        }

        if (isInitial) {
            loadPluginSettings();
            Qt.callLater(() => _reconcileConnectedFrameBarStyles());
        }
        return unsavedChanges;
    }

    function _mergeSessionState() {
        if (!_hasLoaded || !SessionData._hasLoaded)
            return;

        const pluginState = SessionData.builtInPluginState || {};
        if (Object.keys(pluginState).length > 0) {
            const updated = JSON.parse(JSON.stringify(builtInPluginSettings));
            for (const id in pluginState) {
                updated[id] = pluginState[id];
            }
            builtInPluginSettings = updated;
        }
    }

    Connections {
        target: SessionData

        function onLoaded() {
            root._mergeSessionState();
        }
    }

    function _getCurrentSettings() {
        const setKeys = new Set();
        for (const path of _settingsFilesPaths) {
            const file = _settingsFiles.get(path);
            for (const key in file.settings) {
                setKeys.add(key);
            }
        }
        return Store.toJson(root, setKeys);
    }
    function getCurrentSettingsJson() {
        return JSON.stringify(_getCurrentSettings(), null, 2);
    }

    function _resetPluginSettings() {
        _pluginParseError = false;
        pluginSettings = {};
    }

    function _pluginSettingsErrorCode(error) {
        if (typeof error === "number")
            return error;
        if (error && typeof error === "object") {
            if (typeof error.code === "number")
                return error.code;
            if (typeof error.errno === "number")
                return error.errno;
        }

        const msg = String(error || "").trim();
        if (/^\d+$/.test(msg))
            return Number(msg);

        return -1;
    }

    function _isMissingPluginSettingsError(error) {
        if (_pluginSettingsErrorCode(error) === 2)
            return true;

        const msg = String(error || "").toLowerCase();
        return msg.indexOf("file does not exist") !== -1 || msg.indexOf("no such file") !== -1 || msg.indexOf("enoent") !== -1;
    }

    function loadPluginSettings() {
        try {
            parsePluginSettings(pluginSettingsFile.text());
        } catch (e) {
            const msg = e.message || String(e);
            if (!_isMissingPluginSettingsError(e))
                log.warn("Failed to load plugin_settings.json. Error:", msg);
            _resetPluginSettings();
        }
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
            log.error("Failed to parse plugin_settings.json - file will not be overwritten. Error:", msg);
            Qt.callLater(() => ToastService.showError(I18n.tr("Failed to parse %1").arg("plugin_settings.json"), msg));
            pluginSettings = {};
        } finally {
            _pluginSettingsLoading = false;
        }
    }

    function _splitSettingsByFile(settings) {
        const savedSettings = new Set();
        const splitSettings = {};

        for (let i = _settingsFilesPaths.length - 1; i >= 0; i--) {
            const path = _settingsFilesPaths[i];
            const file = _settingsFiles.get(path);
            const fileSettings = file.getSettings();
            for (const setting in fileSettings) {
                if (!(setting in settings)) {
                    delete fileSettings[setting];
                    continue;
                }
                if (savedSettings.has(setting)) {
                    continue;
                }
                fileSettings[setting] = settings[setting];
                savedSettings.add(setting);
            }
            splitSettings[path] = fileSettings;
        }

        for (const setting in settings) {
            if (!savedSettings.has(setting)) {
                splitSettings[defaultSettingsFile.filePath][setting] = settings[setting];
            }
        }
        return splitSettings;
    }
    function saveSettings() {
        if (isGreeterMode || _loading || !_hasLoaded)
            return;
        settingsSaveDebounce.restart();
    }
    function _saveSettings() {
        let reason = null;
        if (isGreeterMode) {
            reason = "running in greeter mode."
        } else if (_loading) {
            reason = "some files are being loaded";
        } else if (_parseError) {
            reason = "failed to parse settings.";
        }
        if (reason !== null) {
            log.warn("Refusing to save settings, recent changes may be lost: " + reason);
            return;
        }
        const settings = _getCurrentSettings();
        const splitSettings = _splitSettingsByFile(settings);
        for (const path in splitSettings) {
            const fileSettings = splitSettings[path];
            const file = _settingsFiles.get(path);
            file.setSettings(fileSettings);
        }
    }

    function savePluginSettings() {
        if (isGreeterMode || _pluginSettingsLoading || _pluginParseError)
            return;
        pluginSettingsFile.setText(JSON.stringify(pluginSettings, null, 2));
    }

    function _connectedFrameBarStyleSnapshot(config) {
        return {
            "shadowIntensity": config?.shadowIntensity ?? 0,
            "squareCorners": config?.squareCorners ?? false,
            "attachToScreenEdge": config?.attachToScreenEdge ?? false,
            "gothCornersEnabled": config?.gothCornersEnabled ?? false,
            "borderEnabled": config?.borderEnabled ?? false
        };
    }

    function _hasConnectedFrameBarStyleBackups() {
        return connectedFrameBarStyleBackups && Object.keys(connectedFrameBarStyleBackups).length > 0;
    }

    function _captureConnectedFrameBarStyleBackups(configs, overwriteExisting) {
        if (!Array.isArray(configs))
            return;

        const nextBackups = JSON.parse(JSON.stringify(connectedFrameBarStyleBackups || {}));
        const validIds = {};
        let changed = false;

        for (let i = 0; i < configs.length; i++) {
            const config = configs[i];
            if (!config?.id)
                continue;
            validIds[config.id] = true;

            if (!overwriteExisting && nextBackups[config.id] !== undefined)
                continue;

            const snapshot = _connectedFrameBarStyleSnapshot(config);
            if (JSON.stringify(nextBackups[config.id]) !== JSON.stringify(snapshot)) {
                nextBackups[config.id] = snapshot;
                changed = true;
            }
        }

        if (overwriteExisting) {
            for (const barId in nextBackups) {
                if (validIds[barId])
                    continue;
                delete nextBackups[barId];
                changed = true;
            }
        }

        if (changed)
            connectedFrameBarStyleBackups = nextBackups;
    }

    function _restoreConnectedFrameBarStyleBackups() {
        if (!_hasConnectedFrameBarStyleBackups())
            return;

        const backups = connectedFrameBarStyleBackups || {};
        const configs = JSON.parse(JSON.stringify(barConfigs));
        let changed = false;

        for (let i = 0; i < configs.length; i++) {
            const backup = backups[configs[i].id];
            if (!backup)
                continue;
            for (const key in backup) {
                if (configs[i][key] === backup[key])
                    continue;
                configs[i][key] = backup[key];
                changed = true;
            }
        }

        if (changed)
            barConfigs = configs;
        connectedFrameBarStyleBackups = ({});
        if (changed)
            updateBarConfigs();
    }

    // Zeroes out connected-mode-hostile fields (shadow, square/goth corners, edge attach, border).
    // Returns { configs, changed } — `configs` is the same ref when no change.
    function _sanitizeBarConfigsForConnectedFrame(configs) {
        if (!connectedFrameModeActive || !Array.isArray(configs))
            return {
                "configs": configs,
                "changed": false
            };

        let anyChanged = false;
        const out = configs.map(cfg => {
            if (!cfg)
                return cfg;
            let dirty = false;
            const s = Object.assign({}, cfg);
            if ((s.shadowIntensity ?? 0) !== 0) {
                s.shadowIntensity = 0;
                dirty = true;
            }
            if (s.squareCorners ?? false) {
                s.squareCorners = false;
                dirty = true;
            }
            if (s.attachToScreenEdge ?? false) {
                s.attachToScreenEdge = false;
                dirty = true;
            }
            if (s.gothCornersEnabled ?? false) {
                s.gothCornersEnabled = false;
                dirty = true;
            }
            if (s.borderEnabled ?? false) {
                s.borderEnabled = false;
                dirty = true;
            }
            if (dirty)
                anyChanged = true;
            return dirty ? s : cfg;
        });
        return {
            "configs": anyChanged ? out : configs,
            "changed": anyChanged
        };
    }

    function effectiveBarConfigForRender(config, usesFrameBarChrome) {
        if (!config || !connectedFrameModeActive || usesFrameBarChrome)
            return config;
        const backup = connectedFrameBarStyleBackups[config.id];
        if (!backup)
            return config;
        return Object.assign({}, config, backup);
    }

    // Single entry point for connected-mode settings state.
    //   !active → restore backups
    function _reconcileConnectedFrameBarStyles() {
        if (!connectedFrameModeActive) {
            _restoreConnectedFrameBarStyleBackups();
            return;
        }
        if (!_hasConnectedFrameBarStyleBackups())
            _captureConnectedFrameBarStyleBackups(barConfigs, true);
        const result = _sanitizeBarConfigsForConnectedFrame(barConfigs);
        if (result.changed) {
            barConfigs = result.configs;
            updateBarConfigs();
        }
    }

    function detectAvailableIconThemes() {
        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS") || "";
        const localData = Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation));
        const homeDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation));

        const dataDirs = xdgDataDirs.trim() !== "" ? xdgDataDirs.split(":").concat([localData]) : ["/usr/share", "/usr/local/share", localData];

        const iconPaths = dataDirs.map(d => d + "/icons").concat([homeDir + "/.icons"]);
        const pathsArg = iconPaths.join(" ");

        const script = `
            echo "SYSDEFAULT:$(${GSettings.getCmd("org.gnome.desktop.interface", "icon-theme")})"
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
            echo "SYSDEFAULT:$(${GSettings.getCmd("org.gnome.desktop.interface", "cursor-theme")})"
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

    function getEffectiveDateFormat(fallback) {
        if (clockDateFormat && clockDateFormat.length > 0)
            return clockDateFormat;
        return fallback || "ddd d";
    }

    function initializeListModels() {
        const defaultBar = getPrimaryBarConfig();
        if (defaultBar) {
            Lists.init(leftWidgetsModel, centerWidgetsModel, rightWidgetsModel, defaultBar.leftWidgets, defaultBar.centerWidgets, defaultBar.rightWidgets);
        }
    }

    function updateListModel(listModel, order) {
        Lists.update(listModel, order);
        widgetDataChanged();
    }

    function getPopupTriggerPosition(pos, screen, barThickness, widgetWidth, barSpacing, barPosition, barConfig) {
        return ShellLayout.popupTrigger(pos, screen, barThickness, widgetWidth, barSpacing, barPosition, barConfig);
    }

    function getAdjacentBarInfo(screen, barPosition, barConfig) {
        return ShellLayout.adjacentInfo(screen, barConfig);
    }

    function getBarBounds(screen, barThickness, barPosition, barConfig) {
        return ShellLayout.barBounds(screen, barThickness, barPosition, barConfig);
    }

    function updateBarConfigs() {
        barConfigsChanged();
        saveSettings();
    }

    // Each screen edge can hold one dock, so resolution and reservation are always edge-scoped.
    function dockConfigsForScreen(screen) {
        if (typeof screen === "string")
            screen = Quickshell.screens.find(s => s.name === screen);
        if (!screen)
            return [];
        return DockConfig.resolveAll(dockConfigs, screen, Quickshell.screens, (config, target) => isScreenInPreferences(target, config.screenPreferences)).filter(config => !_barClaimsEdge(screen, config.position));
    }

    function dockConfigForScreenEdge(screen, side) {
        return dockConfigsForScreen(screen).find(config => DockConfig.EDGES[config.position] === side) ?? null;
    }

    function dockConfigForScreen(screen) {
        return dockConfigsForScreen(screen)[0] ?? null;
    }

    function _barClaimsEdge(screen, position) {
        return barConfigs.some(bar => bar.enabled && (bar.visible ?? true) && bar.position === position && barConfigCoversScreen(bar, screen));
    }

    function taskbarInsetForEdge(screen, side) {
        const config = dockConfigForScreenEdge(screen, side);
        if (!config || config.mode !== "taskbar")
            return 0;
        const frameInset = !CompositorService.frameWindowVisibleForScreen(screen) ? 0 : !config.useOverlayLayer && CompositorService.usesConnectedFrameChromeForScreen(screen) ? frameEdgeReservation(screen, side) : frameThickness;
        return DockConfig.effectiveThickness(config) + frameInset;
    }

    function dockReservationForEdge(screen, side) {
        const config = dockConfigForScreenEdge(screen, side);
        if (!config?.enabled || config.autoHide || config.smartAutoHide)
            return 0;
        return Math.max(0, DockConfig.effectiveThickness(config) + (config.mode === "taskbar" || (!config.useOverlayLayer && CompositorService.usesConnectedFrameChromeForScreen(screen)) ? 0 : config.margin + config.bottomGap));
    }

    function _screensCoveredBy(preferences) {
        return Quickshell.screens.filter(screen => preferences.includes("all") || isScreenInPreferences(screen, preferences));
    }

    // A dock only clashes with something sharing both a screen and an edge; other edges stay free.
    function dockAssignmentConflict(id, preferences, position) {
        const edge = position ?? getDockConfig(id)?.position ?? SettingsData.Position.Bottom;
        const covered = _screensCoveredBy(preferences);
        for (const other of dockConfigs) {
            if (other.id === id || other.position !== edge || !other.enabled)
                continue;
            if (covered.some(screen => isScreenInPreferences(screen, other.screenPreferences) || other.screenPreferences.includes("all")))
                return other.name;
        }
        for (const bar of barConfigs) {
            if (!bar.enabled || !(bar.visible ?? true) || bar.position !== edge)
                continue;
            if (covered.some(screen => barConfigCoversScreen(bar, screen)))
                return bar.name || bar.id;
        }
        return "";
    }

    // Edges this configuration could still be moved to, with its current edge always offered.
    function dockAvailableEdges(id, preferences) {
        const current = getDockConfig(id)?.position;
        return [SettingsData.Position.Top, SettingsData.Position.Bottom, SettingsData.Position.Left, SettingsData.Position.Right].filter(edge => edge === current || !dockAssignmentConflict(id, preferences, edge));
    }

    function dockConfigForAction(screen, selector) {
        if (selector)
            return getDockConfig(selector) || dockConfigs.find(config => config.name === selector) || null;
        if (typeof screen === "string")
            screen = Quickshell.screens.find(item => item.name === screen);
        const resolved = dockConfigForScreen(screen);
        if (resolved)
            return resolved;
        return dockConfigs.find(config => !config.screenPreferences.includes("all") && screen && isScreenInPreferences(screen, config.screenPreferences)) || dockConfigs.find(config => config.screenPreferences.includes("all")) || dockConfigs[0] || null;
    }

    function getDockConfig(id) {
        return dockConfigs.find(config => config.id === id) ?? null;
    }

    function updateDockConfig(id, updates) {
        const current = getDockConfig(id);
        if (!current)
            return;
        const next = DockConfig.normalize([Object.assign({}, current, updates, {
                id
            })])[0];
        if (!next)
            return;
        dockConfigs = dockConfigs.map(config => config.id === id ? next : config);
        saveSettings();
    }
    // First edge in `order` that no enabled bar or dock already holds on the covered displays.
    function firstFreeEdge(id, preferences, order) {
        return order.find(edge => !dockAssignmentConflict(id, preferences, edge)) ?? -1;
    }

    function firstFreeDockEdge(id, preferences) {
        return firstFreeEdge(id, preferences, [SettingsData.Position.Bottom, SettingsData.Position.Left, SettingsData.Position.Right, SettingsData.Position.Top]);
    }

    // A new dock shows up right away on every display when an edge is free for it.
    function createDockConfig() {
        const id = "dock_" + Date.now();
        let name = I18n.tr("Dock");
        let number = 2;
        while (dockConfigs.some(config => config.name === name))
            name = I18n.tr("Dock") + " " + number++;
        const config = DockConfig.create(id, name);
        const edge = firstFreeDockEdge(id, config.screenPreferences);
        config.enabled = edge >= 0;
        config.position = Math.max(SettingsData.Position.Top, edge);
        dockConfigs = dockConfigs.concat([config]);
        saveSettings();
        return id;
    }
    function removeDockConfig(id) {
        dockConfigs = dockConfigs.filter(config => config.id !== id);
        SessionData.removeDockPins(id);
        saveSettings();
    }
    function updateDockWidget(id, instanceId, updates) {
        const config = getDockConfig(id);
        if (!config)
            return;
        updateDockConfig(id, {
            widgets: config.widgets.map(item => item.id === instanceId ? Object.assign({}, item, updates) : item)
        });
    }

    // Pinning an app to a dock whose Apps row was removed would otherwise pin into nothing.
    function ensureDockApps(id) {
        const config = getDockConfig(id);
        if (!config)
            return;
        const apps = config.widgets.find(item => item.widgetId === "appsDock");
        if (apps && apps.enabled !== false)
            return;
        if (apps) {
            updateDockWidget(id, apps.id, {
                enabled: true
            });
            return;
        }
        updateDockConfig(id, {
            widgets: config.widgets.concat([
                {
                    id: id + "_apps",
                    widgetId: "appsDock",
                    enabled: true
                }
            ])
        });
    }

    function getBarConfig(barId) {
        return barConfigs.find(cfg => cfg.id === barId) || null;
    }

    function barTransparency(config) {
        if (config?.followInterfaceStyle !== false)
            return popupTransparency;
        return config?.transparency ?? 1.0;
    }

    function widgetOption(widgetType, data, key) {
        return WidgetDefaults.option(widgetType, data, key);
    }

    function widgetDefaults(widgetType) {
        return WidgetDefaults.DEFAULTS[widgetType] ?? {};
    }

    function barWidgetEntry(barConfig, widgetType) {
        if (!barConfig)
            return null;
        for (const listKey of ["leftWidgets", "centerWidgets", "rightWidgets"]) {
            for (const entry of barConfig[listKey] ?? []) {
                const id = typeof entry === "string" ? entry : (entry.id ?? entry.widgetId);
                if (id !== widgetType)
                    continue;
                return typeof entry === "string" ? {
                    "id": entry
                } : entry;
            }
        }
        return null;
    }

    function addBarWidget(barId, sectionId, widgetId) {
        const config = getBarConfig(barId);
        if (!config)
            return -1;
        const entry = {
            "id": widgetId,
            "enabled": true
        };
        switch (widgetId) {
        case "spacer":
            entry.size = 20;
            break;
        case "gpuTemp":
            entry.selectedGpuIndex = 0;
            entry.pciId = "";
            break;
        case "diskUsage":
            entry.mountPath = "/";
            break;
        }
        const listKey = sectionId + "Widgets";
        const list = (config[listKey] ?? []).slice();
        list.push(entry);
        const patch = {};
        patch[listKey] = list;
        updateBarConfig(barId, patch);
        return list.length - 1;
    }

    function locateBarWidget(widgetId, preferredBarId) {
        const ordered = barConfigs.slice().sort((a, b) => (b.id === preferredBarId) - (a.id === preferredBarId));
        for (const config of ordered) {
            for (const sectionId of ["left", "center", "right"]) {
                const list = config[sectionId + "Widgets"] ?? [];
                for (let i = 0; i < list.length; i++) {
                    const id = typeof list[i] === "string" ? list[i] : list[i].id;
                    if (id === widgetId)
                        return {
                            "barId": config.id,
                            "section": sectionId,
                            "index": i
                        };
                }
            }
        }
        return null;
    }

    function updateBarWidget(barId, sectionId, index, updates) {
        const config = getBarConfig(barId);
        const listKey = sectionId + "Widgets";
        const list = (config?.[listKey] ?? []).slice();
        if (index < 0 || index >= list.length)
            return;
        const entry = typeof list[index] === "string" ? {
            "id": list[index],
            "enabled": true
        } : Object.assign({}, list[index]);
        Object.assign(entry, updates);
        list[index] = entry;
        const patch = {};
        patch[listKey] = list;
        updateBarConfig(barId, patch);
    }

    function setBarIsland(barId, on) {
        const config = getBarConfig(barId);
        if (!config || (config.island === true) === (on === true))
            return;
        const updates = {
            island: on === true
        };
        if (on === true) {
            if (!config.enabled)
                updates.enabled = true;
            if ((config.screenPreferences ?? []).length === 0)
                updates.screenPreferences = ["all"];
        }
        updateBarConfig(barId, updates);
    }

    function isBarIpcRevealed(barId) {
        if (!barId)
            return false;
        return !!barIpcRevealStates[barId];
    }

    function setBarIpcReveal(barId, revealed) {
        if (!barId || isIslandBarConfig(getBarConfig(barId)))
            return;
        const nextRevealed = !!revealed;
        if (!!barIpcRevealStates[barId] === nextRevealed)
            return;
        const states = Object.assign({}, barIpcRevealStates);
        if (nextRevealed) {
            states[barId] = true;
        } else {
            delete states[barId];
        }
        barIpcRevealStates = states;
    }

    function toggleBarIpcReveal(barId) {
        const revealed = !isBarIpcRevealed(barId);
        setBarIpcReveal(barId, revealed);
        return revealed;
    }

    function addBarConfig(config) {
        const configs = JSON.parse(JSON.stringify(barConfigs));
        configs.push(config);
        if (connectedFrameModeActive)
            _captureConnectedFrameBarStyleBackups(configs, false);
        barConfigs = _sanitizeBarConfigsForConnectedFrame(configs).configs;
        updateBarConfigs();
    }

    function updateBarConfig(barId, updates) {
        const configs = JSON.parse(JSON.stringify(barConfigs));
        const index = configs.findIndex(cfg => cfg.id === barId);
        if (index === -1)
            return;
        const positionChanged = updates.position !== undefined && configs[index].position !== updates.position;
        if (updates.autoHide === false || updates.visible === false)
            setBarIpcReveal(barId, false);

        Object.assign(configs[index], updates);
        barConfigs = _sanitizeBarConfigsForConnectedFrame(configs).configs;
        updateBarConfigs();

        if (positionChanged) {
            notificationPopupsInvalidated();
        }
    }

    function deleteBarConfig(barId) {
        if (barId === "default")
            return;
        const configs = barConfigs.filter(cfg => cfg.id !== barId);
        barConfigs = configs;
        if (connectedFrameBarStyleBackups?.[barId] !== undefined) {
            const nextBackups = JSON.parse(JSON.stringify(connectedFrameBarStyleBackups || {}));
            delete nextBackups[barId];
            connectedFrameBarStyleBackups = nextBackups;
        }
        setBarIpcReveal(barId, false);
        updateBarConfigs();
    }

    function getBarKindConfigs() {
        return barConfigs.filter(cfg => !isIslandBarConfig(cfg));
    }

    // Style and popup fallbacks never treat the island as "the bar".
    function getPrimaryBarConfig() {
        const bars = getBarKindConfigs();
        if (bars.length > 0)
            return bars[0];
        const fallback = getBarConfig("default");
        return isIslandBarConfig(fallback) ? null : fallback;
    }

    function _sideToPosition(side) {
        return LayoutResolver.edges.indexOf(side);
    }

    function positionToSide(pos) {
        return LayoutResolver.edgeName(pos);
    }

    function barOccupiesSide(screen, side) {
        const position = _sideToPosition(side);
        return position >= 0 && (ShellLayout.forScreen(screen)?.bars.some(input => input.config.position === position) ?? false);
    }

    // Check if a dock occupies the specified screen edge.
    function dockOccupiesSide(screen, side) {
        const config = dockConfigForScreenEdge(screen, side);
        return !!config?.enabled;
    }

    function getScreenModelIndex(screen) {
        return LayoutResolver.screenModelIndex(screen, Quickshell.screens);
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
        return LayoutResolver.screenMatches(screen, prefs, Quickshell.screens, displayNameMode);
    }

    function getFilteredScreens(componentId) {
        var prefs = screenPreferences && screenPreferences[componentId] || ["all"];
        if (componentId === "wallpaper" && Array.isArray(prefs) && prefs.length === 0) {
            return [];
        }
        if (!prefs || prefs.length === 0 || prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all")) {
            return Quickshell.screens;
        }
        var filtered = Quickshell.screens.filter(screen => isScreenInPreferences(screen, prefs));
        if (filtered.length === 0 && showOnLastDisplay && showOnLastDisplay[componentId] && Quickshell.screens.length === 1) {
            return Quickshell.screens;
        }
        return filtered;
    }

    function barConfigCoversScreen(bc, screen) {
        return ShellLayout.coversScreen(bc, screen);
    }

    function isIslandBarConfig(bc) {
        return !!bc && bc.island === true;
    }

    function activeIslandConfigsForScreen(screen) {
        return ShellLayout.islandConfigs(screen);
    }

    function islandConfigForEdge(screen, edge) {
        return ShellLayout.edge(screen, edge)?.island ?? null;
    }

    function dankIslandCoversScreen(screen) {
        return activeIslandConfigsForScreen(screen).length > 0;
    }

    function dankIslandHandlesNotifications(screen) {
        return activeIslandConfigsForScreen(screen).some(cfg => !islandSetting(cfg, "islandNotificationPopups"));
    }

    function dankIslandOwnsEdge(screen, edge) {
        return islandConfigForEdge(screen, edge) !== null;
    }

    function dankIslandEdgeOffset(screen, edge) {
        return ShellLayout.edge(screen, edge)?.islandThickness ?? 0;
    }

    function dankIslandIsSoleBarForScreen(screen) {
        return dankIslandCoversScreen(screen) && getActiveBarEdgesForScreen(screen).length === 0;
    }

    function getActiveBarEdgesForScreen(screen) {
        return ShellLayout.barEdges(screen, false);
    }

    readonly property real frameBarContentGap: frameBarInsetPadding < 0 ? frameThickness : frameBarInsetPadding
    readonly property real frameBarContentGapExtra: Math.max(0, frameBarContentGap - frameThickness)

    function frameEdgeReservation(screen, edge) {
        return ShellLayout.frameReservation(screen, edge);
    }

    function frameEdgeInsetForSide(screen, side) {
        if (!frameEnabled)
            return 0;
        return frameEdgeReservation(screen, side);
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

    function setMatugenSmartMode(enabled) {
        if (matugenSmartMode === enabled)
            return;
        set("matugenSmartMode", enabled);
    }

    function setMatugenSourceMode(mode) {
        var normalized = mode || "dominant";
        if (matugenSourceMode === normalized)
            return;
        // Regeneration comes from the regenSystemThemes onChange hook in
        // SettingsSpec.js, which set() dispatches. matugenScheme above also
        // calls Theme.generateSystemThemesFromCurrentTheme() directly, which is
        // redundant with its own hook.
        set("matugenSourceMode", normalized);
    }

    function setMatugenContrast(value) {
        if (matugenContrast === value)
            return;
        set("matugenContrast", value);
    }

    function setMatugenSeedColor(hex) {
        var normalized = /^#[0-9a-f]{6}$/i.test(hex || "") ? hex.toLowerCase() : "";
        if (matugenSeedColor === normalized)
            return;
        set("matugenSeedColor", normalized);
    }

    function setMatugenSpec(spec) {
        var normalized = spec === "2025" ? "2025" : "2021";
        if (matugenSpec === normalized)
            return;
        if (normalized === "2025" && matugenContrast < 0)
            set("matugenContrast", 0);
        set("matugenSpec", normalized);
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
        set("radiusStrength", Shape.strengthFromRadius(radius));
    }

    function setWeatherLocation(displayName, coordinates) {
        SessionData.setWeatherLocation(displayName, coordinates);
    }

    function setIconThemeForMode(themeName, light) {
        if (light)
            iconThemeLight = themeName;
        else
            iconThemeDark = themeName;
        applyStoredIconTheme();
        saveSettings();
        if (typeof Theme !== "undefined" && Theme.currentTheme === Theme.dynamic)
            Theme.generateSystemThemesFromCurrentTheme();
    }

    function setIconThemePerMode(enabled) {
        iconThemePerMode = enabled;
        applyStoredIconTheme();
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
        compositorCursorRefreshNeeded();
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
        const themeName = isSystemDefault ? "" : cursorSettings.theme;
        const size = String(cursorSettings.size || 24);
        const env = {};

        // Started from systemd the shell inherits no XCURSOR_SIZE from the compositor
        // XWayland children would size their cursor from the display instead
        if (!isDefaultSize || !Quickshell.env("XCURSOR_SIZE")) {
            env["XCURSOR_SIZE"] = size;
            env["HYPRCURSOR_SIZE"] = size;
        }
        if (themeName) {
            env["XCURSOR_THEME"] = themeName;
            env["HYPRCURSOR_THEME"] = themeName;
        }
        return env;
    }

    function setDankBarLeftWidgets(order) {
        const defaultBar = getPrimaryBarConfig();
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "leftWidgets": order
            });
            updateListModel(leftWidgetsModel, order);
        }
    }

    function setDankBarCenterWidgets(order) {
        const defaultBar = getPrimaryBarConfig();
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "centerWidgets": order
            });
            updateListModel(centerWidgetsModel, order);
        }
    }

    function setDankBarRightWidgets(order) {
        const defaultBar = getPrimaryBarConfig();
        if (defaultBar) {
            updateBarConfig(defaultBar.id, {
                "rightWidgets": order
            });
            updateListModel(rightWidgetsModel, order);
        }
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

    function addMediaExcludePlayer(identity) {
        if (identity === undefined || identity === null)
            return;
        var normalizedIdentity = identity.toString().trim().toLowerCase();
        if (!normalizedIdentity)
            return;
        var list = mediaExcludePlayers ? mediaExcludePlayers.slice() : [];
        var normalizedList = list.map(function (id) {
            return id ? id.toString().trim().toLowerCase() : "";
        });
        if (normalizedList.indexOf(normalizedIdentity) >= 0)
            return;
        list.push(normalizedIdentity);
        mediaExcludePlayers = list;
        saveSettings();
    }

    function removeMediaExcludePlayer(index) {
        var list = mediaExcludePlayers ? mediaExcludePlayers.slice() : [];
        if (index < 0 || index >= list.length)
            return;
        list.splice(index, 1);
        mediaExcludePlayers = list;
        saveSettings();
    }

    property bool _pendingExpandNotificationRules: false
    property int _pendingNotificationRuleIndex: -1

    function _newNotificationRule(overrides) {
        return Object.assign({
            enabled: true,
            field: "appName",
            pattern: "",
            matchType: "contains",
            action: "default",
            urgency: "default",
            bypassDnd: false
        }, overrides || {});
    }

    function addNotificationRule() {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        rules.push(_newNotificationRule());
        notificationRules = rules;
        saveSettings();
    }

    function addNotificationRuleForNotification(appName, desktopEntry) {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        var pattern = desktopEntry || appName || "";
        rules.push(_newNotificationRule(pattern ? {
            field: desktopEntry ? "desktopEntry" : "appName",
            pattern: pattern,
            matchType: "exact"
        } : {}));
        notificationRules = rules;
        saveSettings();
        var index = rules.length - 1;
        _pendingExpandNotificationRules = true;
        _pendingNotificationRuleIndex = index;
        return index;
    }

    function _isMuteRule(rule) {
        return (rule.action || "").toString().toLowerCase() === "mute";
    }

    function _isDndBypassRule(rule) {
        return rule.bypassDnd === true;
    }

    function _appRuleIndex(rules, appName, desktopEntry, predicate) {
        const app = (appName || "").toString().toLowerCase();
        const desktop = (desktopEntry || "").toString().toLowerCase();
        if (!app && !desktop)
            return -1;
        return rules.findIndex(rule => {
            if (!predicate(rule))
                return false;
            const pattern = (rule.pattern || "").toString().toLowerCase();
            return pattern !== "" && (pattern === app || pattern === desktop);
        });
    }

    function _addAppRule(appName, desktopEntry, overrides) {
        const pattern = desktopEntry || appName || "";
        if (!pattern)
            return;
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        rules.push(_newNotificationRule(Object.assign({
            field: desktopEntry ? "desktopEntry" : "appName",
            pattern: pattern,
            matchType: "exact"
        }, overrides)));
        notificationRules = rules;
        saveSettings();
    }

    function _removeAppRule(appName, desktopEntry, predicate) {
        var rules = JSON.parse(JSON.stringify(notificationRules || []));
        const index = _appRuleIndex(rules, appName, desktopEntry, predicate);
        if (index === -1)
            return;
        rules.splice(index, 1);
        notificationRules = rules;
        saveSettings();
    }

    function addMuteRuleForApp(appName, desktopEntry) {
        _addAppRule(appName, desktopEntry, {
            action: "mute"
        });
    }

    function isAppMuted(appName, desktopEntry) {
        return _appRuleIndex(notificationRules || [], appName, desktopEntry, rule => rule.enabled !== false && _isMuteRule(rule)) !== -1;
    }

    function removeMuteRuleForApp(appName, desktopEntry) {
        _removeAppRule(appName, desktopEntry, _isMuteRule);
    }

    function isAppDndBypassed(appName, desktopEntry) {
        return _appRuleIndex(notificationRules || [], appName, desktopEntry, rule => rule.enabled !== false && _isDndBypassRule(rule)) !== -1;
    }

    function setAppDndBypass(appName, desktopEntry, enabled) {
        if (!enabled) {
            _removeAppRule(appName, desktopEntry, _isDndBypassRule);
            return;
        }
        if (isAppDndBypassed(appName, desktopEntry))
            return;
        _addAppRule(appName, desktopEntry, {
            bypassDnd: true
        });
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

    function getPluginSettingsForPlugin(pluginId) {
        const settings = pluginSettings[pluginId];
        return settings ? JSON.parse(JSON.stringify(settings)) : {};
    }

    function removeDisplayProfile(compositor, profileId) {
        if (!displayProfiles[compositor] || !displayProfiles[compositor][profileId])
            return;
        const updated = JSON.parse(JSON.stringify(displayProfiles));
        delete updated[compositor][profileId];
        displayProfiles = updated;
        saveSettings();
    }

    function setDisplayPreviousRefreshModes(compositor, modes) {
        if (JSON.stringify(displayPreviousRefreshModes[compositor] || {}) === JSON.stringify(modes || {}))
            return;
        const updated = JSON.parse(JSON.stringify(displayPreviousRefreshModes));
        if (Object.keys(modes || {}).length > 0)
            updated[compositor] = modes;
        else
            delete updated[compositor];
        displayPreviousRefreshModes = updated;
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

    component SettingsFile : QtObject {
        id: settingsFile

        required property string filePath
        property var settings: ({})
        property bool isLoading: false
        property bool hasLoaded: false
        property bool hasParseFailed: false
        property bool hasUnsavedChanges: false
        property bool isFileReadOnly: false
        property bool selfWrite: false
        function setSettings(newSettings) {
            const newSettingsJson = JSON.stringify(newSettings, null, 2);
            if (JSON.stringify(settings, null, 2) !== newSettingsJson) {
                settings = newSettings;
                hasUnsavedChanges = true;
            }
            if (hasUnsavedChanges) {
                selfWrite = true;
                settingsFileView.setText(newSettingsJson);
            }
        }
        function getSettings() {
            return Object.assign({}, settings);
        }
        function retrySaving() {
            if (!hasUnsavedChanges) {
                return;
            }
            // Quickshell only writes if the text has changed, but doesn't provide a way to force a write.
            const json = JSON.stringify(settings, null, 2) + ((settingsSaveFailRecovery.tries % 2 === 1) ? " " : "");
            selfWrite = true;
            settingsFileView.setText(json);
        }

        property Timer timer: Timer {
            id: settingsFileReloadDebounce
            interval: 50
            onTriggered: settingsFileView.reload()
            repeat: false
        }

        property FileView fileView: FileView {
            id: settingsFileView

            path: isGreeterMode ? "" : filePath
            blockLoading: false
            blockWrites: true
            atomicWrites: true
            watchChanges: !isGreeterMode
            onFileChanged: {
                if (selfWrite) {
                    selfWrite = false;
                } else {
                    isLoading = true;
                    _loading = true;
                    settingsFileReloadDebounce.restart();
                }
            }
            onLoaded: {
                if (isGreeterMode) {
                    return;
                }
                if (hasUnsavedChanges) {
                    const fileName = filePath?.split("/").pop() || "unknown";
                    log.warn(`Aborting ${fileName} reload: there are unsaved changes which would've been lost.`)
                    isLoading = false;
                    _loading = _anySettingsFile(file => file.isLoading);
                    settingsSaveFailRecovery.start();
                    return;
                }
                isLoading = true;
                _loading = true;
                const hadParseFailed = hasParseFailed;
                hasParseFailed = false;
                const fileName = filePath?.split("/").pop();
                try {
                    let txt = settingsFileView.text();
                    if (!txt || !txt.trim()) {
                        txt = "{}";
                    }
                    settings = JSON.parse(txt);
                    hasLoaded = true;
                } catch (error) {
                    hasParseFailed = true;
                    _parseError = true;

                    const msg = error.message;
                    log.error(`Failed to reload ${fileName} - file will not be overwritten. Error:`, msg);
                    Qt.callLater(() => ToastService.showError(I18n.tr("Failed to parse %1").arg(fileName), msg));
                } finally {
                    isLoading = false;
                    if (hasLoaded) {
                        _tryCompleteLoading();
                    }
                    if (hadParseFailed && !hasParseFailed) {
                        _parseError = _anySettingsFile(file => file.hasParseFailed);
                    }
                    _loadSettingsOrStartIfReady();
                }
            }
            onLoadFailed: (error) => {
                if (isGreeterMode) {
                    return;
                }
                isLoading = false;
                _loading = _anySettingsFile(file => file.isLoading);
                if (error === FileViewError.FileNotFound) {
                    // Fake that the file has been loaded so that it gets created after a save.
                    hasLoaded = true;
                }
                applyStoredTheme();
                if (hasLoaded) {
                    _tryCompleteLoading();
                }
                _loadSettingsOrStartIfReady();
            }
            onSaved: {
                hasUnsavedChanges = false;
                isFileReadOnly = false;
                isReadOnly = _anySettingsFile(file => file.isFileReadOnly);

                const fileName = filePath?.split("/").pop() || "unknown";
                if (_failedSaveSettingsFiles.has(settingsFile)) {
                    log.info(`Settings file '${fileName}' saved successfully after previous failures`)
                    _failedSaveSettingsFiles.delete(settingsFile);
                }
            }
            onSaveFailed: (error) => {
                if (error === FileViewError.PermissionDenied) {
                    isFileReadOnly = true;
                    isReadOnly = true;
                }
                _failedSaveSettingsFiles.add(settingsFile);
                const fileName = filePath?.split("/").pop() || "unknown";
                log.warn(`Failed to save ${fileName}, retrying...`)
                settingsSaveFailRecovery.start();
            }
        }
    }

    enum Stage { Discovering = 0, Loading = 1, Ready = 2 }
    property int _settingsStage: SettingsData.Stage.Discovering

    property var _settingsFiles: new Map()
    property var _settingsFilesPaths: ([])
    property var _failedSaveSettingsFiles: new Set()
    function _registerSettingsFile(file) {
        const filePath = file.filePath;
        if (_settingsFiles.has(filePath)) {
            return;
        }
        let index;
        if (file === defaultSettingsFile) {
            index = 0;
        } else {
            index = _settingsFilesPaths.findIndex((path, index) => {
                return path > filePath && index > 0;
            });
        }
        _settingsFiles.set(filePath, file);
        if (index >= 0) {
            _settingsFilesPaths.splice(index, 0, filePath);
        } else {
            _settingsFilesPaths.push(filePath);
        }
        _tryCompleteDiscovery();
    }
    function _unregisterSettingsFile(file) {
        _settingsFiles.delete(file.filePath);
        _settingsFilesPaths = _settingsFilesPaths.filter(path => path != file.filePath);
    }
    function _tryCompleteDiscovery() {
        const folderModel = settingsFolderModel;
        if (_settingsStage !== SettingsData.Stage.Discovering || !folderModel.checked) {
            return;
        }
        let expectedCount = 1;
        if (folderModel.exists) {
            expectedCount += settingsFolderModel.count;
        }
        if (_settingsFilesPaths.length == expectedCount) {
            _settingsStage = SettingsData.Stage.Loading;
            _tryCompleteLoading();
            _loadSettingsOrStartIfReady();
        }
    }
    function _tryCompleteLoading() {
        if (_settingsStage !== SettingsData.Stage.Loading) {
            return;
        }
        if (_everySettingsFile(file => file.hasLoaded)) {
            _settingsStage = SettingsData.Stage.Ready;
        }
    }
    function _loadSettingsOrStartIfReady() {
        if (_settingsStage !== SettingsData.Stage.Ready || _anySettingsFile(file => file.isLoading)) {
            return;
        }
        let unsaved;
        _loading = true;
        if (!_hasLoaded) {
            unsaved = _runStartSequence();
        } else {
            unsaved = _loadSettings();
        }
        _loading = false;
        if (unsaved) {
            _saveSettings();
        }
    }
    function _getSettingsObjectFromFiles() {
        const settingsObject = {};
        for (const path of _settingsFilesPaths) {
            const settingsFile = _settingsFiles.get(path);
            Object.assign(settingsObject, settingsFile.getSettings());
        }
        return settingsObject;
    }

    function _anySettingsFile(predicate) {
        for (const file of _settingsFiles.values()) {
            if (predicate(file)) {
                return true;
            }
        }
        return false;
    }
    function _everySettingsFile(predicate) {
        for (const file of _settingsFiles.values()) {
            if (!predicate(file)) {
                return false;
            }
        }
        return true;
    }

    SettingsFile {
        id: defaultSettingsFile

        filePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell/settings.json"

        Component.onCompleted: {
            _registerSettingsFile(defaultSettingsFile);
        }
    }

    function _syncSettingsFilesModels() {
        const listModel = settingsFilesListModel;
        const folderModel = settingsFolderModel;
        if (!folderModel.checked) {
            settingsFilesModelSyncDebounce.restart();
            return;
        }
        if (!folderModel.exists) {
            return;
        }

        const folderPathsSet = new Set();
        for (let i = 0; i < folderModel.count; i++) {
            const filePath = folderModel.get(i, "filePath");
            folderPathsSet.add(filePath);
            if (!_settingsFiles.has(filePath)) {
                listModel.append({ filePath });
            }
        }
        for (let i = listModel.count - 1; i >= 0; i--) {
            const filePath = listModel.get(i).filePath;
            if (!folderPathsSet.has(filePath)) {
                listModel.remove(i);
            }
        }
    }
    Timer {
        id: settingsFilesModelSyncDebounce
        interval: 50
        repeat: false
        running: false
        onTriggered: _syncSettingsFilesModels()
    }
    ListModel {
        id: settingsFilesListModel
    }
    FolderListModel {
        id: settingsFolderModel

        // Folder seems to be reset to the CWD if the directory doesn't exist.
        property url dir: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell/config.d"
        property bool checked: false
        property bool exists: folder === dir

        folder: dir
        showDirs: false
        nameFilters: ["*.json"]
        onStatusChanged: {
            if (status !== FolderListModel.Ready) {
                return;
            }
            checked = true;
            if (_hasLoaded) {
                settingsFilesModelSyncDebounce.restart();
            } else {
                _syncSettingsFilesModels();
            }
            _tryCompleteDiscovery();
        }
    }

    Instantiator {
        id: settingsLoader

        model: settingsFilesListModel
        onObjectAdded: (_, file) => {
            _registerSettingsFile(file);
        }
        onObjectRemoved: (_, file) => {
            _unregisterSettingsFile(file);
            _loadSettingsOrStartIfReady();
        }
        delegate: SettingsFile {
            id: settingsFile
        }
    }

    readonly property string _greeterCacheDir: Quickshell.env("DMS_GREET_CFG_DIR") || "/var/cache/dms-greeter"

    property string greeterSettingsBaseDir: root._greeterCacheDir

    function setGreeterSettingsBaseDir(dir) {
        const next = dir || root._greeterCacheDir;
        if (greeterSettingsBaseDir === next)
            return;
        greeterSettingsBaseDir = next;
        if (isGreeterMode)
            greeterSettingsFile.reload();
    }

    function resetGreeterSettingsBaseDir() {
        setGreeterSettingsBaseDir(root._greeterCacheDir);
    }

    function loadGreeterSettings(txt) {
        _loading = true;
        _hasLoaded = false;
        try {
            Store.parse(root, (txt && txt.trim()) ? JSON.parse(txt) : {});
            _parseError = false;
        } catch (e) {
            _parseError = true;
            log.error("Failed to parse greeter settings.json:", e.message);
            Store.parse(root, {});
        } finally {
            _loading = false;
        }
        _hasLoaded = true;
        applyStoredTheme();
    }

    FileView {
        id: greeterSettingsFile

        path: root.greeterSettingsBaseDir ? (root.greeterSettingsBaseDir + "/settings.json") : ""
        preload: isGreeterMode
        blockLoading: false
        blockWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            if (isGreeterMode)
                loadGreeterSettings(greeterSettingsFile.text());
        }
        onLoadFailed: {
            if (isGreeterMode)
                loadGreeterSettings("");
        }
    }

    FileView {
        id: pluginSettingsFile

        path: isGreeterMode ? "" : pluginSettingsPath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        watchChanges: !isGreeterMode
        onLoaded: {
            if (isGreeterMode)
                return;
            parsePluginSettings(pluginSettingsFile.text());
        }
        onLoadFailed: error => {
            if (isGreeterMode)
                return;
            const msg = String(error || "");
            if (!_isMissingPluginSettingsError(error))
                log.warn("Failed to load plugin_settings.json. Error:", msg);
            _resetPluginSettings();
        }
    }

    Timer {
        id: settingsSaveFailRecovery

        property int tries: 0
        interval: {
            const delay = 2 ** (tries + 1);
            return (delay > 60 ? 60 : delay) * 1000;
        }
        repeat: true
        running: false
        onTriggered: {
            if (_failedSaveSettingsFiles.size === 0 || tries >= 15) {
                tries = 0;
                stop();
                return;
            }
            tries++;
            for (const file of _failedSaveSettingsFiles) {
                file.retrySaving();
            }
        }
    }

    Timer {
        id: settingsSaveDebounce
        interval: 50
        repeat: false
        running: false
        onTriggered: _saveSettings()
    }

    property bool pluginSettingsFileExists: false
}
