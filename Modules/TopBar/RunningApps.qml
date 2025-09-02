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
        
        property real scrollAccumulator: 0
        property real touchpadThreshold: 500
        
        onWheel: (wheel) => {
            const deltaY = wheel.angleDelta.y
            const isMouseWheel = Math.abs(deltaY) >= 120
                && (Math.abs(deltaY) % 120) === 0
            
            var windows = root.sortedToplevels;
            if (windows.length < 2) {
                return;
            }
            
            if (isMouseWheel) {
                // Direct mouse wheel action
                var currentIndex = -1;
                for (var i = 0; i < windows.length; i++) {
                    if (windows[i].activated) {
                        currentIndex = i;
                        break;
                    }
                }

                var nextIndex;
                if (deltaY < 0) {
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
            } else {
                // Touchpad - accumulate small deltas
                scrollAccumulator += deltaY
                
                if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                    var currentIndex = -1;
                    for (var i = 0; i < windows.length; i++) {
                        if (windows[i].activated) {
                            currentIndex = i;
                            break;
                        }
                    }

                    var nextIndex;
                    if (scrollAccumulator < 0) {
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
                    
                    scrollAccumulator = 0
                }
            }
            
            wheel.accepted = true
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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            if (toplevelObject) {
                                toplevelObject.activate()
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (tooltipLoader.item)
                                tooltipLoader.item.hideTooltip()
                            tooltipLoader.active = false
                            
                            windowContextMenuLoader.active = true
                            if (windowContextMenuLoader.item) {
                                windowContextMenuLoader.item.currentWindow = toplevelObject
                                var globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, 0)
                                var screenX = root.parentScreen ? root.parentScreen.x : 0
                                var screenY = root.parentScreen ? root.parentScreen.y : 0
                                var relativeX = globalPos.x - screenX
                                var yPos = Theme.barHeight + SettingsData.topBarSpacing - 7
                                windowContextMenuLoader.item.showAt(relativeX, yPos)
                            }
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
    
    Loader {
        id: windowContextMenuLoader
        active: false
        sourceComponent: PanelWindow {
            id: contextMenuWindow
            
            property var currentWindow: null
            property bool isVisible: false
            property point anchorPos: Qt.point(0, 0)
            
            function showAt(x, y) {
                screen = root.parentScreen
                anchorPos = Qt.point(x, y)
                isVisible = true
                visible = true
            }
            
            function close() {
                isVisible = false
                visible = false
                windowContextMenuLoader.active = false
            }
            
            implicitWidth: 100
            implicitHeight: 40
            visible: false
            color: "transparent"
            
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: contextMenuWindow.close()
            }
            
            Rectangle {
                x: {
                    var left = 10
                    var right = contextMenuWindow.width - width - 10
                    var want = contextMenuWindow.anchorPos.x - width / 2
                    return Math.max(left, Math.min(right, want))
                }
                y: contextMenuWindow.anchorPos.y
                width: 100
                height: 32
                color: Theme.popupBackground()
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: closeMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                }
                
                StyledText {
                    anchors.centerIn: parent
                    text: "Close"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                }
                
                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenuWindow.currentWindow) {
                            contextMenuWindow.currentWindow.close()
                        }
                        contextMenuWindow.close()
                    }
                }
            }
        }
    }
}
