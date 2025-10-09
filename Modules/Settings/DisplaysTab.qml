import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: displaysTab

    property var variantComponents: [{
        "id": "dankBar",
        "name": "Dank Bar",
        "description": "System bar with widgets and system information",
        "icon": "toolbar"
    }, {
        "id": "dock",
        "name": "Application Dock",
        "description": "Bottom dock for pinned and running applications",
        "icon": "dock"
    }, {
        "id": "notifications",
        "name": "Notification Popups",
        "description": "Notification toast popups",
        "icon": "notifications"
    }, {
        "id": "wallpaper",
        "name": "Wallpaper",
        "description": "Desktop background images",
        "icon": "wallpaper"
    }, {
        "id": "osd",
        "name": "On-Screen Displays",
        "description": "Volume, brightness, and other system OSDs",
        "icon": "picture_in_picture"
    }, {
        "id": "toast",
        "name": "Toast Messages",
        "description": "System toast notifications",
        "icon": "campaign"
    }, {
        "id": "notepad",
        "name": "Notepad Slideout",
        "description": "Quick note-taking slideout panel",
        "icon": "sticky_note_2"
    }, {
        "id": "systemTray",
        "name": "System Tray",
        "description": "System tray icons",
        "icon": "notifications"
    }]

    function getScreenPreferences(componentId) {
        return SettingsData.screenPreferences && SettingsData.screenPreferences[componentId] || ["all"];
    }

    function setScreenPreferences(componentId, screenNames) {
        var prefs = SettingsData.screenPreferences || {
        };
        prefs[componentId] = screenNames;
        SettingsData.setScreenPreferences(prefs);
    }

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        anchors.bottomMargin: Theme.spacingS
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: screensInfoSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: screensInfoSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "monitor"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Connected Displays")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Configure which displays show shell components")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                        }

                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Available Screens (") + Quickshell.screens.length + ")"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Repeater {
                            model: Quickshell.screens

                            delegate: Rectangle {
                                width: parent.width
                                height: screenRow.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                border.width: 0

                                Row {
                                    id: screenRow

                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: "desktop_windows"
                                        size: Theme.iconSize - 4
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - Theme.iconSize - Theme.spacingM * 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingXS / 2

                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        Row {
                                            spacing: Theme.spacingS

                                            StyledText {
                                                text: modelData.width + "×" + modelData.height
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: modelData.model || "Unknown Model"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

            Column {
                width: parent.width
                spacing: Theme.spacingL

                Repeater {
                    model: displaysTab.variantComponents

                    delegate: StyledRect {
                        width: parent.width
                        height: componentSection.implicitHeight + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        border.width: 0

                        Column {
                            id: componentSection

                            anchors.fill: parent
                            anchors.margins: Theme.spacingL
                            spacing: Theme.spacingM

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: modelData.icon
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - Theme.iconSize - Theme.spacingM
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: modelData.description
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }

                                }

                            }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: I18n.tr("Show on screens:")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }

                                Column {
                                    property string componentId: modelData.id
                                    property var selectedScreens: displaysTab.getScreenPreferences(componentId)

                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    DankToggle {
                                        width: parent.width
                                        text: I18n.tr("All displays")
                                        description: I18n.tr("Show on all connected displays")
                                        checked: parent.selectedScreens.includes("all")
                                        onToggled: (checked) => {
                                            if (checked)
                                                displaysTab.setScreenPreferences(parent.componentId, ["all"]);
                                            else
                                                displaysTab.setScreenPreferences(parent.componentId, []);
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Theme.outline
                                        opacity: 0.2
                                        visible: !parent.selectedScreens.includes("all")
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        visible: !parent.selectedScreens.includes("all")

                                        Repeater {
                                            model: Quickshell.screens

                                            delegate: DankToggle {
                                                property string screenName: modelData.name
                                                property string componentId: parent.parent.componentId

                                                width: parent.width
                                                text: screenName
                                                description: modelData.width + "×" + modelData.height + " • " + (modelData.model || "Unknown Model")
                                                checked: {
                                                    var prefs = displaysTab.getScreenPreferences(componentId);
                                                    return !prefs.includes("all") && prefs.includes(screenName);
                                                }
                                                onToggled: (checked) => {
                                                    var currentPrefs = displaysTab.getScreenPreferences(componentId);
                                                    if (currentPrefs.includes("all"))
                                                        currentPrefs = [];

                                                    var newPrefs = currentPrefs.slice();
                                                    if (checked) {
                                                        if (!newPrefs.includes(screenName))
                                                            newPrefs.push(screenName);

                                                    } else {
                                                        var index = newPrefs.indexOf(screenName);
                                                        if (index > -1)
                                                            newPrefs.splice(index, 1);

                                                    }
                                                    displaysTab.setScreenPreferences(componentId, newPrefs);
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

    }

}
