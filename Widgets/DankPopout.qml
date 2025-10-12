import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services

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
    property int animationDuration: Theme.shortDuration
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

    readonly property real screenWidth: root.screen.width
    readonly property real screenHeight: root.screen.height
    readonly property real dpr: {
        if (CompositorService.isNiri && root.screen) {
            const niriScale = NiriService.displayScales[root.screen.name]
            if (niriScale !== undefined) return niriScale
        }
        if (CompositorService.isHyprland && root.screen) {
            const hyprlandMonitor = Hyprland.monitors.values.find(m => m.name === root.screen.name)
            if (hyprlandMonitor?.scale !== undefined) return hyprlandMonitor.scale
        }
        return root.screen?.devicePixelRatio || 1
    }

    readonly property real alignedWidth: Theme.px(popupWidth, dpr)
    readonly property real alignedHeight: Theme.px(popupHeight, dpr)
    readonly property real alignedX: Theme.snap((() => {
        if (SettingsData.dankBarPosition === SettingsData.Position.Left) {
            return triggerY + SettingsData.dankBarBottomGap
        } else if (SettingsData.dankBarPosition === SettingsData.Position.Right) {
            return screenWidth - triggerY - SettingsData.dankBarBottomGap - popupWidth
        } else {
            const centerX = triggerX + (triggerWidth / 2) - (popupWidth / 2)
            return Math.max(Theme.popupDistance, Math.min(screenWidth - popupWidth - Theme.popupDistance, centerX))
        }
    })(), dpr)
    readonly property real alignedY: Theme.snap((() => {
        if (SettingsData.dankBarPosition === SettingsData.Position.Left || SettingsData.dankBarPosition === SettingsData.Position.Right) {
            const centerY = triggerX + (triggerWidth / 2) - (popupHeight / 2)
            return Math.max(Theme.popupDistance, Math.min(screenHeight - popupHeight - Theme.popupDistance, centerY))
        } else if (SettingsData.dankBarPosition === SettingsData.Position.Bottom) {
            return Math.max(Theme.popupDistance, screenHeight - triggerY - popupHeight)
        } else {
            return Math.min(screenHeight - popupHeight - Theme.popupDistance, triggerY)
        }
    })(), dpr)

    MouseArea {
        anchors.fill: parent
        enabled: shouldBeVisible
        onClicked: mouse => {
            if (mouse.x < alignedX || mouse.x > alignedX + alignedWidth ||
                mouse.y < alignedY || mouse.y > alignedY + alignedHeight) {
                backgroundClicked()
                close()
            }
        }
    }

    Loader {
        id: contentLoader
        x: alignedX
        y: alignedY
        width: alignedWidth
        height: alignedHeight
        active: root.visible
        asynchronous: false
        layer.enabled: Quickshell.env("DMS_DISABLE_LAYER") !== "true"
        opacity: shouldBeVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }
    }

    Item {
        x: alignedX
        y: alignedY
        width: alignedWidth
        height: alignedHeight
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                close()
                event.accepted = true
            }
        }
        Component.onCompleted: forceActiveFocus()
        onVisibleChanged: if (visible) forceActiveFocus()
    }
}
