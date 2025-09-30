import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:popout"

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property real popupWidth: 400
    property real popupHeight: 300
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 40
    property string triggerSection: ""
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
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: -1
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
        layer.enabled: false

        readonly property real screenWidth: root.screen ? root.screen.width : 1920
        readonly property real screenHeight: root.screen ? root.screen.height : 1080
        readonly property real gothOffset: SettingsData.dankBarGothCornersEnabled ? Theme.cornerRadius : 0
        readonly property real calculatedX: {
            if (SettingsData.dankBarPosition === SettingsData.Position.Left) {
                return triggerY
            } else if (SettingsData.dankBarPosition === SettingsData.Position.Right) {
                return screenWidth - triggerY - popupWidth
            } else {
                const centerX = triggerX + (triggerWidth / 2) - (popupWidth / 2)
                return Math.max(Theme.popupDistance, Math.min(screenWidth - popupWidth - Theme.popupDistance, centerX))
            }
        }
        readonly property real calculatedY: {
            if (SettingsData.dankBarPosition === SettingsData.Position.Left || SettingsData.dankBarPosition === SettingsData.Position.Right) {
                const centerY = triggerX + (triggerWidth / 2) - (popupHeight / 2)
                return Math.max(Theme.popupDistance, Math.min(screenHeight - popupHeight - Theme.popupDistance, centerY))
            } else if (SettingsData.dankBarPosition === SettingsData.Position.Bottom) {
                return Math.max(Theme.popupDistance, Math.min(screenHeight - popupHeight - Theme.popupDistance, screenHeight - triggerY - popupHeight + Theme.popupDistance))
            } else {
                return Math.max(Theme.popupDistance, Math.min(screenHeight - popupHeight - Theme.popupDistance, triggerY + Theme.popupDistance))
            }
        }
        
        width: Math.round(popupWidth)
        height: Math.round(popupHeight)
        x: Math.round(calculatedX)
        y: Math.round(calculatedY)
        opacity: shouldBeVisible ? 1 : 0
        scale: 1

        Behavior on opacity {
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
