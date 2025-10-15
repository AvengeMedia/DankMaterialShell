import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

pragma ComponentBehavior: Bound

Variants {
    id: dockVariants
    model: SettingsData.getFilteredScreens("dock")

    property var contextMenu

    delegate: PanelWindow {
        id: dock

        WlrLayershell.namespace: "quickshell:dock"

        readonly property bool isVertical: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right

        anchors {
            top: !isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top) : true
            bottom: !isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom) : true
            left: !isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Left)
            right: !isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Right)
        }

        property var modelData: item
    property bool autoHide: SettingsData.dockAutoHide
    property real backgroundTransparency: SettingsData.dockTransparency
    property bool groupByApp: SettingsData.dockGroupByApp

    readonly property real widgetHeight: Math.max(20, 26 + SettingsData.dankBarInnerPadding * 0.6)
    readonly property real effectiveBarHeight: Math.max(widgetHeight + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))
    readonly property real barSpacing: {
        const barIsHorizontal = (SettingsData.dankBarPosition === SettingsData.Position.Top || SettingsData.dankBarPosition === SettingsData.Position.Bottom)
        const barIsVertical = (SettingsData.dankBarPosition === SettingsData.Position.Left || SettingsData.dankBarPosition === SettingsData.Position.Right)
        const samePosition = (SettingsData.dockPosition === SettingsData.dankBarPosition)
        const dockIsHorizontal = !isVertical
        const dockIsVertical = isVertical

        if (!SettingsData.dankBarVisible) return 0
        if (dockIsHorizontal && barIsHorizontal && samePosition) {
            return SettingsData.dankBarSpacing + effectiveBarHeight + SettingsData.dankBarBottomGap
        }
        if (dockIsVertical && barIsVertical && samePosition) {
            return SettingsData.dankBarSpacing + effectiveBarHeight + SettingsData.dankBarBottomGap
        }
        return 0
    }

    readonly property real dockMargin: SettingsData.dockSpacing
    readonly property real positionSpacing: barSpacing + SettingsData.dockBottomGap
    readonly property real _dpr: (dock.screen && dock.screen.devicePixelRatio) ? dock.screen.devicePixelRatio : 1
    function px(v) { return Math.round(v * _dpr) / _dpr }


    property bool contextMenuOpen: (dockVariants.contextMenu && dockVariants.contextMenu.visible && dockVariants.contextMenu.screen === modelData)
    property bool revealSticky: false

    Timer {
        id: revealHold
        interval: 250
        repeat: false
        onTriggered: dock.revealSticky = false
    }

    property bool reveal: {
        if (CompositorService.isNiri && NiriService.inOverview && SettingsData.dockOpenOnOverview) {
            return true
        }
        return !autoHide || dockMouseArea.containsMouse || dockApps.requestDockShow || contextMenuOpen || revealSticky
    }

    onContextMenuOpenChanged: {
        if (!contextMenuOpen && autoHide && !dockMouseArea.containsMouse) {
            revealSticky = true
            revealHold.restart()
        }
    }

    Connections {
        target: SettingsData
        function onDockTransparencyChanged() {
            dock.backgroundTransparency = SettingsData.dockTransparency
        }
    }

    screen: modelData
    visible: {
        if (CompositorService.isNiri && NiriService.inOverview) {
            return SettingsData.dockOpenOnOverview
        }
        return SettingsData.showDock
    }
    color: "transparent"


    exclusiveZone: {
        if (!SettingsData.showDock || autoHide) return -1
        if (barSpacing > 0) return -1
        return px(58 + SettingsData.dockSpacing + SettingsData.dockBottomGap)
    }

    mask: Region {
        item: dockMouseArea
    }

    Rectangle {
        id: appTooltip
        z: 1000

        property var hoveredButton: {
            if (!dockApps.children[0]) {
                return null
            }
            const layoutItem = dockApps.children[0]
            const flowLayout = layoutItem.children[0]
            let repeater = null
            for (var i = 0; i < flowLayout.children.length; i++) {
                const child = flowLayout.children[i]
                if (child && typeof child.count !== "undefined" && typeof child.itemAt === "function") {
                    repeater = child
                    break
                }
            }
            if (!repeater || !repeater.itemAt) {
                return null
            }
            for (var i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i)
                if (item && item.dockButton && item.dockButton.showTooltip) {
                    return item.dockButton
                }
            }
            return null
        }

        property string tooltipText: hoveredButton ? hoveredButton.tooltipText : ""

        visible: hoveredButton !== null && tooltipText !== ""
        width: px(tooltipLabel.implicitWidth + 24)
        height: px(tooltipLabel.implicitHeight + 12)

        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.width: 1
        border.color: Theme.outlineMedium

        x: {
            if (!hoveredButton) return 0
            const buttonPos = hoveredButton.mapToItem(dock.contentItem, 0, 0)
            if (!dock.isVertical) {
                return buttonPos.x + hoveredButton.width / 2 - width / 2
            } else {
                if (SettingsData.dockPosition === SettingsData.Position.Right) {
                    return buttonPos.x - width - Theme.spacingS
                } else {
                    return buttonPos.x + hoveredButton.width + Theme.spacingS
                }
            }
        }
        y: {
            if (!hoveredButton) return 0
            const buttonPos = hoveredButton.mapToItem(dock.contentItem, 0, 0)
            if (!dock.isVertical) {
                if (SettingsData.dockPosition === SettingsData.Position.Bottom) {
                    return buttonPos.y - height - Theme.spacingS
                } else {
                    return buttonPos.y + hoveredButton.height + Theme.spacingS
                }
            } else {
                return buttonPos.y + hoveredButton.height / 2 - height / 2
            }
        }

        StyledText {
            id: tooltipLabel
            anchors.centerIn: parent
            text: appTooltip.tooltipText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }

    Item {
        id: dockCore
        anchors.fill: parent

        Connections {
            target: dockMouseArea
            function onContainsMouseChanged() {
                if (dockMouseArea.containsMouse) {
                    dock.revealSticky = true
                    revealHold.stop()
                } else {
                    if (dock.autoHide && !dock.contextMenuOpen) {
                        revealHold.restart()
                    }
                }
            }
        }

        MouseArea {
            id: dockMouseArea
            property real currentScreen: modelData ? modelData : dock.screen
            property real screenWidth: currentScreen ? currentScreen.geometry.width : 1920
            property real screenHeight: currentScreen ? currentScreen.geometry.height : 1080
            property real maxDockWidth: Math.min(screenWidth * 0.8, 1200)
            property real maxDockHeight: Math.min(screenHeight * 0.8, 1200)

            height: {
                if (dock.isVertical) {
                    return dock.reveal ? Math.min(dockBackground.implicitHeight + 32, maxDockHeight) : Math.min(Math.max(dockBackground.implicitHeight + 64, 200), screenHeight * 0.5)
                } else {
                    return dock.reveal ? px(58 + SettingsData.dockSpacing + SettingsData.dockBottomGap) : 1
                }
            }
            width: {
                if (dock.isVertical) {
                    return dock.reveal ? px(58 + SettingsData.dockSpacing + SettingsData.dockBottomGap) : 1
                } else {
                    return dock.reveal ? Math.min(dockBackground.implicitWidth + 32, maxDockWidth) : Math.min(Math.max(dockBackground.implicitWidth + 64, 200), screenWidth * 0.5)
                }
            }
            anchors {
                top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? undefined : parent.top) : undefined
                bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined) : undefined
                horizontalCenter: !dock.isVertical ? parent.horizontalCenter : undefined
                left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? undefined : parent.left) : undefined
                right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined) : undefined
                verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
            }
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: dockContainer
                anchors.fill: parent

                transform: Translate {
                    id: dockSlide
                    x: {
                        if (!dock.isVertical) return 0
                        if (dock.reveal) return 0
                        const hideDistance = 58 + SettingsData.dockSpacing + SettingsData.dockBottomGap + 10
                        if (SettingsData.dockPosition === SettingsData.Position.Right) {
                            return hideDistance
                        } else {
                            return -hideDistance
                        }
                    }
                    y: {
                        if (dock.isVertical) return 0
                        if (dock.reveal) return 0
                        const hideDistance = 58 + SettingsData.dockSpacing + SettingsData.dockBottomGap + 10
                        if (SettingsData.dockPosition === SettingsData.Position.Bottom) {
                            return hideDistance
                        } else {
                            return -hideDistance
                        }
                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    id: dockBackground
                    objectName: "dockBackground"
                    anchors {
                        top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? undefined : parent.top) : undefined
                        bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined) : undefined
                        horizontalCenter: !dock.isVertical ? parent.horizontalCenter : undefined
                        left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? undefined : parent.left) : undefined
                        right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined) : undefined
                        verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
                    }
                    anchors.topMargin: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? 0 : barSpacing + 4) : 0
                    anchors.bottomMargin: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? barSpacing + 1 : 0) : 0
                    anchors.leftMargin: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? 0 : barSpacing + 4) : 0
                    anchors.rightMargin: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? barSpacing + 1 : 0) : 0

                    implicitWidth: dock.isVertical ? (dockApps.implicitHeight + SettingsData.dockSpacing * 2) : (dockApps.implicitWidth + SettingsData.dockSpacing * 2)
                    implicitHeight: dock.isVertical ? (dockApps.implicitWidth + SettingsData.dockSpacing * 2) : (dockApps.implicitHeight + SettingsData.dockSpacing * 2)
                    width: implicitWidth
                    height: implicitHeight

                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, backgroundTransparency)
                    radius: Theme.cornerRadius
                    border.width: 1
                    border.color: Theme.outlineMedium
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 0.04)
                        radius: parent.radius
                    }

                    DockApps {
                        id: dockApps

                        anchors.top: !dock.isVertical ? parent.top : undefined
                        anchors.bottom: !dock.isVertical ? parent.bottom : undefined
                        anchors.horizontalCenter: !dock.isVertical ? parent.horizontalCenter : undefined
                        anchors.left: dock.isVertical ? parent.left : undefined
                        anchors.right: dock.isVertical ? parent.right : undefined
                        anchors.verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
                        anchors.topMargin: !dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.bottomMargin: !dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.leftMargin: dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.rightMargin: dock.isVertical ? SettingsData.dockSpacing : 0

                        contextMenu: dockVariants.contextMenu
                        groupByApp: dock.groupByApp
                        isVertical: dock.isVertical
                    }
                }
            }
        }
        }
    }
}
