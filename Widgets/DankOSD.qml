import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: root

    property string blurNamespace: "dms:osd"
    WlrLayershell.namespace: blurNamespace

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property var modelData
    property bool shouldBeVisible: false
    property int autoHideInterval: 2000
    property bool enableMouseInteraction: false
    property real osdWidth: Theme.iconSize + Theme.spacingS * 2
    property real osdHeight: Theme.iconSize + Theme.spacingS * 2
    property int animationDuration: Theme.mediumDuration
    property var animationEasing: Theme.emphasizedEasing

    signal osdShown
    signal osdHidden

    function show() {
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        hideTimer.restart()
        osdShown()
    }

    function hide() {
        shouldBeVisible = false
        closeTimer.restart()
    }

    function resetHideTimer() {
        if (shouldBeVisible) {
            hideTimer.restart()
        }
    }

    function updateHoverState() {
        let isHovered = (enableMouseInteraction && mouseArea.containsMouse) || osdContainer.childHovered
        if (enableMouseInteraction) {
            if (isHovered) {
                hideTimer.stop()
            } else if (shouldBeVisible) {
                hideTimer.restart()
            }
        }
    }

    function setChildHovered(hovered) {
        osdContainer.childHovered = hovered
        updateHoverState()
    }

    screen: modelData
    visible: false
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    readonly property real dpr: CompositorService.getScreenScale(screen)
    readonly property real screenWidth: screen.width
    readonly property real screenHeight: screen.height
    readonly property real alignedWidth: Theme.px(osdWidth, dpr)
    readonly property real alignedHeight: Theme.px(osdHeight, dpr)
    readonly property real alignedX: Theme.snap((screenWidth - alignedWidth) / 2, dpr)
    readonly property real alignedY: Theme.snap(screenHeight - alignedHeight - Theme.spacingM, dpr)

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Timer {
        id: hideTimer

        interval: autoHideInterval
        repeat: false
        onTriggered: {
            if (!enableMouseInteraction || !mouseArea.containsMouse) {
                hide()
            } else {
                hideTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: animationDuration + 50
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false
                osdHidden()
            }
        }
    }

    Item {
        id: osdContainer
        x: alignedX
        y: alignedY
        width: alignedWidth
        height: alignedHeight
        opacity: shouldBeVisible ? 1 : 0
        scale: shouldBeVisible ? 1 : 0.9

        property bool childHovered: false

        Rectangle {
            id: osdBackground
            anchors.fill: parent
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: enableMouseInteraction
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            z: -1
            onContainsMouseChanged: updateHoverState()
        }

        onChildHoveredChanged: updateHoverState()

        Loader {
            id: contentLoader
            anchors.fill: parent
            active: root.visible
            asynchronous: false
        }

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
    }

    mask: Region {
        item: osdBackground
    }
}
