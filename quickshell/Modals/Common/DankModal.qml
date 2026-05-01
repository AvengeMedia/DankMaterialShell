import QtQuick
import qs.Common
import qs.Services

Item {
    id: root
    readonly property var log: Log.scoped("DankModal")

    readonly property bool useHyprlandFocusGrab: CompositorService.useHyprlandFocusGrab
    property string layerNamespace: "dms:modal"
    property Component content: null
    property Item directContent: null
    property real modalWidth: 400
    property real modalHeight: 300
    property var targetScreen
    property bool showBackground: true
    property real backgroundOpacity: 0.5
    property string positioning: "center"
    property point customPosition: Qt.point(0, 0)
    property bool closeOnEscapeKey: true
    property bool closeOnBackgroundClick: true
    property string animationType: "scale"
    property int animationDuration: Theme.modalAnimationDuration
    property real animationScaleCollapsed: 0.96
    property real animationOffset: Theme.spacingL
    property list<real> animationEnterCurve: Theme.expressiveCurves.expressiveDefaultSpatial
    property list<real> animationExitCurve: Theme.expressiveCurves.emphasized
    property color backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    property color borderColor: Theme.outlineMedium
    property real borderWidth: 0
    property real cornerRadius: Theme.cornerRadius
    property bool enableShadow: true
    property bool shouldBeVisible: false
    property bool shouldHaveFocus: shouldBeVisible
    property bool allowFocusOverride: false
    property bool allowStacking: false
    property bool keepContentLoaded: false
    property bool keepPopoutsOpen: false
    property var customKeyboardFocus: null
    property bool useOverlayLayer: false

    signal opened
    signal dialogClosed
    signal backgroundClicked

    readonly property var contentLoader: impl.item ? impl.item.contentLoader : null
    readonly property alias modalFocusScope: _modalFocusScope

    FocusScope {
        id: _modalFocusScope
        objectName: "modalFocusScope"
        focus: true
        anchors.fill: parent
    }
    readonly property var contentWindow: impl.item ? impl.item.contentWindow : null
    readonly property var clickCatcher: impl.item ? impl.item.clickCatcher : null
    readonly property var effectiveScreen: impl.item ? impl.item.effectiveScreen : null
    readonly property real screenWidth: impl.item ? impl.item.screenWidth : 1920
    readonly property real screenHeight: impl.item ? impl.item.screenHeight : 1080
    readonly property real dpr: impl.item ? impl.item.dpr : 1
    readonly property bool isClosing: impl.item ? (impl.item.isClosing ?? false) : false
    readonly property real alignedX: impl.item ? impl.item.alignedX : 0
    readonly property real alignedY: impl.item ? impl.item.alignedY : 0
    readonly property real alignedWidth: impl.item ? impl.item.alignedWidth : 0
    readonly property real alignedHeight: impl.item ? impl.item.alignedHeight : 0

    function open() {
        if (impl.item)
            impl.item.open();
    }

    function close() {
        if (impl.item)
            impl.item.close();
    }

    function instantClose() {
        if (impl.item && typeof impl.item.instantClose === "function")
            impl.item.instantClose();
    }

    function toggle() {
        if (impl.item)
            impl.item.toggle();
    }

    readonly property var _desiredBackend: SettingsData.connectedFrameModeActive ? connectedComp : standaloneComp
    property var _resolvedBackend: null

    Component.onCompleted: _resolvedBackend = _desiredBackend

    Connections {
        target: SettingsData
        function onConnectedFrameModeActiveChanged() {
            root._maybeResolveBackend();
        }
    }

    // Defer Loader source-component swap until impl is fully closed; avoids
    // tearing down a modal mid-animation when frame mode is toggled.
    function _maybeResolveBackend() {
        if (_resolvedBackend === _desiredBackend)
            return;
        if (impl.item && (impl.item.shouldBeVisible || impl.item.isClosing))
            return;
        _resolvedBackend = _desiredBackend;
    }

    Loader {
        id: impl
        sourceComponent: root._resolvedBackend
        onItemChanged: if (item)
            root._wireBackend(item)
    }

    Component {
        id: standaloneComp
        DankModalStandalone {}
    }

    Component {
        id: connectedComp
        DankModalConnected {}
    }

    function _wireBackend(it) {
        if (!it)
            return;

        it.modalHandle = root;
        it.layerNamespace = Qt.binding(() => root.layerNamespace);
        it.content = Qt.binding(() => root.content);
        it.directContent = Qt.binding(() => root.directContent);
        it.modalWidth = Qt.binding(() => root.modalWidth);
        it.modalHeight = Qt.binding(() => root.modalHeight);
        it.targetScreen = Qt.binding(() => root.targetScreen);
        it.showBackground = Qt.binding(() => root.showBackground);
        it.backgroundOpacity = Qt.binding(() => root.backgroundOpacity);
        it.positioning = Qt.binding(() => root.positioning);
        it.customPosition = Qt.binding(() => root.customPosition);
        it.closeOnEscapeKey = Qt.binding(() => root.closeOnEscapeKey);
        it.closeOnBackgroundClick = Qt.binding(() => root.closeOnBackgroundClick);
        it.animationType = Qt.binding(() => root.animationType);
        it.animationDuration = Qt.binding(() => root.animationDuration);
        it.animationScaleCollapsed = Qt.binding(() => root.animationScaleCollapsed);
        it.animationOffset = Qt.binding(() => root.animationOffset);
        it.animationEnterCurve = Qt.binding(() => root.animationEnterCurve);
        it.animationExitCurve = Qt.binding(() => root.animationExitCurve);
        it.backgroundColor = Qt.binding(() => root.backgroundColor);
        it.borderColor = Qt.binding(() => root.borderColor);
        it.borderWidth = Qt.binding(() => root.borderWidth);
        it.cornerRadius = Qt.binding(() => root.cornerRadius);
        it.enableShadow = Qt.binding(() => root.enableShadow);
        it.allowFocusOverride = Qt.binding(() => root.allowFocusOverride);
        it.allowStacking = Qt.binding(() => root.allowStacking);
        it.keepContentLoaded = Qt.binding(() => root.keepContentLoaded);
        it.keepPopoutsOpen = Qt.binding(() => root.keepPopoutsOpen);
        it.customKeyboardFocus = Qt.binding(() => root.customKeyboardFocus);
        it.useOverlayLayer = Qt.binding(() => root.useOverlayLayer);

        it.shouldBeVisible = root.shouldBeVisible;
        it.shouldHaveFocus = root.shouldHaveFocus;

        if (it.modalFocusScope)
            _modalFocusScope.parent = it.modalFocusScope;
    }

    Connections {
        target: root
        function onShouldBeVisibleChanged() {
            if (impl.item && impl.item.shouldBeVisible !== root.shouldBeVisible)
                impl.item.shouldBeVisible = root.shouldBeVisible;
        }
        function onShouldHaveFocusChanged() {
            if (impl.item && impl.item.shouldHaveFocus !== root.shouldHaveFocus)
                impl.item.shouldHaveFocus = root.shouldHaveFocus;
        }
    }

    Connections {
        target: impl.item
        ignoreUnknownSignals: true

        function onShouldBeVisibleChanged() {
            if (impl.item && root.shouldBeVisible !== impl.item.shouldBeVisible)
                root.shouldBeVisible = impl.item.shouldBeVisible;
        }

        function onShouldHaveFocusChanged() {
            if (impl.item && root.shouldHaveFocus !== impl.item.shouldHaveFocus)
                root.shouldHaveFocus = impl.item.shouldHaveFocus;
        }

        function onOpened() {
            root.opened();
        }

        function onDialogClosed() {
            root.dialogClosed();
            root._maybeResolveBackend();
        }

        function onBackgroundClicked() {
            root.backgroundClicked();
        }
    }
}
