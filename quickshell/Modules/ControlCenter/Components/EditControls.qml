import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

Row {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var availableWidgets: []
    property var popupScreen: null
    property real popoutX: 0
    property real popoutY: 0
    property real popoutWidth: 0
    property real popoutHeight: 0

    signal addWidget(string widgetId)
    signal resetToDefault
    signal clearAll

    height: 48
    spacing: Theme.spacingS

    function openWidgetLibrary() {
        if (popupScreen)
            addWidgetWindow.screen = popupScreen;
        addWidgetWindow.visible = true;
    }

    function closeWidgetLibrary() {
        addWidgetWindow.visible = false;
    }

    onAddWidget: closeWidgetLibrary()
    onVisibleChanged: {
        if (!visible)
            closeWidgetLibrary();
    }

    PanelWindow {
        id: addWidgetWindow

        screen: root.popupScreen
        visible: false
        color: "transparent"

        WlrLayershell.namespace: "dms:control-center-widget-library"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        readonly property bool blurActive: Theme.blurForegroundLayers || Theme.transparentBlurLayers
        readonly property real surfaceAlpha: blurActive ? Math.min(Theme.popupTransparency, Theme.transparentBlurLayers ? 0.24 : 0.72) : Theme.popupTransparency
        readonly property real rowAlpha: blurActive ? Math.min(Theme.popupTransparency, Theme.transparentBlurLayers ? 0.10 : 0.52) : Theme.popupTransparency
        readonly property int panelWidth: 400
        readonly property int panelHeight: 300

        WindowBlur {
            targetWindow: addWidgetWindow
            blurX: widgetLibraryPanel.x
            blurY: widgetLibraryPanel.y
            blurWidth: addWidgetWindow.visible ? widgetLibraryPanel.width : 0
            blurHeight: addWidgetWindow.visible ? widgetLibraryPanel.height : 0
            blurRadius: Theme.cornerRadius
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.closeWidgetLibrary()
        }

        FocusScope {
            anchors.fill: parent
            focus: addWidgetWindow.visible

            Keys.onEscapePressed: event => {
                root.closeWidgetLibrary();
                event.accepted = true;
            }
        }

        Rectangle {
            id: widgetLibraryPanel

            width: addWidgetWindow.panelWidth
            height: addWidgetWindow.panelHeight
            x: Math.round((root.popoutWidth > 0 ? root.popoutX + (root.popoutWidth - width) / 2 : (addWidgetWindow.width - width) / 2))
            y: Math.round((root.popoutHeight > 0 ? root.popoutY + (root.popoutHeight - height) / 2 : (addWidgetWindow.height - height) / 2))
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainer, addWidgetWindow.surfaceAlpha)
            border.color: addWidgetWindow.blurActive ? Theme.outlineMedium : Theme.primarySelected
            border.width: addWidgetWindow.blurActive ? Theme.layerOutlineWidth : 0
            antialiasing: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => mouse.accepted = true
            }

            Item {
                anchors.fill: parent
                anchors.margins: Theme.spacingL

                Row {
                    id: headerRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "add_circle"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Typography {
                        text: I18n.tr("Add Widget")
                        style: Typography.Style.Subtitle
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                DankListView {
                    id: widgetList

                    anchors.top: headerRow.bottom
                    anchors.topMargin: Theme.spacingM
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: Theme.spacingS
                    clip: true
                    model: root.availableWidgets

                    delegate: Rectangle {
                        width: widgetList.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: widgetMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, addWidgetWindow.blurActive ? 0.12 : 0.08) : Theme.withAlpha(Theme.surfaceContainerHigh, addWidgetWindow.rowAlpha)
                        border.color: Theme.outlineMedium
                        border.width: Theme.layerOutlineWidth
                        antialiasing: true

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            DankIcon {
                                name: modelData.icon
                                size: Theme.iconSize
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                width: parent.width - Theme.iconSize * 2 - Theme.spacingM * 3

                                Typography {
                                    text: modelData.text
                                    style: Typography.Style.Body
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    width: parent.width
                                    horizontalAlignment: Text.AlignLeft
                                }

                                Typography {
                                    text: modelData.description
                                    style: Typography.Style.Caption
                                    color: Theme.outline
                                    elide: Text.ElideRight
                                    width: parent.width
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }

                            DankIcon {
                                name: "add"
                                size: Theme.iconSize - 4
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: widgetMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.addWidget(modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 48
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
        border.color: Theme.primary
        border.width: 0

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "add"
                size: Theme.iconSize - 2
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Typography {
                text: I18n.tr("Add Widget")
                style: Typography.Style.Button
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openWidgetLibrary()
        }
    }

    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 48
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
        border.color: Theme.warning
        border.width: 0

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "settings_backup_restore"
                size: Theme.iconSize - 2
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }

            Typography {
                text: I18n.tr("Defaults")
                style: Typography.Style.Button
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.resetToDefault()
        }
    }

    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 48
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
        border.color: Theme.error
        border.width: 0

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "clear_all"
                size: Theme.iconSize - 2
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            Typography {
                text: I18n.tr("Reset")
                style: Typography.Style.Button
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearAll()
        }
    }
}
