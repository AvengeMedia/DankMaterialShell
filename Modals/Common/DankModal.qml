import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property real width: 400
    property real height: 300
    readonly property real screenWidth: screen ? screen.width : 1920
    readonly property real screenHeight: screen ? screen.height : 1080
    property bool showBackground: true
    property real backgroundOpacity: 0.5
    property string positioning: "center"
    property point customPosition: Qt.point(0, 0)
    property bool closeOnEscapeKey: true
    property bool closeOnBackgroundClick: true
    property string animationType: "scale"
    property int animationDuration: Theme.shorterDuration
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

        interval: animationDuration + 50
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

        width: root.width
        height: root.height
        anchors.centerIn: positioning === "center" ? parent : undefined
        x: {
            if (positioning === "top-right") {
                return Math.max(Theme.spacingL, root.screenWidth - width - Theme.spacingL)
            } else if (positioning === "custom") {
                return root.customPosition.x
            }
            return 0
        }
        y: {
            if (positioning === "top-right") {
                return Theme.barHeight + Theme.spacingXS
            } else if (positioning === "custom") {
                return root.customPosition.y
            }
            return 0
        }
        color: root.backgroundColor
        radius: root.cornerRadius
        border.color: root.borderColor
        border.width: root.borderWidth
        layer.enabled: root.enableShadow
        opacity: root.shouldBeVisible ? 1 : 0
        scale: root.animationType === "scale" ? (root.shouldBeVisible ? 1 : 0.9) : 1
        transform: root.animationType === "slide" ? slideTransform : null

        Translate {
            id: slideTransform

            x: root.shouldBeVisible ? 0 : 15
            y: root.shouldBeVisible ? 0 : -30
        }

        Loader {
            id: contentLoader

            anchors.fill: parent
            active: root.visible
            asynchronous: false
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: root.animationEasing
            }
        }

        Behavior on scale {
            enabled: root.animationType === "scale"

            NumberAnimation {
                duration: root.animationDuration
                easing.type: root.animationEasing
            }
        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 8
            shadowBlur: 1
            shadowColor: Theme.shadowStrong
            shadowOpacity: 0.3
        }
    }

    FocusScope {
        id: focusScope

        objectName: "modalFocusScope"
        anchors.fill: parent
        visible: root.visible // Only active when the modal is visible
        focus: root.visible
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
                if (shouldHaveFocus && visible) {
                    Qt.callLater(() => focusScope.forceActiveFocus())
                }
            }

            target: root
        }
    }
}
