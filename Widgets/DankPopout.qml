import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property real popupWidth: 400
    property real popupHeight: 300
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 40
    property string positioning: "center"
    property int animationDuration: Theme.mediumDuration
    property var animationEasing: Theme.emphasizedEasing
    property bool shouldBeVisible: false

    signal opened
    signal popoutClosed
    signal backgroundClicked

    function open() {
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        opened()
    }

    function close() {
        shouldBeVisible = false
        closeTimer.restart()
    }

    function toggle() {
        if (shouldBeVisible)
            close()
        else
            open()
    }

    Timer {
        id: closeTimer
        interval: animationDuration + 50
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false
                popoutClosed()
            }
        }
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Top // if set to overlay -> virtual keyboards can be stuck under popup
    WlrLayershell.exclusiveZone: -1

    // WlrLayershell.keyboardFocus should be set to Exclusive,
    // if popup contains input fields and does NOT create new popups/modals
    // with input fields.
    // With OnDemand virtual keyboards can't send input to popup
    // If set to Exclusive AND this popup creates other popups, that also have
    // input fields -> they can't get keyboard focus, because the parent popup
    // already took the lock
    WlrLayershell.keyboardFocus: shouldBeVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None 

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    MouseArea {
        anchors.fill: parent
        enabled: shouldBeVisible
        onClicked: mouse => {
                       var localPos = mapToItem(contentContainer, mouse.x, mouse.y)
                       if (localPos.x < 0 || localPos.x > contentContainer.width || localPos.y < 0 || localPos.y > contentContainer.height) {
                           backgroundClicked()
                           close()
                       }
                   }
    }

    Item {
        id: contentContainer

        readonly property real screenWidth: root.screen ? root.screen.width : 1920
        readonly property real screenHeight: root.screen ? root.screen.height : 1080
        readonly property real calculatedX: {
            if (positioning === "center") {
                var centerX = triggerX + (triggerWidth / 2) - (popupWidth / 2)
                return Math.max(Theme.spacingM, Math.min(screenWidth - popupWidth - Theme.spacingM, centerX))
            } else if (positioning === "left") {
                return Math.max(Theme.spacingM, triggerX)
            } else if (positioning === "right") {
                return Math.min(screenWidth - popupWidth - Theme.spacingM, triggerX + triggerWidth - popupWidth)
            }
            return triggerX
        }
        readonly property real calculatedY: triggerY

        width: popupWidth
        height: popupHeight
        x: calculatedX
        y: calculatedY
        opacity: shouldBeVisible ? 1 : 0
        scale: shouldBeVisible ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            active: root.visible
            asynchronous: false
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    close()
                                    event.accepted = true
                                }
                            }
            Component.onCompleted: forceActiveFocus()
            onVisibleChanged: if (visible)
                                  forceActiveFocus()
        }
    }
}
