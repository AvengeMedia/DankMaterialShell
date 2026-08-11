pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property string description: I18n.tr("Uses sunrise/sunset times based on your location.")

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
        width: parent.width - Theme.spacingM * 2
        x: Theme.spacingM
        spacing: Theme.spacingM
        visible: !SessionData.nightModeUseIPLocation

        StyledText {
            text: I18n.tr("Manual Coordinates")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            font.weight: Font.Medium
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM

            Column {
                width: (parent.width - Theme.spacingM) / 2
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Latitude")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: latitudeField
                    width: parent.width
                    height: 48
                    text: ""
                    placeholderText: "40.7128"
                    backgroundColor: Theme.surfaceVariant
                    normalBorderColor: Theme.primarySelected
                    focusedBorderColor: Theme.primary
                    keyNavigationTab: longitudeField

                    Component.onCompleted: {
                        text = SessionData.latitude.toString();
                    }

                    Connections {
                        target: SessionData
                        function onLatitudeChanged() {
                            latitudeField.text = SessionData.latitude.toString();
                        }
                    }

                    onEditingFinished: {
                        const lat = parseFloat(text);
                        if (!isNaN(lat) && lat >= -90 && lat <= 90 && lat !== SessionData.latitude) {
                            SessionData.setLatitude(lat);
                            SessionData.setNightModeLocationName("");
                        }
                    }
                }
            }

            Column {
                width: (parent.width - Theme.spacingM) / 2
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Longitude")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: longitudeField
                    width: parent.width
                    height: 48
                    text: ""
                    placeholderText: "-74.0060"
                    backgroundColor: Theme.surfaceVariant
                    normalBorderColor: Theme.primarySelected
                    focusedBorderColor: Theme.primary
                    keyNavigationBacktab: latitudeField

                    Component.onCompleted: {
                        text = SessionData.longitude.toString();
                    }

                    Connections {
                        target: SessionData
                        function onLongitudeChanged() {
                            longitudeField.text = SessionData.longitude.toString();
                        }
                    }

                    onEditingFinished: {
                        const lon = parseFloat(text);
                        if (!isNaN(lon) && lon >= -180 && lon <= 180 && lon !== SessionData.longitude) {
                            SessionData.setLongitude(lon);
                            SessionData.setNightModeLocationName("");
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
            currentLocation: SessionData.nightModeLocationName
            onLocationSelected: (displayName, coordinates) => {
                SessionData.setNightModeLocationName(displayName);
                const coords = coordinates.split(',');
                if (coords.length >= 2) {
                    const lat = parseFloat(coords[0]);
                    const lon = parseFloat(coords[1]);
                    if (!isNaN(lat) && lat >= -90 && lat <= 90) {
                        SessionData.setLatitude(lat);
                        latitudeField.text = coords[0].trim();
                    }
                    if (!isNaN(lon) && lon >= -180 && lon <= 180) {
                        SessionData.setLongitude(lon);
                        longitudeField.text = coords[1].trim();
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
        }
    }
}
