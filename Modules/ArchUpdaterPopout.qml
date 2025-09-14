import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: archUpdaterPopout

    property var parentWidget: null
    property string triggerSection: "right"
    property var triggerScreen: null

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x;
        triggerY = y;
        triggerWidth = width;
        triggerSection = section;
        triggerScreen = screen;
    }

    popupWidth: 400
    popupHeight: 500
    triggerX: Screen.width - 600 - Theme.spacingL
    triggerY: Theme.barHeight - 4 + SettingsData.topBarSpacing + Theme.spacingXS
    triggerWidth: 55
    positioning: "center"
    screen: triggerScreen
    visible: shouldBeVisible
    shouldBeVisible: false

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            if (ArchUpdaterService.updateCount === 0 && !ArchUpdaterService.isChecking) {
                ArchUpdaterService.checkForUpdates()
            }
        }
    }

    content: Component {
        Rectangle {
            id: updaterPanel

            color: Theme.popupBackground()
            radius: Theme.cornerRadius
            antialiasing: true
            smooth: true

            Repeater {
                model: [{
                        "margin": -3,
                        "color": Qt.rgba(0, 0, 0, 0.05),
                        "z": -3
                    }, {
                        "margin": -2,
                        "color": Qt.rgba(0, 0, 0, 0.08),
                        "z": -2
                    }, {
                        "margin": 0,
                        "color": Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12),
                        "z": -1
                    }]
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: modelData.margin
                    color: "transparent"
                    radius: parent.radius + Math.abs(modelData.margin)
                    border.color: modelData.color
                    border.width: 1
                    z: modelData.z
                }
            }

            Column {
                width: parent.width - Theme.spacingL * 2
                height: parent.height - Theme.spacingL * 2
                x: Theme.spacingL
                y: Theme.spacingL
                spacing: Theme.spacingL

                Item {
                    width: parent.width
                    height: 40

                    StyledText {
                        text: "System Updates"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (ArchUpdaterService.isChecking) return "Checking...";
                                if (ArchUpdaterService.hasError) return "Error";
                                if (ArchUpdaterService.updateCount === 0) return "Up to date";
                                return ArchUpdaterService.updateCount + " updates";
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            color: {
                                if (ArchUpdaterService.hasError) return Theme.error;
                                return Theme.surfaceText;
                            }
                        }

                        DankActionButton {
                            id: checkForUpdatesButton
                            buttonSize: 28
                            iconName: "refresh"
                            iconSize: 18
                            z: 15
                            iconColor: Theme.surfaceText
                            enabled: !ArchUpdaterService.isChecking
                            opacity: enabled ? 1.0 : 0.5
                            onClicked: {
                                ArchUpdaterService.checkForUpdates()
                            }

                            RotationAnimation {
                                target: checkForUpdatesButton
                                property: "rotation"
                                from: 0
                                to: 360
                                duration: 1000
                                running: ArchUpdaterService.isChecking
                                loops: Animation.Infinite

                                onRunningChanged: {
                                    if (!running) {
                                        checkForUpdatesButton.rotation = 0
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: {
                        let usedHeight = 40 + Theme.spacingL
                        usedHeight += 48 + Theme.spacingL
                        return parent.height - usedHeight
                    }
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        anchors.rightMargin: 0

                        StyledText {
                            id: statusText
                            width: parent.width
                            text: {
                                if (ArchUpdaterService.hasError) {
                                    return "Failed to check for updates:\n" + ArchUpdaterService.errorMessage;
                                }
                                if (!ArchUpdaterService.helperAvailable) {
                                    return "No AUR helper found. Please install 'paru' or 'yay' to check for updates.";
                                }
                                if (ArchUpdaterService.isChecking) {
                                    return "Checking for updates...";
                                }
                                if (ArchUpdaterService.updateCount === 0) {
                                    return "Your system is up to date!";
                                }
                                return `Found ${ArchUpdaterService.updateCount} packages to update:`;
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            color: {
                                if (ArchUpdaterService.hasError) return Theme.errorText;
                                return Theme.surfaceText;
                            }
                            wrapMode: Text.WordWrap
                            visible: ArchUpdaterService.updateCount === 0 || ArchUpdaterService.hasError || ArchUpdaterService.isChecking
                        }

                        DankListView {
                            id: packagesList

                            width: parent.width
                            height: parent.height - (ArchUpdaterService.updateCount === 0 || ArchUpdaterService.hasError || ArchUpdaterService.isChecking ? statusText.height + Theme.spacingM : 0)
                            visible: ArchUpdaterService.updateCount > 0 && !ArchUpdaterService.isChecking && !ArchUpdaterService.hasError
                            clip: true
                            spacing: Theme.spacingXS

                            model: ArchUpdaterService.availableUpdates

                            delegate: Rectangle {
                                width: ListView.view.width - Theme.spacingM
                                height: 48
                                radius: Theme.cornerRadius
                                color: packageMouseArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                                border.color: Theme.outlineLight
                                border.width: 1

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 24 - Theme.spacingM
                                        spacing: 2

                                        StyledText {
                                            width: parent.width
                                            text: modelData.name || ""
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: `${modelData.currentVersion} → ${modelData.newVersion}`
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: Theme.shortDuration }
                                }

                                MouseArea {
                                    id: packageMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 48
                    spacing: Theme.spacingM
                    
                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: parent.height
                        radius: Theme.cornerRadius
                        color: updateMouseArea.containsMouse ? Theme.primaryHover : Theme.secondaryHover
                        opacity: ArchUpdaterService.updateCount > 0 ? 1.0 : 0.5
                        
                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "system_update_alt"
                                size: Theme.iconSize
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Update All"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: updateMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: ArchUpdaterService.updateCount > 0
                            onClicked: {
                                ArchUpdaterService.runUpdates()
                                archUpdaterPopout.close()
                            }
                        }
                    }
                    

                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: parent.height
                        radius: Theme.cornerRadius
                        color: closeMouseArea.containsMouse ? Theme.errorPressed : Theme.secondaryHover
                            
                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "close"
                                size: Theme.iconSize
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Close"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                archUpdaterPopout.close()
                            }
                        }
                    }
                }
            }

        }
    }
}