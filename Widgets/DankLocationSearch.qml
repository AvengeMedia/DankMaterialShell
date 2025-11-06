import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: root

    activeFocusOnTab: true

    KeyNavigation.tab: keyNavigationTab
    KeyNavigation.backtab: keyNavigationBacktab

    onActiveFocusChanged: {
        if (activeFocus) {
            locationInput.forceActiveFocus()
        }
    }

    property string currentLocation: ""
    property string placeholderText: I18n.tr("Search for a location...")
    property bool _internalChange: false
    property bool isLoading: false
    property string currentSearchText: ""
    property Item keyNavigationTab: null
    property Item keyNavigationBacktab: null

    signal locationSelected(string displayName, string coordinates)

    function resetSearchState() {
        locationSearchTimer.stop()
        dropdownHideTimer.stop()
        isLoading = false
        searchResultsModel.clear()
    }

    width: parent.width
    height: searchInputField.height + (searchDropdown.visible ? searchDropdown.height : 0)

    ListModel {
        id: searchResultsModel
    }

    Timer {
        id: locationSearchTimer

        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (locationInput.text.length > 2) {
                searchResultsModel.clear()
                root.isLoading = true
                const searchLocation = locationInput.text
                root.currentSearchText = searchLocation
                const encodedLocation = encodeURIComponent(searchLocation)
                const curlCommand = `curl -4 -s --connect-timeout 5 --max-time 10 'https://nominatim.openstreetmap.org/search?q=${encodedLocation}&format=json&limit=5&addressdetails=1'`
                Proc.runCommand("locationSearch", ["bash", "-c", curlCommand], (output, exitCode) => {
                    root.isLoading = false
                    if (exitCode !== 0) {
                        searchResultsModel.clear()
                        return
                    }
                    if (root.currentSearchText !== locationInput.text)
                        return

                    const raw = output.trim()
                    searchResultsModel.clear()
                    if (!raw || raw[0] !== "[") {
                        return
                    }
                    try {
                        const data = JSON.parse(raw)
                        if (data.length === 0) {
                            return
                        }
                        for (var i = 0; i < Math.min(data.length, 5); i++) {
                            const location = data[i]
                            if (location.display_name && location.lat && location.lon) {
                                const parts = location.display_name.split(', ')
                                let cleanName = parts[0]
                                if (parts.length > 1) {
                                    const state = parts[parts.length - 2]
                                    if (state && state !== cleanName)
                                        cleanName += `, ${state}`
                                }
                                const query = `${location.lat},${location.lon}`
                                searchResultsModel.append({
                                                              "name": cleanName,
                                                              "query": query
                                                          })
                            }
                        }
                    } catch (e) {

                    }
                })
            }
        }
    }

    Timer {
        id: dropdownHideTimer

        interval: 200
        running: false
        repeat: false
        onTriggered: {
            if (!locationInput.getActiveFocus() && !searchDropdown.hovered)
                root.resetSearchState()
        }
    }

    Item {
        id: searchInputField

        width: parent.width
        height: 48

        DankTextField {
            id: locationInput

            width: parent.width
            height: parent.height
            leftIconName: "search"
            placeholderText: root.placeholderText
            text: ""
            backgroundColor: Theme.surfaceVariant
            normalBorderColor: Theme.primarySelected
            focusedBorderColor: Theme.primary
            keyNavigationTab: root.keyNavigationTab
            keyNavigationBacktab: root.keyNavigationBacktab
            onTextEdited: {
                if (root._internalChange)
                    return
                if (getActiveFocus()) {
                    if (text.length > 2) {
                        root.isLoading = true
                        locationSearchTimer.restart()
                    } else {
                        root.resetSearchState()
                    }
                }
            }
            onFocusStateChanged: hasFocus => {
                                     if (hasFocus) {
                                         dropdownHideTimer.stop()
                                     } else {
                                         dropdownHideTimer.start()
                                     }
                                 }
        }

        DankIcon {
            name: root.isLoading ? "hourglass_empty" : (searchResultsModel.count > 0 ? "check_circle" : "error")
            size: Theme.iconSize - 4
            color: root.isLoading ? Theme.surfaceVariantText : (searchResultsModel.count > 0 ? Theme.primary : Theme.error)
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            opacity: (locationInput.getActiveFocus() && locationInput.text.length > 2) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }

    StyledRect {
        id: searchDropdown

        property bool hovered: false

        width: parent.width
        height: Math.min(Math.max(searchResultsModel.count * 38 + Theme.spacingS * 2, 50), 200)
        y: searchInputField.height
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        border.color: Theme.primarySelected
        border.width: 1
        visible: locationInput.getActiveFocus() && locationInput.text.length > 2 && (searchResultsModel.count > 0 || root.isLoading)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                parent.hovered = true
                dropdownHideTimer.stop()
            }
            onExited: {
                parent.hovered = false
                if (!locationInput.getActiveFocus())
                    dropdownHideTimer.start()
            }
            acceptedButtons: Qt.NoButton
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingS

            DankListView {
                id: searchResultsList

                anchors.fill: parent
                clip: true
                model: searchResultsModel
                spacing: 2

                delegate: StyledRect {
                    width: searchResultsList.width
                    height: 36
                    radius: Theme.cornerRadius
                    color: resultMouseArea.containsMouse ? Theme.surfaceLight : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "place"
                            size: Theme.iconSize - 6
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: model.name || "Unknown"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: parent.width - 30
                        }
                    }

                    MouseArea {
                        id: resultMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._internalChange = true
                            const selectedName = model.name
                            const selectedQuery = model.query
                            locationInput.text = selectedName
                            root.locationSelected(selectedName, selectedQuery)
                            root.resetSearchState()
                            locationInput.setFocus(false)
                            root._internalChange = false
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: root.isLoading ? "Searching..." : "No locations found"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: searchResultsList.count === 0 && locationInput.text.length > 2
            }
        }
    }
}
