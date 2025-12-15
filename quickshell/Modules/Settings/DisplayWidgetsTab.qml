import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    function getBarComponentsFromSettings() {
        const bars = SettingsData.barConfigs || []
        return bars.map(bar => ({
                                    "id": "bar:" + bar.id,
                                    "name": bar.name || "Bar",
                                    "description": I18n.tr("Individual bar configuration"),
                                    "icon": "toolbar",
                                    "barId": bar.id
                                }))
    }

    property var variantComponents: getVariantComponentsList()

    function getVariantComponentsList() {
        return [...getBarComponentsFromSettings(), {
                    "id": "dock",
                    "name": I18n.tr("Application Dock"),
                    "description": I18n.tr("Bottom dock for pinned and running applications"),
                    "icon": "dock"
                }, {
                    "id": "notifications",
                    "name": I18n.tr("Notification Popups"),
                    "description": I18n.tr("Notification toast popups"),
                    "icon": "notifications"
                }, {
                    "id": "wallpaper",
                    "name": I18n.tr("Wallpaper"),
                    "description": I18n.tr("Desktop background images"),
                    "icon": "wallpaper"
                }, {
                    "id": "osd",
                    "name": I18n.tr("On-Screen Displays"),
                    "description": I18n.tr("Volume, brightness, and other system OSDs"),
                    "icon": "picture_in_picture"
                }, {
                    "id": "toast",
                    "name": I18n.tr("Toast Messages"),
                    "description": I18n.tr("System toast notifications"),
                    "icon": "campaign"
                }, {
                    "id": "notepad",
                    "name": I18n.tr("Notepad Slideout"),
                    "description": I18n.tr("Quick note-taking slideout panel"),
                    "icon": "sticky_note_2"
                }]
    }

    Connections {
        target: SettingsData
        function onBarConfigsChanged() {
            variantComponents = getVariantComponentsList()
        }
    }

    function getScreenPreferences(componentId) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4)
            const barConfig = SettingsData.getBarConfig(barId)
            return barConfig?.screenPreferences || ["all"]
        }
        return SettingsData.screenPreferences && SettingsData.screenPreferences[componentId] || ["all"]
    }

    function setScreenPreferences(componentId, screenNames) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4)
            SettingsData.updateBarConfig(barId, {
                                             "screenPreferences": screenNames
                                         })
            return
        }
        var prefs = SettingsData.screenPreferences || {}
        var newPrefs = Object.assign({}, prefs)
        newPrefs[componentId] = screenNames
        SettingsData.set("screenPreferences", newPrefs)
    }

    function getShowOnLastDisplay(componentId) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4)
            const barConfig = SettingsData.getBarConfig(barId)
            return barConfig?.showOnLastDisplay ?? true
        }
        return SettingsData.showOnLastDisplay && SettingsData.showOnLastDisplay[componentId] || false
    }

    function setShowOnLastDisplay(componentId, enabled) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4)
            SettingsData.updateBarConfig(barId, {
                                             "showOnLastDisplay": enabled
                                         })
            return
        }
        var prefs = SettingsData.showOnLastDisplay || {}
        var newPrefs = Object.assign({}, prefs)
        newPrefs[componentId] = enabled
        SettingsData.set("showOnLastDisplay", newPrefs)
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: screensInfoSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
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

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                StyledText {
                                    text: I18n.tr("Available Screens (") + Quickshell.screens.length + ")"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                Item {
                                    width: 1
                                    height: 1
                                    Layout.fillWidth: true
                                }

                                Column {
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: I18n.tr("Display Name Format")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    DankButtonGroup {
                                        id: displayModeGroup
                                        model: [I18n.tr("Name"), I18n.tr("Model")]
                                        currentIndex: SettingsData.displayNameMode === "model" ? 1 : 0
                                        onSelectionChanged: (index, selected) => {
                                                                if (!selected)
                                                                return
                                                                SettingsData.displayNameMode = index === 1 ? "model" : "system"
                                                                SettingsData.saveSettings()
                                                            }

                                        Connections {
                                            target: SettingsData
                                            function onDisplayNameModeChanged() {
                                                displayModeGroup.currentIndex = SettingsData.displayNameMode === "model" ? 1 : 0
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: Quickshell.screens

                            delegate: Rectangle {
                                width: parent.width
                                height: screenRow.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
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
                                            text: SettingsData.getScreenDisplayName(modelData)
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        Row {
                                            spacing: Theme.spacingS

                                            property var wlrOutput: WlrOutputService.wlrOutputAvailable ? WlrOutputService.getOutput(modelData.name) : null
                                            property var currentMode: wlrOutput?.currentMode

                                            StyledText {
                                                text: {
                                                    if (parent.currentMode) {
                                                        return parent.currentMode.width + "×" + parent.currentMode.height + "@" + Math.round(parent.currentMode.refresh / 1000) + "Hz"
                                                    }
                                                    return modelData.width + "×" + modelData.height
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: SettingsData.displayNameMode === "system" ? (modelData.model || "Unknown Model") : modelData.name
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
                    model: root.variantComponents

                    delegate: StyledRect {
                        width: parent.width
                        height: componentSection.implicitHeight + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
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

                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    DankToggle {
                                        width: parent.width
                                        text: I18n.tr("All displays")
                                        description: I18n.tr("Show on all connected displays")
                                        checked: {
                                            var prefs = root.getScreenPreferences(parent.componentId)
                                            return prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all")
                                        }
                                        onToggled: checked => {
                                                       if (checked) {
                                                           root.setScreenPreferences(parent.componentId, ["all"])
                                                       } else {
                                                           root.setScreenPreferences(parent.componentId, [])
                                                           const cid = parent.componentId
                                                           if (["dankBar", "dock", "notifications", "osd", "toast"].includes(cid) || cid.startsWith("bar:")) {
                                                               root.setShowOnLastDisplay(cid, true)
                                                           }
                                                       }
                                                   }
                                    }

                                    DankToggle {
                                        width: parent.width
                                        text: I18n.tr("Show on Last Display")
                                        description: I18n.tr("Always show when there's only one connected display")
                                        checked: root.getShowOnLastDisplay(parent.componentId)
                                        visible: {
                                            const prefs = root.getScreenPreferences(parent.componentId)
                                            const isAll = prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all")
                                            const cid = parent.componentId
                                            const isRelevantComponent = ["dankBar", "dock", "notifications", "osd", "toast", "notepad"].includes(cid) || cid.startsWith("bar:")
                                            return !isAll && isRelevantComponent
                                        }
                                        onToggled: checked => {
                                                       root.setShowOnLastDisplay(parent.componentId, checked)
                                                   }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Theme.outline
                                        opacity: 0.2
                                        visible: {
                                            var prefs = root.getScreenPreferences(parent.componentId)
                                            return !prefs.includes("all") && !(typeof prefs[0] === "string" && prefs[0] === "all")
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        visible: {
                                            var prefs = root.getScreenPreferences(parent.componentId)
                                            return !prefs.includes("all") && !(typeof prefs[0] === "string" && prefs[0] === "all")
                                        }

                                        Repeater {
                                            model: Quickshell.screens

                                            delegate: DankToggle {
                                                property var screenData: modelData
                                                property string componentId: parent.parent.componentId

                                                width: parent.width
                                                text: SettingsData.getScreenDisplayName(screenData)
                                                description: screenData.width + "×" + screenData.height + " • " + (SettingsData.displayNameMode === "system" ? (screenData.model || "Unknown Model") : screenData.name)
                                                checked: {
                                                    var prefs = root.getScreenPreferences(componentId)
                                                    if (typeof prefs[0] === "string" && prefs[0] === "all")
                                                        return false
                                                    return SettingsData.isScreenInPreferences(screenData, prefs)
                                                }
                                                onToggled: checked => {
                                                               var currentPrefs = root.getScreenPreferences(componentId)
                                                               if (typeof currentPrefs[0] === "string" && currentPrefs[0] === "all") {
                                                                   currentPrefs = []
                                                               }

                                                               const screenModelIndex = SettingsData.getScreenModelIndex(screenData)

                                                               var newPrefs = currentPrefs.filter(pref => {
                                                                                                      if (typeof pref === "string")
                                                                                                      return false
                                                                                                      if (pref.modelIndex !== undefined && screenModelIndex >= 0) {
                                                                                                          return !(pref.model === screenData.model && pref.modelIndex === screenModelIndex)
                                                                                                      }
                                                                                                      return pref.name !== screenData.name || pref.model !== screenData.model
                                                                                                  })

                                                               if (checked) {
                                                                   const prefObj = {
                                                                       "name": screenData.name,
                                                                       "model": screenData.model || ""
                                                                   }
                                                                   if (screenModelIndex >= 0) {
                                                                       prefObj.modelIndex = screenModelIndex
                                                                   }
                                                                   newPrefs.push(prefObj)
                                                               }

                                                               root.setScreenPreferences(componentId, newPrefs)
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
