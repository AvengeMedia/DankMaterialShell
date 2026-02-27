import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string currentIcon: ""
    property string iconType: "icon"

    signal iconSelected(string iconName, string iconType)

    width: 240
    height: 32
    radius: Theme.cornerRadius
    color: Theme.surfaceContainer
    border.color: iconPopup.visible ? Theme.primary : Theme.outline
    border.width: 1

    property var iconCategories: [
        {
            "name": I18n.tr("Numbers"),
            "icons": ["looks_one", "looks_two", "looks_3", "looks_4", "looks_5", "looks_6", "filter_1", "filter_2", "filter_3", "filter_4", "filter_5", "filter_6", "filter_7", "filter_8", "filter_9", "filter_9_plus", "plus_one", "exposure_plus_1", "exposure_plus_2"]
        },
        {
            "name": I18n.tr("Workspace"),
            "icons": ["work", "laptop", "desktop_windows", "folder", "view_module", "dashboard", "apps", "grid_view"]
        },
        {
            "name": I18n.tr("Development"),
            "icons": ["code", "terminal", "bug_report", "build", "engineering", "integration_instructions", "data_object", "schema", "api", "webhook"]
        },
        {
            "name": I18n.tr("Communication"),
            "icons": ["chat", "mail", "forum", "message", "video_call", "call", "contacts", "group", "notifications", "campaign"]
        },
        {
            "name": I18n.tr("Media"),
            "icons": ["music_note", "headphones", "mic", "videocam", "photo", "movie", "library_music", "album", "radio", "volume_up"]
        },
        {
            "name": I18n.tr("System"),
            "icons": ["memory", "storage", "developer_board", "monitor", "keyboard", "mouse", "battery_std", "wifi", "bluetooth", "security", "settings"]
        },
        {
            "name": I18n.tr("Navigation"),
            "icons": ["home", "arrow_forward", "arrow_back", "expand_more", "expand_less", "menu", "close", "search", "filter_list", "sort"]
        },
        {
            "name": I18n.tr("Actions"),
            "icons": ["add", "remove", "edit", "delete", "save", "download", "upload", "share", "content_copy", "content_paste", "content_cut", "undo", "redo"]
        },
        {
            "name": I18n.tr("Status"),
            "icons": ["check", "error", "warning", "info", "done", "pending", "schedule", "update", "sync", "offline_bolt"]
        },
        {
            "name": I18n.tr("Fun"),
            "icons": ["celebration", "cake", "star", "favorite", "pets", "sports_esports", "local_fire_department", "bolt", "auto_awesome", "diamond"]
        }
    ]

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (iconPopup.visible) {
                iconPopup.close();
                return;
            }
            const pos = root.mapToItem(Overlay.overlay, 0, 0);
            const popupHeight = 500;
            const overlayHeight = Overlay.overlay?.height ?? 800;
            iconPopup.x = pos.x;
            if (pos.y + root.height + popupHeight + 4 > overlayHeight) {
                iconPopup.y = pos.y - popupHeight - 4;
            } else {
                iconPopup.y = pos.y + root.height + 4;
            }
            iconPopup.open();
        }
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingS
        spacing: Theme.spacingS

        DankIcon {
            name: (root.iconType === "icon" && root.currentIcon) ? root.currentIcon : (root.iconType === "text" ? "text_fields" : "add")
            size: 16
            color: root.currentIcon ? Theme.surfaceText : Theme.outline
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.currentIcon ? root.currentIcon : I18n.tr("Choose icon")
            font.pixelSize: Theme.fontSizeSmall
            color: root.currentIcon ? Theme.surfaceText : Theme.outline
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            elide: Text.ElideRight
        }
    }

    DankIcon {
        name: iconPopup.visible ? "expand_less" : "expand_more"
        size: 16
        color: Theme.outline
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
    }

    Popup {
        id: iconPopup

        parent: Overlay.overlay
        width: 320
        height: Math.min(500, dropdownContent.implicitHeight + 32)
        padding: 0
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            color: Theme.surface
            radius: Theme.cornerRadius

            layer.enabled: Theme.elevationEnabled
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: Theme.elevationEnabled
                blurMax: Theme.elevationBlurMax
                shadowColor: Theme.elevationShadowColor(Theme.elevationLevel2)
                shadowBlur: Theme.elevationEnabled ? Math.max(0, Math.min(1, (Theme.elevationLevel2 && Theme.elevationLevel2.blurPx !== undefined ? Theme.elevationLevel2.blurPx : 8) / Theme.elevationBlurMax)) : 0
                shadowHorizontalOffset: 0
                shadowVerticalOffset: Theme.elevationLevel2 && Theme.elevationLevel2.offsetY !== undefined ? Theme.elevationLevel2.offsetY : 4
                shadowOpacity: Theme.elevationLevel2 && Theme.elevationLevel2.alpha !== undefined ? Theme.elevationLevel2.alpha : 0.25
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: closeMouseArea.containsMouse ? Theme.errorHover : "transparent"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                z: 1

                DankIcon {
                    name: "close"
                    size: 16
                    color: closeMouseArea.containsMouse ? Theme.error : Theme.outline
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: iconPopup.close()
                }
            }

            DankFlickable {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                contentHeight: dropdownContent.height
                clip: true
                pressDelay: 0

                Column {
                    id: dropdownContent
                    width: parent.width
                    spacing: Theme.spacingM

                    Repeater {
                        model: root.iconCategories

                        Column {
                            required property var modelData
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            Flow {
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: modelData.icons

                                    Rectangle {
                                        required property string modelData
                                        width: 36
                                        height: 36
                                        radius: Theme.cornerRadius
                                        color: iconMouseArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)
                                        border.color: root.currentIcon === modelData ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
                                        border.width: 2

                                        DankIcon {
                                            name: parent.modelData
                                            size: 20
                                            color: root.currentIcon === parent.modelData ? Theme.primary : Theme.surfaceText
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: iconMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.iconSelected(parent.modelData, "icon");
                                                iconPopup.close();
                                            }
                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.standardEasing
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function setIcon(iconName, type) {
        root.iconType = type;
        root.iconType = "icon";
        root.currentIcon = iconName;
    }
}
