import QtQuick
import qs.Common

Item {
    id: root
    readonly property var log: Log.scoped("DankModal")

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

    Loader {
        id: impl
        sourceComponent: SettingsData.connectedFrameModeActive ? connectedComp : standaloneComp
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
        it.shouldBeVisibleChanged.connect(function () {
            if (root.shouldBeVisible !== it.shouldBeVisible)
                root.shouldBeVisible = it.shouldBeVisible;
        });

        it.shouldHaveFocus = root.shouldHaveFocus;
        it.shouldHaveFocusChanged.connect(function () {
            if (root.shouldHaveFocus !== it.shouldHaveFocus)
                root.shouldHaveFocus = it.shouldHaveFocus;
        });

        it.opened.connect(root.opened);
        it.dialogClosed.connect(root.dialogClosed);
        it.backgroundClicked.connect(root.backgroundClicked);

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
}
