import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property string layerNamespace: "dms:modal"
    WlrLayershell.namespace: layerNamespace

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property Item directContent: null
    property real width: 400
    property real height: 300
    readonly property real screenWidth: screen ? screen.width : 1920
    readonly property real screenHeight: screen ? screen.height : 1080
    readonly property real dpr: CompositorService.getScreenScale(screen)
    property bool showBackground: true
    property real backgroundOpacity: 0.5
    property string positioning: "center"
    property point customPosition: Qt.point(0, 0)
    property bool closeOnEscapeKey: true
    property bool closeOnBackgroundClick: true
    property string animationType: "scale"
    property int animationDuration: Theme.expressiveDurations.expressiveDefaultSpatial
    property real animationScaleCollapsed: 0.96
    property real animationOffset: Theme.spacingL
    property list<real> animationEnterCurve: Theme.expressiveCurves.expressiveDefaultSpatial
    property list<real> animationExitCurve: Theme.expressiveCurves.emphasized
    property color backgroundColor: Theme.surfaceContainer
    property color borderColor: Theme.outlineMedium
    property real borderWidth: 1
    property real cornerRadius: Theme.cornerRadius
    property bool enableShadow: false
    property alias modalFocusScope: focusScope
    property bool shouldBeVisible: false
    property bool shouldHaveFocus: shouldBeVisible
    property bool allowFocusOverride: false
    property bool allowStacking: false
    property bool keepContentLoaded: false
    property bool keepPopoutsOpen: false

    signal opened
    signal dialogClosed
    signal backgroundClicked

    function open() {
        ModalManager.openModal(root)
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        shouldHaveFocus = false
        Qt.callLater(() => {
            shouldHaveFocus = Qt.binding(() => shouldBeVisible)
        })
    }

    function close() {
        shouldBeVisible = false
        shouldHaveFocus = false
        closeTimer.restart()
    }

    function toggle() {
        if (shouldBeVisible) {
            close()
        } else {
            open()
        }
    }

    visible: shouldBeVisible
    color: "transparent"
    WlrLayershell.layer: {
        switch (Quickshell.env("DMS_MODAL_LAYER")) {
        case "bottom":
            return WlrLayershell.Bottom
        case "overlay":
            return WlrLayershell.Overlay
        case "background":
            return WlrLayershell.Background
        default:
            return WlrLayershell.Top
        }
    }
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: {
        if (!shouldHaveFocus) return WlrKeyboardFocus.None
        if (CompositorService.isHyprland) return WlrKeyboardFocus.OnDemand
        return WlrKeyboardFocus.Exclusive
    }

    HyprlandFocusGrab {
        windows: [root]
        active: CompositorService.isHyprland && shouldHaveFocus
    }

    onVisibleChanged: {
        if (root.visible) {
            opened()
        } else {
            if (Qt.inputMethod) {
                Qt.inputMethod.hide()
                Qt.inputMethod.reset()
            }
            dialogClosed()
        }
    }

    Connections {
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== root && !allowStacking && shouldBeVisible) {
                close()
            }
        }

        target: ModalManager
    }

    Timer {
        id: closeTimer

        interval: animationDuration + 120
        onTriggered: {
            visible = false
        }
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.closeOnBackgroundClick && root.shouldBeVisible
        onClicked: mouse => {
                       const localPos = mapToItem(contentContainer, mouse.x, mouse.y)
                       if (localPos.x < 0 || localPos.x > contentContainer.width || localPos.y < 0 || localPos.y > contentContainer.height) {
                           root.backgroundClicked()
                       }
                   }
    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: "black"
        opacity: root.showBackground && SettingsData.modalDarkenBackground ? (root.shouldBeVisible ? root.backgroundOpacity : 0) : 0
        visible: root.showBackground && SettingsData.modalDarkenBackground

        Behavior on opacity {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
            }
        }
    }

    Item {
        id: modalContainer

        width: Theme.px(root.width, dpr)
        height: Theme.px(root.height, dpr)
        x: {
            if (positioning === "center") {
                return Theme.snap((root.screenWidth - width) / 2, dpr)
            } else if (positioning === "top-right") {
                return Theme.px(Math.max(Theme.spacingL, root.screenWidth - width - Theme.spacingL), dpr)
            } else if (positioning === "custom") {
                return Theme.snap(root.customPosition.x, dpr)
            }
            return 0
        }
        y: {
            if (positioning === "center") {
                return Theme.snap((root.screenHeight - height) / 2, dpr)
            } else if (positioning === "top-right") {
                return Theme.px(Theme.barHeight + Theme.spacingXS, dpr)
            } else if (positioning === "custom") {
                return Theme.snap(root.customPosition.y, dpr)
            }
            return 0
        }

        readonly property bool slide: root.animationType === "slide"
        readonly property real offsetX: slide ? 15 : 0
        readonly property real offsetY: slide ? -30 : root.animationOffset

        property real animX: 0
        property real animY: 0
        property real scaleValue: root.animationScaleCollapsed

        onOffsetXChanged: animX = Theme.snap(root.shouldBeVisible ? 0 : offsetX, root.dpr)
        onOffsetYChanged: animY = Theme.snap(root.shouldBeVisible ? 0 : offsetY, root.dpr)

        Connections {
            target: root
            function onShouldBeVisibleChanged() {
                modalContainer.animX = Theme.snap(root.shouldBeVisible ? 0 : modalContainer.offsetX, root.dpr)
                modalContainer.animY = Theme.snap(root.shouldBeVisible ? 0 : modalContainer.offsetY, root.dpr)
                modalContainer.scaleValue = root.shouldBeVisible ? 1.0 : root.animationScaleCollapsed
            }
        }

        Behavior on animX {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
            }
        }

        Behavior on animY {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
            }
        }

        Behavior on scaleValue {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
            }
        }

        Item {
            id: contentContainer

            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            clip: false
            layer.enabled: true
            layer.smooth: false
            layer.textureSize: Qt.size(width * root.dpr, height * root.dpr)
            opacity: root.shouldBeVisible ? 1 : 0
            scale: modalContainer.scaleValue
            x: Theme.snap(modalContainer.animX + (parent.width - width) * (1 - modalContainer.scaleValue) * 0.5, root.dpr)
            y: Theme.snap(modalContainer.animY + (parent.height - height) * (1 - modalContainer.scaleValue) * 0.5, root.dpr)

            Behavior on opacity {
                NumberAnimation {
                    duration: animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            DankRectangle {
                anchors.fill: parent
                color: root.backgroundColor
                borderColor: root.borderColor
                borderWidth: root.borderWidth
                radius: root.cornerRadius
            }

            FocusScope {
                anchors.fill: parent
                focus: root.shouldBeVisible
                clip: false

                Item {
                    id: directContentWrapper

                    anchors.fill: parent
                    visible: root.directContent !== null
                    focus: true
                    clip: false

                    Component.onCompleted: {
                        if (root.directContent) {
                            root.directContent.parent = directContentWrapper
                            root.directContent.anchors.fill = directContentWrapper
                            Qt.callLater(() => root.directContent.forceActiveFocus())
                        }
                    }

                    Connections {
                        function onDirectContentChanged() {
                            if (root.directContent) {
                                root.directContent.parent = directContentWrapper
                                root.directContent.anchors.fill = directContentWrapper
                                Qt.callLater(() => root.directContent.forceActiveFocus())
                            }
                        }

                        target: root
                    }
                }

                Loader {
                    id: contentLoader

                    anchors.fill: parent
                    active: root.directContent === null && (root.keepContentLoaded || root.shouldBeVisible || root.visible)
                    asynchronous: false
                    focus: true
                    clip: false
                    visible: root.directContent === null

                    onLoaded: {
                        if (item) {
                            Qt.callLater(() => item.forceActiveFocus())
                        }
                    }
                }
            }
        }
    }

    FocusScope {
        id: focusScope

        objectName: "modalFocusScope"
        anchors.fill: parent
        visible: root.shouldBeVisible || root.visible
        focus: root.shouldBeVisible
        Keys.onEscapePressed: event => {
                                  if (root.closeOnEscapeKey && shouldHaveFocus) {
                                      root.close()
                                      event.accepted = true
                                  }
                              }
    }
}
