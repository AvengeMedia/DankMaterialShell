import QtQuick
import QtQuick.Controls
import Quickshell
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

                WlrLayershell.namespace: "dms:workspace-overview"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: {
                    if (!overviewScope.overviewOpen)
                        return WlrKeyboardFocus.None;
                    if (CompositorService.useHyprlandFocusGrab)
                        return WlrKeyboardFocus.OnDemand;
                    return WlrKeyboardFocus.Exclusive;
                }

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
                        if (CompositorService.useHyprlandFocusGrab)
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
                    if (!CompositorService.useHyprlandFocusGrab)
                        return;
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
                    if (CompositorService.useHyprlandFocusGrab && overviewScope.overviewOpen && root.monitorIsFocused) {
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
                        duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewScope.overviewOpen)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: overviewScope.overviewOpen ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
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
                    xScale: overviewScope.overviewOpen ? 1 : Theme.effectScaleCollapsed
                    yScale: overviewScope.overviewOpen ? 1 : Theme.effectScaleCollapsed

                    Behavior on xScale {
                        NumberAnimation {
                            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewScope.overviewOpen)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
                        }
                    }

                    Behavior on yScale {
                        NumberAnimation {
                            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewScope.overviewOpen)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
                        }
                    }
                }

                Translate {
                    id: motionTransform
                    x: {
                        if (overviewScope.overviewOpen)
                            return 0;
                        if (Theme.isDirectionalEffect)
                            return 0;
                        if (Theme.isDepthEffect)
                            return Theme.effectAnimOffset * 0.25;
                        return 0;
                    }
                    y: {
                        if (overviewScope.overviewOpen)
                            return 0;
                        if (Theme.isDirectionalEffect)
                            return -Math.max(contentContainer.height * 0.8, Theme.effectAnimOffset * 1.1);
                        if (Theme.isDepthEffect)
                            return Math.max(Theme.effectAnimOffset * 0.85, 28);
                        return Theme.effectAnimOffset;
                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewScope.overviewOpen)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewScope.overviewOpen)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: overviewScope.overviewOpen ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewScope.overviewOpen)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: overviewScope.overviewOpen ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
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
