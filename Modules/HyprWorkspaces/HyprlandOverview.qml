import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

Scope {
    id: overviewScope

    property bool overviewOpen: false

    Loader {
        id: hyprlandLoader
        active: overviewScope.overviewOpen
        asynchronous: false

        sourceComponent: Variants {
            id: overviewVariants
            model: Quickshell.screens

            PanelWindow {
                id: root
                required property var modelData
                readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
                property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)

                screen: modelData
                visible: overviewScope.overviewOpen
                color: "transparent"

                WlrLayershell.namespace: "quickshell:overview"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

            HyprlandFocusGrab {
                id: grab
                windows: [root]
                active: false
                property bool hasBeenActivated: false
                onActiveChanged: {
                    if (active) {
                        hasBeenActivated = true
                    }
                }
                onCleared: () => {
                    if (hasBeenActivated && overviewScope.overviewOpen) {
                        overviewScope.overviewOpen = false
                    }
                }
            }

            Connections {
                target: overviewScope
                function onOverviewOpenChanged() {
                    if (overviewScope.overviewOpen) {
                        grab.hasBeenActivated = false
                        delayedGrabTimer.start()
                    } else {
                        delayedGrabTimer.stop()
                        grab.active = false
                        grab.hasBeenActivated = false
                    }
                }
            }

            Connections {
                target: root
                function onMonitorIsFocusedChanged() {
                    if (overviewScope.overviewOpen && root.monitorIsFocused && !grab.active) {
                        grab.hasBeenActivated = false
                        grab.active = true
                    } else if (overviewScope.overviewOpen && !root.monitorIsFocused && grab.active) {
                        grab.active = false
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: 150
                repeat: false
                onTriggered: {
                    if (overviewScope.overviewOpen && root.monitorIsFocused) {
                        grab.active = true
                    }
                }
            }

            Timer {
                id: closeTimer
                interval: Theme.expressiveDurations.expressiveDefaultSpatial + 120
                onTriggered: {
                    root.visible = false
                }
            }

            Rectangle {
                id: background
                anchors.fill: parent
                color: "black"
                opacity: overviewScope.overviewOpen ? 0.5 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => {
                        const localPos = mapToItem(contentContainer, mouse.x, mouse.y)
                        if (localPos.x < 0 || localPos.x > contentContainer.width || localPos.y < 0 || localPos.y > contentContainer.height) {
                            overviewScope.overviewOpen = false
                            closeTimer.restart()
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 100
                width: childrenRect.width
                height: childrenRect.height

                opacity: overviewScope.overviewOpen ? 1 : 0
                transform: [scaleTransform, motionTransform]

                Scale {
                    id: scaleTransform
                    origin.x: contentContainer.width / 2
                    origin.y: contentContainer.height / 2
                    xScale: overviewScope.overviewOpen ? 1 : 0.96
                    yScale: overviewScope.overviewOpen ? 1 : 0.96

                    Behavior on xScale {
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                        }
                    }

                    Behavior on yScale {
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                        }
                    }
                }

                Translate {
                    id: motionTransform
                    x: 0
                    y: overviewScope.overviewOpen ? 0 : Theme.spacingL

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: overviewScope.overviewOpen ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                    }
                }

                Loader {
                    id: overviewLoader
                    active: overviewScope.overviewOpen
                    asynchronous: false

                    sourceComponent: OverviewWidget {
                        panelWindow: root
                        overviewOpen: overviewScope.overviewOpen
                    }
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                visible: overviewScope.overviewOpen
                focus: overviewScope.overviewOpen && root.monitorIsFocused

                Keys.onEscapePressed: event => {
                    if (!root.monitorIsFocused) return
                    overviewScope.overviewOpen = false
                    closeTimer.restart()
                    event.accepted = true
                }

                Keys.onPressed: event => {
                    if (!root.monitorIsFocused) return

                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                        if (!overviewLoader.item) return

                        const thisMonitorWorkspaceIds = overviewLoader.item.thisMonitorWorkspaceIds
                        if (thisMonitorWorkspaceIds.length === 0) return

                        const currentId = root.monitor.activeWorkspace?.id ?? thisMonitorWorkspaceIds[0]
                        const currentIndex = thisMonitorWorkspaceIds.indexOf(currentId)

                        let targetIndex
                        if (event.key === Qt.Key_Left) {
                            targetIndex = currentIndex - 1
                            if (targetIndex < 0) targetIndex = thisMonitorWorkspaceIds.length - 1
                        } else {
                            targetIndex = currentIndex + 1
                            if (targetIndex >= thisMonitorWorkspaceIds.length) targetIndex = 0
                        }

                        const targetId = thisMonitorWorkspaceIds[targetIndex]
                        Hyprland.dispatch("workspace " + targetId)
                        event.accepted = true
                    }
                }

                onVisibleChanged: {
                    if (visible && overviewScope.overviewOpen && root.monitorIsFocused) {
                        Qt.callLater(() => focusScope.forceActiveFocus())
                    }
                }

                Connections {
                    target: root
                    function onMonitorIsFocusedChanged() {
                        if (root.monitorIsFocused && overviewScope.overviewOpen) {
                            Qt.callLater(() => focusScope.forceActiveFocus())
                        }
                    }
                }
            }

            onVisibleChanged: {
                if (visible && overviewScope.overviewOpen) {
                    Qt.callLater(() => focusScope.forceActiveFocus())
                } else if (!visible) {
                    grab.active = false
                }
            }

            Connections {
                target: overviewScope
                function onOverviewOpenChanged() {
                    if (overviewScope.overviewOpen) {
                        closeTimer.stop()
                        root.visible = true
                        Qt.callLater(() => focusScope.forceActiveFocus())
                    } else {
                        closeTimer.restart()
                        grab.active = false
                    }
                }
            }
        }
        }
    }
}
