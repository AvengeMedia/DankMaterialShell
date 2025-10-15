import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:modal"

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property Item directContent: null
    property real width: 400
    property real height: 300
    readonly property real screenWidth: screen ? screen.width : 1920
    readonly property real screenHeight: screen ? screen.height : 1080
    readonly property real dpr: {
        if (CompositorService.isNiri && screen) {
            const niriScale = NiriService.displayScales[screen.name]
            if (niriScale !== undefined) return niriScale
        }
        if (CompositorService.isHyprland && screen) {
            const hyprlandMonitor = Hyprland.monitors.values.find(m => m.name === screen.name)
            if (hyprlandMonitor?.scale !== undefined) return hyprlandMonitor.scale
        }
        return (screen?.devicePixelRatio) || 1
    }
    property bool showBackground: true
    property real backgroundOpacity: 0.5
    property string positioning: "center"
    property point customPosition: Qt.point(0, 0)
    property bool closeOnEscapeKey: true
    property bool closeOnBackgroundClick: true
    property string animationType: "scale"
    property int animationDuration: Theme.shortDuration
    property var animationEasing: Theme.emphasizedEasing
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

    signal opened
    signal dialogClosed
    signal backgroundClicked

    function open() {
        ModalManager.openModal(root)
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        focusScope.forceActiveFocus()
    }

    function close() {
        shouldBeVisible = false
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
    WlrLayershell.layer: WlrLayershell.Top // if set to overlay -> virtual keyboards can be stuck under modal
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: shouldHaveFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

        interval: animationDuration + 100
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

    Rectangle {
        id: background

        anchors.fill: parent
        color: "black"
        opacity: root.showBackground ? (root.shouldBeVisible ? root.backgroundOpacity : 0) : 0
        visible: root.showBackground

        MouseArea {
            anchors.fill: parent
            enabled: root.closeOnBackgroundClick
            onClicked: mouse => {
                           const localPos = mapToItem(contentContainer, mouse.x, mouse.y)
                           if (localPos.x < 0 || localPos.x > contentContainer.width || localPos.y < 0 || localPos.y > contentContainer.height) {
                               root.backgroundClicked()
                           }
                       }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: root.animationEasing
            }
        }
    }

    Rectangle {
        id: contentContainer

        width: Theme.px(root.width, dpr)
        height: Theme.px(root.height, dpr)
        anchors.centerIn: undefined
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
        color: root.backgroundColor
        radius: root.cornerRadius
        border.color: root.borderColor
        border.width: root.borderWidth
        clip: false
        layer.enabled: true
        opacity: root.shouldBeVisible ? 1 : 0
        transform: root.animationType === "slide" ? slideTransform : null

        Translate {
            id: slideTransform

            readonly property real rawX: root.shouldBeVisible ? 0 : 15
            readonly property real rawY: root.shouldBeVisible ? 0 : -30

            x: Theme.snap(rawX, root.dpr)
            y: Theme.snap(rawY, root.dpr)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
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
        onVisibleChanged: {
            if (visible && shouldHaveFocus) {
                Qt.callLater(() => focusScope.forceActiveFocus())
            }
        }

        Connections {
            function onShouldHaveFocusChanged() {
                if (shouldHaveFocus && shouldBeVisible) {
                    Qt.callLater(() => focusScope.forceActiveFocus())
                }
            }

            target: root
        }
    }
}
