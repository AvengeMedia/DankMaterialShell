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

        anchors {
            top: SettingsData.dockPosition === SettingsData.Position.Top
            bottom: SettingsData.dockPosition === SettingsData.Position.Bottom
            left: true
            right: true
        }

        property var modelData: item
    property bool autoHide: SettingsData.dockAutoHide
    property real backgroundTransparency: SettingsData.dockTransparency
    property bool groupByApp: SettingsData.dockGroupByApp

    readonly property bool isDockAtTop: SettingsData.dockPosition === SettingsData.Position.Top
    readonly property bool isDankBarAtTop: !SettingsData.dankBarAtBottom
    readonly property bool isDankBarVisible: SettingsData.dankBarVisible
    readonly property bool needsBarSpacing: isDankBarVisible && (isDockAtTop === isDankBarAtTop)
    readonly property real widgetHeight: Math.max(20, 26 + SettingsData.dankBarInnerPadding * 0.6)
    readonly property real effectiveBarHeight: Math.max(widgetHeight + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))
    readonly property real barSpacing: needsBarSpacing ? (SettingsData.dankBarSpacing + effectiveBarHeight + SettingsData.dankBarBottomGap) : 0

    readonly property real dockMargin: SettingsData.dockSpacing
    readonly property real positionSpacing: barSpacing + SettingsData.dockBottomGap
    readonly property real _dpr: (dock.screen && dock.screen.devicePixelRatio) ? dock.screen.devicePixelRatio : 1
    function px(v) { return Math.round(v * _dpr) / _dpr }


    property bool contextMenuOpen: (dockVariants.contextMenu && dockVariants.contextMenu.visible && dockVariants.contextMenu.screen === modelData)
    property bool windowIsFullscreen: {
        if (!ToplevelManager.activeToplevel) {
            return false
        }
        const activeWindow = ToplevelManager.activeToplevel
        const fullscreenApps = ["vlc", "mpv", "kodi", "steam", "lutris", "wine", "dosbox"]
        return fullscreenApps.some(app => activeWindow.appId && activeWindow.appId.toLowerCase().includes(app))
    }
    property bool revealSticky: false

    Timer {
        id: revealHold
        interval: 250
        repeat: false
        onTriggered: dock.revealSticky = false
    }

    property bool reveal: {
        if (CompositorService.isNiri && NiriService.inOverview) {
            return SettingsData.dockOpenOnOverview
        }
        return (!autoHide || dockMouseArea.containsMouse || dockApps.requestDockShow || contextMenuOpen || revealSticky) && !windowIsFullscreen
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
    visible: SettingsData.showDock
    color: "transparent"


    exclusiveZone: {
        if (!SettingsData.showDock || autoHide) return -1
        if (needsBarSpacing) return -1
        return px(58 + SettingsData.dockSpacing + SettingsData.dockBottomGap)
    }

    mask: Region {
        item: dockMouseArea
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
            property real maxDockWidth: Math.min(screenWidth * 0.8, 1200)

            height: dock.reveal ? px(58 + SettingsData.dockSpacing + SettingsData.dockBottomGap) : 1
            width: dock.reveal ? Math.min(dockBackground.implicitWidth + 32, maxDockWidth) : Math.min(Math.max(dockBackground.implicitWidth + 64, 200), screenWidth * 0.5)
            anchors {
                top: SettingsData.dockPosition === SettingsData.Position.Bottom ? undefined : parent.top
                bottom: SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined
                horizontalCenter: parent.horizontalCenter
            }
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            Behavior on height {
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
                    y: {
                        if (dock.reveal) return 0
                        if (SettingsData.dockPosition === SettingsData.Position.Bottom) {
                            return 60
                        } else {
                            return -60
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
                        top: SettingsData.dockPosition === SettingsData.Position.Bottom ? undefined : parent.top
                        bottom: SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined
                        horizontalCenter: parent.horizontalCenter
                    }
                    anchors.topMargin: SettingsData.dockPosition === SettingsData.Position.Bottom ? 0 : barSpacing + 4
                    anchors.bottomMargin: SettingsData.dockPosition === SettingsData.Position.Bottom ? barSpacing + 1 : 0

                    implicitWidth: dockApps.implicitWidth + SettingsData.dockSpacing * 2
                    implicitHeight: dockApps.implicitHeight + SettingsData.dockSpacing * 2
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

                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: SettingsData.dockSpacing
                        anchors.bottomMargin: SettingsData.dockSpacing

                        contextMenu: dockVariants.contextMenu
                        groupByApp: dock.groupByApp
                    }
                }

            Rectangle {
                id: appTooltip

                property var hoveredButton: {
                    if (!dockApps.children[0]) {
                        return null
                    }
                    const row = dockApps.children[0]
                    let repeater = null
                    for (var i = 0; i < row.children.length; i++) {
                        const child = row.children[i]
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

                y: SettingsData.dockPosition === SettingsData.Position.Bottom ? -height - Theme.spacingS : parent.height + Theme.spacingS
                x: hoveredButton ? hoveredButton.mapToItem(dockContainer, hoveredButton.width / 2, 0).x - width / 2 : 0

                StyledText {
                    id: tooltipLabel
                    anchors.centerIn: parent
                    text: appTooltip.tooltipText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }
        }
        }
        }
    }
}
