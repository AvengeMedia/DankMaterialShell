import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string section: "left"
    property var parentScreen
    property var hoveredItem: null
    property var topBar: null
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS
    // The visual root for this window
    property Item windowRoot: (Window.window ? Window.window.contentItem : null)
    readonly property var sortedToplevels: {
            if (SettingsData.runningAppsCurrentWorkspace){
                    return CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, parentScreen.name)
            }
            return CompositorService.sortedToplevels
    }
    readonly property int windowCount: sortedToplevels.length
    readonly property int calculatedWidth: {
        if (windowCount === 0)
            return 0
        if (SettingsData.runningAppsCompactMode) {
            return windowCount * 24 + (windowCount - 1) * Theme.spacingXS + horizontalPadding * 2
        } else {
            return windowCount * (24 + Theme.spacingXS + 120)
                    + (windowCount - 1) * Theme.spacingXS + horizontalPadding * 2
        }
    }

    width: calculatedWidth
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    visible: windowCount > 0
    clip: false
    color: {
        if (windowCount === 0)
            return "transparent"
        
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onWheel: {
            var windows = root.sortedToplevels;
            if (windows.length < 2) {
                return;
            }

            var currentIndex = -1;
            for (var i = 0; i < windows.length; i++) {
                if (windows[i].activated) {
                    currentIndex = i;
                    break;
                }
            }

            var nextIndex;
            if (wheel.angleDelta.y < 0) {
                if (currentIndex === -1) {
                    nextIndex = 0;
                } else {
                    nextIndex = (currentIndex + 1) % windows.length;
                }
            } else {
                if (currentIndex === -1) {
                    nextIndex = windows.length - 1;
                } else {
                    nextIndex = (currentIndex - 1 + windows.length) % windows.length;
                }
            }

            var nextWindow = windows[nextIndex];
            if (nextWindow) {
                nextWindow.activate();
            }
        }
    }

    Row {
        id: windowRow

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        Repeater {
            id: windowRepeater

            model: sortedToplevels

            delegate: Item {
                id: delegateItem

                property bool isFocused: modelData.activated
                property string appId: modelData.appId || ""
                property string windowTitle: modelData.title || "(Unnamed)"
                property var toplevelObject: modelData
                property string tooltipText: {
                    var appName = "Unknown"
                    if (appId) {
                        var desktopEntry = DesktopEntries.heuristicLookup(appId)
                        appName = desktopEntry
                                && desktopEntry.name ? desktopEntry.name : appId
                    }
                    return appName + (windowTitle ? " • " + windowTitle : "")
                }

                width: SettingsData.runningAppsCompactMode ? 24 : (24 + Theme.spacingXS + 120)
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: {
                        if (isFocused)
                            return mouseArea.containsMouse ? Qt.rgba(
                                                                 Theme.primary.r,
                                                                 Theme.primary.g,
                                                                 Theme.primary.b,
                                                                 0.3) : Qt.rgba(
                                                                 Theme.primary.r,
                                                                 Theme.primary.g,
                                                                 Theme.primary.b,
                                                                 0.2)
                        else
                            return mouseArea.containsMouse ? Qt.rgba(
                                                                 Theme.primaryHover.r,
                                                                 Theme.primaryHover.g,
                                                                 Theme.primaryHover.b,
                                                                 0.1) : "transparent"
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                // App icon
                IconImage {
                    id: iconImg
                    anchors.left: parent.left
                    anchors.leftMargin: SettingsData.runningAppsCompactMode ? (parent.width - 18) / 2 : Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    source: Quickshell.iconPath(DesktopEntries.heuristicLookup(Paths.moddedAppId(appId))?.icon, true)
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    visible: status === Image.Ready
                }

                // Fallback text if no icon found
                Text {
                    anchors.centerIn: parent
                    visible: !iconImg.visible
                    text: {
                        if (!appId)
                            return "?"

                        var desktopEntry = DesktopEntries.heuristicLookup(appId)
                        if (desktopEntry && desktopEntry.name)
                            return desktopEntry.name.charAt(0).toUpperCase()

                        return appId.charAt(0).toUpperCase()
                    }
                    font.pixelSize: 10
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                }

                // Window title text (only visible in expanded mode)
                StyledText {
                    anchors.left: iconImg.right
                    anchors.leftMargin: Theme.spacingXS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !SettingsData.runningAppsCompactMode
                    text: windowTitle
                    font.pixelSize: Theme.fontSizeMedium - 1
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (toplevelObject) {
                            toplevelObject.activate()
                        }
                    }
                    onEntered: {
                        root.hoveredItem = delegateItem
                        var globalPos = delegateItem.mapToGlobal(
                                    delegateItem.width / 2, delegateItem.height)
                        tooltipLoader.active = true
                        if (tooltipLoader.item) {
                            var tooltipY = Theme.barHeight
                                    + SettingsData.topBarSpacing + Theme.spacingXS
                            tooltipLoader.item.showTooltip(
                                        delegateItem.tooltipText, globalPos.x,
                                        tooltipY, root.parentScreen)
                        }
                    }
                    onExited: {
                        if (root.hoveredItem === delegateItem) {
                            root.hoveredItem = null
                            if (tooltipLoader.item)
                                tooltipLoader.item.hideTooltip()

                            tooltipLoader.active = false
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: tooltipLoader

        active: false

        sourceComponent: RunningAppsTooltip {}
    }
}
