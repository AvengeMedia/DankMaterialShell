import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: false
    signal clockClicked

    onClicked: clockClicked()

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : clockRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? clockColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            readonly property bool compact: widgetData?.clockCompactMode !== undefined ? widgetData.clockCompactMode : SettingsData.clockCompactMode

            Column {
                id: clockColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 0

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: {
                            const hours = systemClock?.date?.getHours();
                            if (SettingsData.use24HourClock)
                                return String(hours).padStart(2, '0').charAt(0);
                            const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                            return String(display).padStart(2, '0').charAt(0);
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }

                    StyledText {
                        text: {
                            const hours = systemClock?.date?.getHours();
                            if (SettingsData.use24HourClock)
                                return String(hours).padStart(2, '0').charAt(1);
                            const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                            return String(display).padStart(2, '0').charAt(1);
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(0)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }

                    StyledText {
                        text: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(1)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }
                }

                Row {
                    visible: SettingsData.showSeconds
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: String(systemClock?.date?.getSeconds()).padStart(2, '0').charAt(0)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }

                    StyledText {
                        text: String(systemClock?.date?.getSeconds()).padStart(2, '0').charAt(1)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.spacingM
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !compact

                    Rectangle {
                        width: parent.width * 0.6
                        height: 1
                        color: Theme.outlineButton
                        anchors.centerIn: parent
                    }
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !compact

                    StyledText {
                        text: {
                            const locale = Qt.locale();
                            const dateFormatShort = locale.dateFormat(Locale.ShortFormat);
                            const dayFirst = dateFormatShort.indexOf('d') < dateFormatShort.indexOf('M');
                            const value = dayFirst ? String(systemClock?.date?.getDate()).padStart(2, '0') : String(systemClock?.date?.getMonth() + 1).padStart(2, '0');
                            return value.charAt(0);
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.primary
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }

                    StyledText {
                        text: {
                            const locale = Qt.locale();
                            const dateFormatShort = locale.dateFormat(Locale.ShortFormat);
                            const dayFirst = dateFormatShort.indexOf('d') < dateFormatShort.indexOf('M');
                            const value = dayFirst ? String(systemClock?.date?.getDate()).padStart(2, '0') : String(systemClock?.date?.getMonth() + 1).padStart(2, '0');
                            return value.charAt(1);
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.primary
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !compact

                    StyledText {
                        text: {
                            const locale = Qt.locale();
                            const dateFormatShort = locale.dateFormat(Locale.ShortFormat);
                            const dayFirst = dateFormatShort.indexOf('d') < dateFormatShort.indexOf('M');
                            const value = dayFirst ? String(systemClock?.date?.getMonth() + 1).padStart(2, '0') : String(systemClock?.date?.getDate()).padStart(2, '0');
                            return value.charAt(0);
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.primary
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }

                    StyledText {
                        text: {
                            const locale = Qt.locale();
                            const dateFormatShort = locale.dateFormat(Locale.ShortFormat);
                            const dayFirst = dateFormatShort.indexOf('d') < dateFormatShort.indexOf('M');
                            const value = dayFirst ? String(systemClock?.date?.getMonth() + 1).padStart(2, '0') : String(systemClock?.date?.getDate()).padStart(2, '0');
                            return value.charAt(1);
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.primary
                        width: Math.round(font.pixelSize * 0.6)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }
                }
            }

            Row {
                id: clockRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingS

                property real fontSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                property real digitWidth: fontSize * 0.6

                property string hoursStr: {
                    const hours = systemClock?.date?.getHours() ?? 0;
                    if (SettingsData.use24HourClock)
                        return String(hours).padStart(2, '0');
                    const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                    if (SettingsData.padHours12Hour)
                        return String(display).padStart(2, '0');
                    return String(display);
                }
                property string minutesStr: String(systemClock?.date?.getMinutes() ?? 0).padStart(2, '0')
                property string secondsStr: String(systemClock?.date?.getSeconds() ?? 0).padStart(2, '0')
                property string ampmStr: {
                    if (SettingsData.use24HourClock)
                        return "";
                    const hours = systemClock?.date?.getHours() ?? 0;
                    return hours >= 12 ? " PM" : " AM";
                }

                Row {
                    spacing: 0
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        visible: clockRow.hoursStr.length > 1
                        text: clockRow.hoursStr.charAt(0)
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                        width: clockRow.digitWidth
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: clockRow.hoursStr.length > 1 ? clockRow.hoursStr.charAt(1) : clockRow.hoursStr.charAt(0)
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                        width: clockRow.digitWidth
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: ":"
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                    }

                    StyledText {
                        text: clockRow.minutesStr.charAt(0)
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                        width: clockRow.digitWidth
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: clockRow.minutesStr.charAt(1)
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                        width: clockRow.digitWidth
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        visible: SettingsData.showSeconds
                        text: ":"
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                    }

                    StyledText {
                        visible: SettingsData.showSeconds
                        text: clockRow.secondsStr.charAt(0)
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                        width: clockRow.digitWidth
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        visible: SettingsData.showSeconds
                        text: clockRow.secondsStr.charAt(1)
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                        width: clockRow.digitWidth
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        visible: !SettingsData.use24HourClock
                        text: clockRow.ampmStr
                        font.pixelSize: clockRow.fontSize
                        color: Theme.widgetTextColor
                    }
                }

                StyledText {
                    id: middleDot
                    text: "•"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.outlineButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !compact
                }

                StyledText {
                    id: dateText
                    text: {
                        if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0) {
                            return systemClock?.date?.toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat);
                        }
                        return systemClock?.date?.toLocaleDateString(Qt.locale(), "ddd d");
                    }
                    font.pixelSize: clockRow.fontSize
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !compact
                }
            }

            SystemClock {
                id: systemClock
                precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
            }
        }
    }
}
