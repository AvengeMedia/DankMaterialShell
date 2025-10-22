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

    readonly property real widgetHeight: SettingsData.dockIconSize
    readonly property real effectiveBarHeight: widgetHeight + SettingsData.dockSpacing * 2 + 10
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
        return px(effectiveBarHeight + SettingsData.dockSpacing + SettingsData.dockBottomGap)
    }

    property real animationHeadroom: Math.ceil(SettingsData.dockIconSize * 0.35)

    implicitWidth: isVertical ? (px(effectiveBarHeight + SettingsData.dockSpacing + SettingsData.dockBottomGap + SettingsData.dockIconSize * 0.3) + animationHeadroom) : 0
    implicitHeight: !isVertical ? (px(effectiveBarHeight + SettingsData.dockSpacing + SettingsData.dockBottomGap + SettingsData.dockIconSize * 0.3) + animationHeadroom) : 0

    Item {
        id: maskItem
        parent: dock.contentItem
        visible: false
        x: {
            const baseX = dockCore.x + dockMouseArea.x
            if (isVertical && SettingsData.dockPosition === SettingsData.Position.Right) {
                return baseX - animationHeadroom
            }
            return baseX
        }
        y: {
            const baseY = dockCore.y + dockMouseArea.y
            if (!isVertical && SettingsData.dockPosition === SettingsData.Position.Bottom) {
                return baseY - animationHeadroom
            }
            return baseY
        }
        width: dockMouseArea.width + (isVertical ? animationHeadroom : 0)
        height: dockMouseArea.height + (!isVertical ? animationHeadroom : 0)
    }

    mask: Region {
        item: maskItem
    }

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

    DankTooltip {
        id: dockTooltip
        targetScreen: dock.screen
    }

    Timer {
        id: tooltipRevealDelay
        interval: 250
        repeat: false
        onTriggered: dock.showTooltipForHoveredButton()
    }

    function showTooltipForHoveredButton() {
        dockTooltip.hide()
        if (dock.hoveredButton && dock.reveal && !slideXAnimation.running && !slideYAnimation.running) {
            const buttonGlobalPos = dock.hoveredButton.mapToGlobal(0, 0)
            const tooltipText = dock.hoveredButton.tooltipText || ""
            if (tooltipText) {
                const screenX = dock.screen ? (dock.screen.x || 0) : 0
                const screenY = dock.screen ? (dock.screen.y || 0) : 0
                const screenHeight = dock.screen ? dock.screen.height : 0
                if (!dock.isVertical) {
                    const isBottom = SettingsData.dockPosition === SettingsData.Position.Bottom
                    const globalX = buttonGlobalPos.x + dock.hoveredButton.width / 2
                    const screenRelativeY = isBottom
                        ? (screenHeight - dock.effectiveBarHeight - SettingsData.dockSpacing - SettingsData.dockBottomGap - 35)
                        : (buttonGlobalPos.y - screenY + dock.hoveredButton.height + Theme.spacingS)
                    dockTooltip.show(tooltipText,
                                   globalX,
                                   screenRelativeY,
                                   dock.screen,
                                   false, false)
                } else {
                    const isLeft = SettingsData.dockPosition === SettingsData.Position.Left
                    const tooltipOffset = dock.effectiveBarHeight + SettingsData.dockSpacing + Theme.spacingXS
                    const tooltipX = isLeft ? tooltipOffset : (dock.screen.width - tooltipOffset)
                    const screenRelativeY = buttonGlobalPos.y - screenY + dock.hoveredButton.height / 2
                    dockTooltip.show(tooltipText,
                                   screenX + tooltipX,
                                   screenRelativeY,
                                   dock.screen,
                                   isLeft,
                                   !isLeft)
                }
            }
        }
    }

    Connections {
        target: dock
        function onRevealChanged() {
            if (!dock.reveal) {
                tooltipRevealDelay.stop()
                dockTooltip.hide()
            } else {
                tooltipRevealDelay.restart()
            }
        }

        function onHoveredButtonChanged() {
            dock.showTooltipForHoveredButton()
        }
    }

    Item {
        id: dockCore
        anchors.fill: parent
        x: isVertical && SettingsData.dockPosition === SettingsData.Position.Right ? animationHeadroom : 0
        y: !isVertical && SettingsData.dockPosition === SettingsData.Position.Bottom ? animationHeadroom : 0

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
            property real maxDockWidth: screenWidth * 0.98
            property real maxDockHeight: screenHeight * 0.98

            height: {
                if (dock.isVertical) {
                    return dock.reveal ? Math.min(dockBackground.implicitHeight + 4, maxDockHeight) : Math.min(Math.max(dockBackground.implicitHeight + 64, 200), screenHeight * 0.5)
                } else {
                    return dock.reveal ? px(dock.effectiveBarHeight + SettingsData.dockSpacing + SettingsData.dockBottomGap) : 1
                }
            }
            width: {
                if (dock.isVertical) {
                    return dock.reveal ? px(dock.effectiveBarHeight + SettingsData.dockSpacing + SettingsData.dockBottomGap) : 1
                } else {
                    return dock.reveal ? Math.min(dockBackground.implicitWidth + 4, maxDockWidth) : Math.min(Math.max(dockBackground.implicitWidth + 64, 200), screenWidth * 0.5)
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
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: dockContainer
                anchors.fill: parent
                clip: false

                transform: Translate {
                    id: dockSlide
                    x: {
                        if (!dock.isVertical) return 0
                        if (dock.reveal) return 0
                        const hideDistance = dock.effectiveBarHeight + SettingsData.dockSpacing + SettingsData.dockBottomGap + 10
                        if (SettingsData.dockPosition === SettingsData.Position.Right) {
                            return hideDistance
                        } else {
                            return -hideDistance
                        }
                    }
                    y: {
                        if (dock.isVertical) return 0
                        if (dock.reveal) return 0
                        const hideDistance = dock.effectiveBarHeight + SettingsData.dockSpacing + SettingsData.dockBottomGap + 10
                        if (SettingsData.dockPosition === SettingsData.Position.Bottom) {
                            return hideDistance
                        } else {
                            return -hideDistance
                        }
                    }

                    Behavior on x {
                        NumberAnimation {
                            id: slideXAnimation
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            id: slideYAnimation
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    id: dockBackground
                    objectName: "dockBackground"
                    anchors {
                        top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top ? parent.top : undefined) : undefined
                        bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined) : undefined
                        horizontalCenter: !dock.isVertical ? parent.horizontalCenter : undefined
                        left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Left ? parent.left : undefined) : undefined
                        right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined) : undefined
                        verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
                    }
                    anchors.topMargin: !dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Top ? barSpacing + 1 : 0
                    anchors.bottomMargin: !dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Bottom ? barSpacing + 1 : 0
                    anchors.leftMargin: dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Left ? barSpacing + 1 : 0
                    anchors.rightMargin: dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Right ? barSpacing + 1 : 0

                    implicitWidth: dock.isVertical ? (dockApps.implicitHeight + SettingsData.dockSpacing * 2) : (dockApps.implicitWidth + SettingsData.dockSpacing * 2)
                    implicitHeight: dock.isVertical ? (dockApps.implicitWidth + SettingsData.dockSpacing * 2) : (dockApps.implicitHeight + SettingsData.dockSpacing * 2)
                    width: implicitWidth
                    height: implicitHeight

                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, backgroundTransparency)
                    radius: Theme.cornerRadius
                    border.width: 1
                    border.color: Theme.outlineMedium
                    clip: false

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 0.04)
                        radius: parent.radius
                    }
                }

                DockApps {
                    id: dockApps

                    anchors.top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top ? dockBackground.top : undefined) : undefined
                    anchors.bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? dockBackground.bottom : undefined) : undefined
                    anchors.horizontalCenter: !dock.isVertical ? dockBackground.horizontalCenter : undefined
                    anchors.left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Left ? dockBackground.left : undefined) : undefined
                    anchors.right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? dockBackground.right : undefined) : undefined
                    anchors.verticalCenter: dock.isVertical ? dockBackground.verticalCenter : undefined
                    anchors.topMargin: !dock.isVertical ? SettingsData.dockSpacing : 0
                    anchors.bottomMargin: !dock.isVertical ? SettingsData.dockSpacing : 0
                    anchors.leftMargin: dock.isVertical ? SettingsData.dockSpacing : 0
                    anchors.rightMargin: dock.isVertical ? SettingsData.dockSpacing : 0

                    contextMenu: dockVariants.contextMenu
                    groupByApp: dock.groupByApp
                    isVertical: dock.isVertical
                    dockScreen: dock.screen
                    iconSize: dock.widgetHeight
                }
            }
        }
        }
    }
}
