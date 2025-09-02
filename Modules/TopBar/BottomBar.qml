import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules
import qs.Modules.TopBar
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property var modelData
    property string screenName: modelData.name
    property real backgroundTransparency: SettingsData.topBarTransparency
    property bool autoHide: SettingsData.topBarAutoHide
    property bool reveal: SettingsData.topBarVisible && (!autoHide || topBarMouseArea.containsMouse)
    readonly property real effectiveBarHeight: Math.max(root.widgetHeight + SettingsData.topBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.topBarInnerPadding))
    readonly property real widgetHeight: Math.max(20, 26 + SettingsData.topBarInnerPadding * 0.6)

    screen: modelData
    implicitHeight: effectiveBarHeight + SettingsData.topBarSpacing
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: !SettingsData.topBarVisible || autoHide ? -1 : root.effectiveBarHeight + SettingsData.topBarSpacing - 2 + SettingsData.topBarBottomGap

    mask: Region { item: topBarMouseArea }

    MouseArea {
        id: topBarMouseArea
        height: root.reveal ? effectiveBarHeight + SettingsData.topBarSpacing : 4
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        hoverEnabled: true

        Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Item {
            id: topBarContainer
            anchors.fill: parent
	    anchors.leftMargin: Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.4)
                    anchors.rightMargin: Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.4)
                    anchors.topMargin: 0
                    anchors.bottomMargin: SettingsData.topBarInnerPadding / 2
                    clip: true

            transform: Translate {
                id: topBarSlide
                y: root.reveal ? 0 : -(effectiveBarHeight - 4)
                Behavior on y {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }
            Item {
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    radius: SettingsData.topBarSquareCorners ? 0 : Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, root.backgroundTransparency)
                    layer.enabled: true

                    Rectangle { anchors.fill: parent; color: "transparent"; border.color: Theme.outlineMedium; border.width: 1; radius: parent.radius }
                    Rectangle { anchors.fill: parent; color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 0.04); radius: parent.radius }
                    layer.effect: MultiEffect { shadowEnabled: true; shadowHorizontalOffset: 0; shadowVerticalOffset: 4; shadowBlur: 0.5; shadowColor: Qt.rgba(0, 0, 0, 0.15); shadowOpacity: 0.15 }
                }

                Row {
                    id: leftSection
		    anchors.fill: parent
                    anchors.leftMargin: Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8)
                    anchors.rightMargin: Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8)
                    anchors.topMargin: SettingsData.topBarInnerPadding / 2
                    anchors.bottomMargin: SettingsData.topBarInnerPadding / 2
                    clip: true

                    spacing: SettingsData.topBarNoBackground ? 2 : Theme.spacingXS
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                    Loader { sourceComponent: workspaceSwitcherComponent; asynchronous: false; anchors.verticalCenter: parent.verticalCenter }
                }

                Item {
                    id: rightSection
                    height: parent.height
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // оставляем пустым
                }
            }
        }
    }

    Component { 
        id: workspaceSwitcherComponent
        AdvancedWorkspaceSwitcher { 
            screenName: root.screenName
            widgetHeight: root.widgetHeight
        } 
    }
}
