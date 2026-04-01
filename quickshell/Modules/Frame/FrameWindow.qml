pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: win

    required property var targetScreen

    screen: targetScreen
    visible: true

    WlrLayershell.namespace: "dms:frame"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    // No input — pass everything through to apps and bar
    mask: Region {}

    readonly property var barEdges: {
        SettingsData.barConfigs;
        return SettingsData.getActiveBarEdgesForScreen(win.screen);
    }

    readonly property real _dpr: CompositorService.getScreenScale(win.screen)
    readonly property bool _frameActive: SettingsData.frameEnabled
        && SettingsData.isScreenInPreferences(win.screen, SettingsData.frameScreenPreferences)
    readonly property int _windowRegionWidth:  win._regionInt(win.width)
    readonly property int _windowRegionHeight: win._regionInt(win.height)

    function _regionInt(value) {
        return Math.max(0, Math.round(Theme.px(value, win._dpr)));
    }

    readonly property int cutoutTopInset:    win._regionInt(barEdges.includes("top")    ? SettingsData.frameBarSize : SettingsData.frameThickness)
    readonly property int cutoutBottomInset: win._regionInt(barEdges.includes("bottom") ? SettingsData.frameBarSize : SettingsData.frameThickness)
    readonly property int cutoutLeftInset:   win._regionInt(barEdges.includes("left")   ? SettingsData.frameBarSize : SettingsData.frameThickness)
    readonly property int cutoutRightInset:  win._regionInt(barEdges.includes("right")  ? SettingsData.frameBarSize : SettingsData.frameThickness)
    readonly property int cutoutWidth:  Math.max(0, win._windowRegionWidth - win.cutoutLeftInset - win.cutoutRightInset)
    readonly property int cutoutHeight: Math.max(0, win._windowRegionHeight - win.cutoutTopInset - win.cutoutBottomInset)
    readonly property int cutoutRadius: {
        const requested = win._regionInt(SettingsData.frameRounding);
        const maxRadius = Math.floor(Math.min(win.cutoutWidth, win.cutoutHeight) / 2);
        return Math.max(0, Math.min(requested, maxRadius));
    }

    // Slightly expand the subtractive blur cutout at very low opacity levels
    readonly property int _blurCutoutCompensation: SettingsData.frameOpacity <= 0.2 ? 1 : 0
    readonly property int _blurCutoutLeft: Math.max(0, win.cutoutLeftInset - win._blurCutoutCompensation)
    readonly property int _blurCutoutTop: Math.max(0, win.cutoutTopInset - win._blurCutoutCompensation)
    readonly property int _blurCutoutRight: Math.min(win._windowRegionWidth, win._windowRegionWidth - win.cutoutRightInset + win._blurCutoutCompensation)
    readonly property int _blurCutoutBottom: Math.min(win._windowRegionHeight, win._windowRegionHeight - win.cutoutBottomInset + win._blurCutoutCompensation)
    readonly property int _blurCutoutRadius: {
        const requested = win.cutoutRadius + win._blurCutoutCompensation;
        const maxRadius = Math.floor(Math.min(_blurCutout.width, _blurCutout.height) / 2);
        return Math.max(0, Math.min(requested, maxRadius));
    }

    // Must stay visible so Region.item can resolve scene coordinates.
    Item {
        id: _blurCutout
        x: win._blurCutoutLeft
        y: win._blurCutoutTop
        width: Math.max(0, win._blurCutoutRight - win._blurCutoutLeft)
        height: Math.max(0, win._blurCutoutBottom - win._blurCutoutTop)
    }

    property var _frameBlurRegion: null

    function _buildBlur() {
        _teardownBlur();
        // Follow the global blur toggle
        if (!BlurService.enabled || !SettingsData.frameBlurEnabled || !win._frameActive || !win.visible)
            return;
        try {
            const region = Qt.createQmlObject(
                'import QtQuick; import Quickshell; Region {' +
                '  property Item cutoutItem;' +
                '  property int cutoutRadius: 0;' +
                '  Region {' +
                '    item: cutoutItem;' +
                '    intersection: Intersection.Subtract;' +
                '    radius: cutoutRadius;' +
                '  }' +
                '}',
                win, "FrameBlurRegion");

            region.x = Qt.binding(() => 0);
            region.y = Qt.binding(() => 0);
            region.width = Qt.binding(() => win._windowRegionWidth);
            region.height = Qt.binding(() => win._windowRegionHeight);
            region.cutoutItem = _blurCutout;
            region.cutoutRadius = Qt.binding(() => win._blurCutoutRadius);

            win.BackgroundEffect.blurRegion = region;
            win._frameBlurRegion = region;
        } catch (e) {
            console.warn("FrameWindow: Failed to create blur region:", e);
        }
    }

    function _teardownBlur() {
        if (!win._frameBlurRegion)
            return;
        try {
            win.BackgroundEffect.blurRegion = null;
        } catch (e) {}
        win._frameBlurRegion.destroy();
        win._frameBlurRegion = null;
    }

    Timer {
        id: _blurRebuildTimer
        interval: 1
        onTriggered: win._buildBlur()
    }

    Connections {
        target: SettingsData
        function onFrameBlurEnabledChanged()  { _blurRebuildTimer.restart(); }
        function onFrameEnabledChanged()      { _blurRebuildTimer.restart(); }
        function onFrameThicknessChanged()    { _blurRebuildTimer.restart(); }
        function onFrameBarSizeChanged()      { _blurRebuildTimer.restart(); }
        function onFrameOpacityChanged()      { _blurRebuildTimer.restart(); }
        function onFrameRoundingChanged()     { _blurRebuildTimer.restart(); }
        function onFrameScreenPreferencesChanged() { _blurRebuildTimer.restart(); }
        function onBarConfigsChanged()        { _blurRebuildTimer.restart(); }
    }

    Connections {
        target: BlurService
        function onEnabledChanged() { _blurRebuildTimer.restart(); }
    }

    onVisibleChanged: {
        if (visible) {
            win._frameBlurRegion = null;
            _blurRebuildTimer.restart();
        } else {
            _teardownBlur();
        }
    }

    Component.onCompleted: Qt.callLater(() => win._buildBlur())
    Component.onDestruction: win._teardownBlur()

    FrameBorder {
        anchors.fill: parent
        visible: win._frameActive
        cutoutTopInset: win.cutoutTopInset
        cutoutBottomInset: win.cutoutBottomInset
        cutoutLeftInset: win.cutoutLeftInset
        cutoutRightInset: win.cutoutRightInset
        cutoutRadius: win.cutoutRadius
    }
}
