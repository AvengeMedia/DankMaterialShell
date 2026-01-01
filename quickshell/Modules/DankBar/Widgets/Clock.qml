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
                            if (SettingsData.use24HourClock) {
                                return String(systemClock?.date?.getHours()).padStart(2, '0').charAt(0);
                            } else {
                                const hours = systemClock?.date?.getHours();
                                const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                                return String(display).padStart(2, '0').charAt(0);
                            }
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
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
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }

                    StyledText {
                        text: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(1)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }

                    StyledText {
                        text: String(systemClock?.date?.getSeconds()).padStart(2, '0').charAt(1)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
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

                StyledText {
                    id: timeText
                    text: {
                        return systemClock?.date?.toLocaleTimeString(Qt.locale(), SettingsData.getEffectiveTimeFormat());
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.baseline: dateText.baseline
                }

                StyledText {
                    id: middleDot
                    text: "•"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.outlineButton
                    anchors.baseline: dateText.baseline
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
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
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

    MouseArea {
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            root.clockClicked();
        }
    }
}
