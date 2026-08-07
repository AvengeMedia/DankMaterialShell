pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property string description: I18n.tr("Uses sunrise/sunset times based on your location.")
    property bool centered: false

    width: parent.width
    spacing: Theme.spacingM

    DankToggle {
        id: ipLocationToggle
        width: parent.width
        text: I18n.tr("Use IP Location")
        description: I18n.tr("Automatically detect location based on IP address")
        checked: SessionData.nightModeUseIPLocation || false
        onToggled: checked => {
            SessionData.setNightModeUseIPLocation(checked);
        }

        Connections {
            target: SessionData
            function onNightModeUseIPLocationChanged() {
                ipLocationToggle.checked = SessionData.nightModeUseIPLocation;
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM
        visible: !SessionData.nightModeUseIPLocation

        StyledText {
            text: I18n.tr("Manual Coordinates")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            width: parent.width
            horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
        }

        Row {
            spacing: Theme.spacingL
            anchors.horizontalCenter: root.centered ? parent.horizontalCenter : undefined

            Column {
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Latitude")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    width: 120
                    height: 40
                    text: SessionData.latitude.toString()
                    placeholderText: "0.0"
                    onEditingFinished: {
                        const lat = parseFloat(text);
                        if (!isNaN(lat) && lat >= -90 && lat <= 90 && lat !== SessionData.latitude) {
                            SessionData.setLatitude(lat);
                        }
                    }
                }
            }

            Column {
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Longitude")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    width: 120
                    height: 40
                    text: SessionData.longitude.toString()
                    placeholderText: "0.0"
                    onEditingFinished: {
                        const lon = parseFloat(text);
                        if (!isNaN(lon) && lon >= -180 && lon <= 180 && lon !== SessionData.longitude) {
                            SessionData.setLongitude(lon);
                        }
                    }
                }
            }
        }

        StyledText {
            text: I18n.tr("Location Search")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            font.weight: Font.Medium
        }

        DankLocationSearch {
            width: parent.width
            onLocationSelected: (displayName, coordinates) => {
                const coords = coordinates.split(',');
                if (coords.length >= 2) {
                    const lat = parseFloat(coords[0]);
                    const lon = parseFloat(coords[1]);
                    if (!isNaN(lat) && lat >= -90 && lat <= 90) {
                        SessionData.setLatitude(lat);
                    }
                    if (!isNaN(lon) && lon >= -180 && lon <= 180) {
                        SessionData.setLongitude(lon);
                    }
                }
            }
        }

        StyledText {
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
        }
    }
}
