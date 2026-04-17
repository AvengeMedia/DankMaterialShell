import QtQuick
import qs.Common

Item {
    id: root

    property string layerNamespace: "dms:popout"
    property Component content: null
    property Component overlayContent: null
    property real popupWidth: 400
    property real popupHeight: 300
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 40
    property string triggerSection: ""
    property string positioning: "center"
    property int animationDuration: Theme.popoutAnimationDuration
    property real animationScaleCollapsed: 0.96
    property real animationOffset: Theme.spacingL
    property list<real> animationEnterCurve: Theme.expressiveCurves.expressiveDefaultSpatial
    property list<real> animationExitCurve: Theme.expressiveCurves.emphasized
    property bool suspendShadowWhileResizing: false
    property bool shouldBeVisible: false
    property var customKeyboardFocus: null
    property bool backgroundInteractive: true
    property bool contentHandlesKeys: false
    property bool fullHeightSurface: false
    property bool _primeContent: false

    property real storedBarThickness: Theme.barHeight - 4
    property real storedBarSpacing: 4
    property var storedBarConfig: null
    property var adjacentBarInfo: ({
            "topBar": 0,
            "bottomBar": 0,
            "leftBar": 0,
            "rightBar": 0
        })
    property var screen: null
    property int effectiveBarPosition: 0
    property real effectiveBarBottomGap: 0

    signal opened
    signal popoutClosed
    signal backgroundClicked

    readonly property var contentLoader: impl.item ? impl.item.contentLoader : _fallbackContentLoader
    readonly property var overlayLoader: impl.item ? impl.item.overlayLoader : _fallbackOverlayLoader

    Loader {
        id: _fallbackContentLoader
        active: false
    }
    Loader {
        id: _fallbackOverlayLoader
        active: false
    }
    readonly property bool isClosing: impl.item ? (impl.item.isClosing ?? false) : false
    readonly property real dpr: impl.item ? impl.item.dpr : 1
    readonly property real screenWidth: impl.item ? impl.item.screenWidth : 0
    readonly property real screenHeight: impl.item ? impl.item.screenHeight : 0
    readonly property real alignedX: impl.item ? impl.item.alignedX : 0
    readonly property real alignedY: impl.item ? impl.item.alignedY : 0
    readonly property real alignedWidth: impl.item ? impl.item.alignedWidth : 0
    readonly property real alignedHeight: impl.item ? impl.item.alignedHeight : 0
    readonly property real maskX: impl.item ? impl.item.maskX : 0
    readonly property real maskY: impl.item ? impl.item.maskY : 0
    readonly property real maskWidth: impl.item ? impl.item.maskWidth : 0
    readonly property real maskHeight: impl.item ? impl.item.maskHeight : 0
    readonly property real barX: impl.item ? impl.item.barX : 0
    readonly property real barY: impl.item ? impl.item.barY : 0
    readonly property real barWidth: impl.item ? impl.item.barWidth : 0
    readonly property real barHeight: impl.item ? impl.item.barHeight : 0

    function open() {
        if (impl.item)
            impl.item.open();
    }

    function close() {
        if (impl.item)
            impl.item.close();
    }

    function toggle() {
        shouldBeVisible ? close() : open();
    }

    function setBarContext(position, bottomGap) {
        effectiveBarPosition = position !== undefined ? position : 0;
        effectiveBarBottomGap = bottomGap !== undefined ? bottomGap : 0;
    }

    function setTriggerPosition(x, y, width, section, targetScreen, barPosition, barThickness, barSpacing, barConfig) {
        triggerX = x;
        triggerY = y;
        triggerWidth = width;
        triggerSection = section;
        screen = targetScreen;

        storedBarThickness = barThickness !== undefined ? barThickness : (Theme.barHeight - 4);
        storedBarSpacing = barSpacing !== undefined ? barSpacing : 4;
        storedBarConfig = barConfig;

        const pos = barPosition !== undefined ? barPosition : 0;
        const bottomGap = barConfig ? (barConfig.bottomGap !== undefined ? barConfig.bottomGap : 0) : 0;

        adjacentBarInfo = SettingsData.getAdjacentBarInfo(targetScreen, pos, barConfig);
        setBarContext(pos, bottomGap);
    }

    function updateSurfacePosition() {
        if (impl.item && typeof impl.item.updateSurfacePosition === "function")
            impl.item.updateSurfacePosition();
    }

    Loader {
        id: impl
        sourceComponent: SettingsData.connectedFrameModeActive ? connectedComp : standaloneComp
        onItemChanged: if (item)
            root._wireBackend(item)
    }

    Component {
        id: standaloneComp
        DankPopoutStandalone {}
    }

    Component {
        id: connectedComp
        DankPopoutConnected {}
    }

    function _wireBackend(it) {
        if (!it)
            return;

        it.popoutHandle = root;
        it.layerNamespace = Qt.binding(() => root.layerNamespace);
        it.content = Qt.binding(() => root.content);
        it.overlayContent = Qt.binding(() => root.overlayContent);
        it.popupWidth = Qt.binding(() => root.popupWidth);
        it.popupHeight = Qt.binding(() => root.popupHeight);
        it.triggerX = Qt.binding(() => root.triggerX);
        it.triggerY = Qt.binding(() => root.triggerY);
        it.triggerWidth = Qt.binding(() => root.triggerWidth);
        it.triggerSection = Qt.binding(() => root.triggerSection);
        it.positioning = Qt.binding(() => root.positioning);
        it.animationDuration = Qt.binding(() => root.animationDuration);
        it.animationScaleCollapsed = Qt.binding(() => root.animationScaleCollapsed);
        it.animationOffset = Qt.binding(() => root.animationOffset);
        it.animationEnterCurve = Qt.binding(() => root.animationEnterCurve);
        it.animationExitCurve = Qt.binding(() => root.animationExitCurve);
        it.suspendShadowWhileResizing = Qt.binding(() => root.suspendShadowWhileResizing);
        it.customKeyboardFocus = Qt.binding(() => root.customKeyboardFocus);
        it.backgroundInteractive = Qt.binding(() => root.backgroundInteractive);
        it.contentHandlesKeys = Qt.binding(() => root.contentHandlesKeys);
        it.fullHeightSurface = Qt.binding(() => root.fullHeightSurface);
        it.storedBarThickness = Qt.binding(() => root.storedBarThickness);
        it.storedBarSpacing = Qt.binding(() => root.storedBarSpacing);
        it.storedBarConfig = Qt.binding(() => root.storedBarConfig);
        it.adjacentBarInfo = Qt.binding(() => root.adjacentBarInfo);
        it.screen = Qt.binding(() => root.screen);
        it.effectiveBarPosition = Qt.binding(() => root.effectiveBarPosition);
        it.effectiveBarBottomGap = Qt.binding(() => root.effectiveBarBottomGap);

        // shouldBeVisible is two-way — backend's open()/close() flips it internally.
        it.shouldBeVisible = root.shouldBeVisible;
        it.shouldBeVisibleChanged.connect(function () {
            if (root.shouldBeVisible !== it.shouldBeVisible)
                root.shouldBeVisible = it.shouldBeVisible;
        });

        it.opened.connect(root.opened);
        it.popoutClosed.connect(root.popoutClosed);
        it.backgroundClicked.connect(root.backgroundClicked);
    }

    function primeContent() {
        _primeContent = true;
        if (impl.item)
            impl.item.primeContent();
    }

    function clearPrimedContent() {
        _primeContent = false;
        if (impl.item)
            impl.item.clearPrimedContent();
    }

    Connections {
        target: root
        function onShouldBeVisibleChanged() {
            if (impl.item && impl.item.shouldBeVisible !== root.shouldBeVisible)
                impl.item.shouldBeVisible = root.shouldBeVisible;
        }
    }
}
