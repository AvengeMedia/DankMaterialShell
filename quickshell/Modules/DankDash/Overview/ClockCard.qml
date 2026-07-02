import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Card {
    id: root

    Column {
        anchors.centerIn: parent
        spacing: 0

        Column {
            spacing: -8
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    text: {
                        if (SettingsData.use24HourClock) {
                            return String(systemClock?.date?.getHours()).padStart(2, '0').charAt(0);
                        } else {
                            const hours = systemClock?.date?.getHours();
                            const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                            return String(display).padStart(2, '0').charAt(0);
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
                            return String(systemClock?.date?.getHours()).padStart(2, '0').charAt(1);
                        } else {
                            const hours = systemClock?.date?.getHours();
                            const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                            return String(display).padStart(2, '0').charAt(1);
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
        }

        Row {
            visible: SettingsData.showSeconds
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter

            StyledText {
                text: String(systemClock?.date?.getSeconds()).padStart(2, '0')
                font.pixelSize: 24
                color: Theme.withAlpha(Theme.primary, 0.7)
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Item {
            width: 1
            height: Theme.spacingXS
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: systemClock?.date?.toLocaleDateString(I18n.locale(), "MMM dd")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    SystemClock {
        id: systemClock
        precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService

        function onSessionResumed() {
            systemClock.enabled = false;
            systemClock.enabled = true;
        }
    }
}
