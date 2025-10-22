import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property bool compactMode: false
    signal clockClicked

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : clockRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? clockColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: clockColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: -2

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
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        width: 9
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
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(0)
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(1)
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Row {
                    visible: SettingsData.showSeconds
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: String(systemClock?.date?.getSeconds()).padStart(2, '0').charAt(0)
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: String(systemClock?.date?.getSeconds()).padStart(2, '0').charAt(1)
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    width: 12
                    height: Theme.spacingM
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 12
                        height: 1
                        color: Theme.outlineButton
                        anchors.centerIn: parent
                    }
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: {
                            const locale = Qt.locale()
                            const dateFormatShort = locale.dateFormat(Locale.ShortFormat)
                            const dayFirst = dateFormatShort.indexOf('d') < dateFormatShort.indexOf('M')
                            const value = dayFirst ? String(systemClock?.date?.getDate()).padStart(2, '0') : String(systemClock?.date?.getMonth() + 1).padStart(2, '0')
                            return value.charAt(0)
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.primary
                        font.weight: Font.Light
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: {
                            const locale = Qt.locale()
                            const dateFormatShort = locale.dateFormat(Locale.ShortFormat)
                            const dayFirst = dateFormatShort.indexOf('d') < dateFormatShort.indexOf('M')
                            const value = dayFirst ? String(systemClock?.date?.getDate()).padStart(2, '0') : String(systemClock?.date?.getMonth() + 1).padStart(2, '0')
                            return value.charAt(1)
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.primary
                        font.weight: Font.Light
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: {
                            const locale = Qt.locale()
                            const dateFormatShort = locale.dateFormat(Locale.ShortFormat)
                            const dayFirst = dateFormatShort.indexOf('d') < dateFormatShort.indexOf('M')
                            const value = dayFirst ? String(systemClock?.date?.getMonth() + 1).padStart(2, '0') : String(systemClock?.date?.getDate()).padStart(2, '0')
                            return value.charAt(0)
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.primary
                        font.weight: Font.Light
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: {
                            const locale = Qt.locale()
                            const dateFormatShort = locale.dateFormat(Locale.ShortFormat)
                            const dayFirst = dateFormatShort.indexOf('d') < dateFormatShort.indexOf('M')
                            const value = dayFirst ? String(systemClock?.date?.getMonth() + 1).padStart(2, '0') : String(systemClock?.date?.getDate()).padStart(2, '0')
                            return value.charAt(1)
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        color: Theme.primary
                        font.weight: Font.Light
                        width: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Row {
                id: clockRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingS

                StyledText {
                    text: {
                        return systemClock?.date?.toLocaleTimeString(Qt.locale(), SettingsData.getEffectiveTimeFormat())
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "•"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.outlineButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !SettingsData.clockCompactMode
                }

                StyledText {
                    text: {
                        if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0) {
                            return systemClock?.date?.toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat)
                        }

                        return systemClock?.date?.toLocaleDateString(Qt.locale(), "ddd d")
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !SettingsData.clockCompactMode
                }
            }

            SystemClock {
                id: systemClock
                precision: SystemClock.Seconds
            }
        }
    }

    MouseArea {
        id: clockMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (root.popoutTarget && root.popoutTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = root.parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, width)
                root.popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen)
            }
            root.clockClicked()
        }
    }
}
