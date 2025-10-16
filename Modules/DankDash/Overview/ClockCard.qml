import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Card {
    id: root

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Column {
            spacing: -8
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    text: {
                        if (SettingsData.use24HourClock) {
                            return String(systemClock?.date?.getHours()).padStart(2, '0').charAt(0)
                        } else {
                            const hours = systemClock?.date?.getHours()
                            const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
                            return String(display).padStart(2, '0').charAt(0)
                        }
                    }
                    font.pixelSize: 48
                    color: Theme.primary
                    font.weight: Font.Medium
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                }
                
                StyledText {
                    text: {
                        if (SettingsData.use24HourClock) {
                            return String(systemClock?.date?.getHours()).padStart(2, '0').charAt(1)
                        } else {
                            const hours = systemClock?.date?.getHours()
                            const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
                            return String(display).padStart(2, '0').charAt(1)
                        }
                    }
                    font.pixelSize: 48
                    color: Theme.primary
                    font.weight: Font.Medium
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            
            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    text: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(0)
                    font.pixelSize: 48
                    color: Theme.primary
                    font.weight: Font.Medium
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                }
                
                StyledText {
                    text: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(1)
                    font.pixelSize: 48
                    color: Theme.primary
                    font.weight: Font.Medium
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Row {
                visible: SettingsData.showSeconds
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    text: String(systemClock?.date?.getSeconds()).padStart(2, '0').charAt(0)
                    font.pixelSize: 48
                    color: Theme.primary
                    font.weight: Font.Medium
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: String(systemClock?.date?.getSeconds()).padStart(2, '0').charAt(1)
                    font.pixelSize: 48
                    color: Theme.primary
                    font.weight: Font.Medium
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                }
            }

        }
        
        StyledText {
            text: systemClock?.date?.toLocaleDateString(Qt.locale(), "MMM dd")
            font.pixelSize: Theme.fontSizeSmall
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }
}