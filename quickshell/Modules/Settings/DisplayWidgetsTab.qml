import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    function getBarComponentsFromSettings() {
        const bars = SettingsData.barConfigs || [];
        return bars.map(bar => {
            const isIsland = SettingsData.isIslandBarConfig(bar);
            return {
                "id": "bar:" + bar.id,
                "name": bar.name || "Bar",
                "description": isIsland ? I18n.tr("Dank Island instance") : I18n.tr("Individual bar configuration"),
                "icon": isIsland ? "view_in_ar" : "toolbar",
                "barId": bar.id
            };
        });
    }

    property var variantComponents: getVariantComponentsList()

    function getVariantComponentsList() {
        return [...getBarComponentsFromSettings(),
            {
                "id": "notifications",
                "name": I18n.tr("Notification popups"),
                "icon": "notifications"
            },
            {
                "id": "wallpaper",
                "name": I18n.tr("Wallpaper"),
                "icon": "wallpaper"
            },
            {
                "id": "osd",
                "name": I18n.tr("OSD", "on-screen display, shell component name in per-display settings"),
                "icon": "picture_in_picture"
            },
            {
                "id": "toast",
                "name": I18n.tr("Toasts", "noun plural, toast popups, shell component name in per-display settings"),
                "icon": "campaign"
            },
            {
                "id": "notepad",
                "name": I18n.tr("Notepad"),
                "icon": "sticky_note_2"
            }
        ];
    }

    Connections {
        target: SettingsData
        function onBarConfigsChanged() {
            variantComponents = getVariantComponentsList();
        }
    }

    function getScreenPreferences(componentId) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4);
            const barConfig = SettingsData.getBarConfig(barId);
            return barConfig?.screenPreferences || ["all"];
        }
        return SettingsData.screenPreferences && SettingsData.screenPreferences[componentId] || ["all"];
    }

    function setScreenPreferences(componentId, screenNames) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4);
            SettingsData.updateBarConfig(barId, {
                "screenPreferences": screenNames
            });
            return;
        }
        var prefs = SettingsData.screenPreferences || {};
        var newPrefs = Object.assign({}, prefs);
        newPrefs[componentId] = screenNames;
        SettingsData.set("screenPreferences", newPrefs);
    }

    function getShowOnLastDisplay(componentId) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4);
            const barConfig = SettingsData.getBarConfig(barId);
            return barConfig?.showOnLastDisplay ?? true;
        }
        return SettingsData.showOnLastDisplay && SettingsData.showOnLastDisplay[componentId] || false;
    }

    function setShowOnLastDisplay(componentId, enabled) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4);
            SettingsData.updateBarConfig(barId, {
                "showOnLastDisplay": enabled
            });
            return;
        }
        var prefs = SettingsData.showOnLastDisplay || {};
        var newPrefs = Object.assign({}, prefs);
        newPrefs[componentId] = enabled;
        SettingsData.set("showOnLastDisplay", newPrefs);
    }

    SettingsPage {
        id: mainColumn

        StyledRect {
            width: parent.width
            height: screensInfoSection.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Theme.floatingWindowNestedSurface
            border.color: Theme.outlineMedium
            border.width: Theme.layerOutlineWidth

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
                            text: I18n.tr("Connected displays")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Theme.fontWeightMedium
                            color: Theme.surfaceText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
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
                                text: I18n.tr("Available displays (%1)", "display widgets settings heading, %1 is the monitor count").arg(Quickshell.screens.length)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                                horizontalAlignment: Text.AlignLeft
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
                                    text: I18n.tr("Name format")
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
                                            return;
                                        SettingsData.displayNameMode = index === 1 ? "model" : "system";
                                        SettingsData.saveSettings();
                                    }

                                    Connections {
                                        target: SettingsData
                                        function onDisplayNameModeChanged() {
                                            displayModeGroup.currentIndex = SettingsData.displayNameMode === "model" ? 1 : 0;
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
                            color: Theme.floatingWindowNestedSurface
                            border.color: Theme.outlineMedium
                            border.width: Theme.layerOutlineWidth

                            Row {
                                id: screenRow

                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: "desktop_windows"
                                    size: Theme.iconSizeMedium
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
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        property var wlrOutput: WlrOutputService.wlrOutputAvailable ? WlrOutputService.getOutput(modelData.name) : null
                                        property var currentMode: wlrOutput?.currentMode

                                        StyledText {
                                            text: {
                                                if (parent.currentMode) {
                                                    return parent.currentMode.width + "×" + parent.currentMode.height + "@" + Math.round(parent.currentMode.refresh / 1000) + "Hz";
                                                }
                                                return modelData.width + "×" + modelData.height;
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
                    color: Theme.floatingWindowNestedSurface
                    border.color: Theme.outlineMedium
                    border.width: Theme.layerOutlineWidth

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
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.surfaceText
                                    width: parent.width
                                    horizontalAlignment: Text.AlignLeft
                                }

                                StyledText {
                                    visible: text !== ""
                                    text: modelData.description ?? ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                        }

                        SettingsDisplayPicker {
                            readonly property string componentId: modelData.id
                            visible: componentId !== "dock"
                            displayPreferences: root.getScreenPreferences(componentId)
                            emptyMeansAll: false
                            allowEmpty: true
                            showLastDisplay: ["dankBar", "notifications", "osd", "toast", "notepad"].includes(componentId) || componentId.startsWith("bar:")
                            showOnLastDisplay: root.getShowOnLastDisplay(componentId)
                            onPreferencesChanged: prefs => root.setScreenPreferences(componentId, prefs)
                            onLastDisplayToggled: checked => root.setShowOnLastDisplay(componentId, checked)
                        }

                        SettingsToggleRow {
                            resetKeys: ["notificationFocusedMonitor"]
                            visible: modelData.id === "notifications"
                            text: I18n.tr("Focused display only")
                            checked: SettingsData.notificationFocusedMonitor
                            onToggled: checked => SettingsData.set("notificationFocusedMonitor", checked)
                        }

                        Column {
                            visible: modelData.id === "dock"
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Show on displays") + ":"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Theme.fontWeightMedium
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            Column {
                                property string componentId: modelData.id

                                width: parent.width
                                spacing: Theme.spacingXS

                                DankToggle {
                                    width: parent.width
                                    text: I18n.tr("All displays")
                                    checked: {
                                        var prefs = root.getScreenPreferences(parent.componentId);
                                        return prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all");
                                    }
                                    onToggled: checked => {
                                        if (checked) {
                                            root.setScreenPreferences(parent.componentId, ["all"]);
                                        } else {
                                            root.setScreenPreferences(parent.componentId, []);
                                            const cid = parent.componentId;
                                            if (["dankBar", "notifications", "osd", "toast"].includes(cid) || cid.startsWith("bar:")) {
                                                root.setShowOnLastDisplay(cid, true);
                                            }
                                        }
                                    }
                                }

                                DankToggle {
                                    width: parent.width
                                    text: I18n.tr("Focused display only")
                                    visible: parent.componentId === "notifications"
                                    checked: SettingsData.notificationFocusedMonitor
                                    onToggled: checked => SettingsData.set("notificationFocusedMonitor", checked)
                                }

                                DankToggle {
                                    width: parent.width
                                    text: I18n.tr("Show on last display")
                                    checked: root.getShowOnLastDisplay(parent.componentId)
                                    visible: {
                                        const prefs = root.getScreenPreferences(parent.componentId);
                                        const isAll = prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all");
                                        const cid = parent.componentId;
                                        const isRelevantComponent = ["dankBar", "notifications", "osd", "toast", "notepad"].includes(cid) || cid.startsWith("bar:");
                                        return !isAll && isRelevantComponent;
                                    }
                                    onToggled: checked => {
                                        root.setShowOnLastDisplay(parent.componentId, checked);
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Theme.outline
                                    opacity: 0.2
                                    visible: {
                                        var prefs = root.getScreenPreferences(parent.componentId);
                                        return !prefs.includes("all") && !(typeof prefs[0] === "string" && prefs[0] === "all");
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: Theme.spacingXS
                                    visible: {
                                        var prefs = root.getScreenPreferences(parent.componentId);
                                        return !prefs.includes("all") && !(typeof prefs[0] === "string" && prefs[0] === "all");
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
                                                var prefs = root.getScreenPreferences(componentId);
                                                if (typeof prefs[0] === "string" && prefs[0] === "all")
                                                    return false;
                                                return SettingsData.isScreenInPreferences(screenData, prefs);
                                            }
                                            onToggled: checked => {
                                                var currentPrefs = root.getScreenPreferences(componentId);
                                                if (typeof currentPrefs[0] === "string" && currentPrefs[0] === "all") {
                                                    currentPrefs = [];
                                                }

                                                const screenModelIndex = SettingsData.getScreenModelIndex(screenData);

                                                var newPrefs = currentPrefs.filter(pref => {
                                                    if (typeof pref === "string")
                                                        return false;
                                                    if (pref.modelIndex !== undefined && screenModelIndex >= 0) {
                                                        return !(pref.model === screenData.model && pref.modelIndex === screenModelIndex);
                                                    }
                                                    return pref.name !== screenData.name || pref.model !== screenData.model;
                                                });

                                                if (checked) {
                                                    const prefObj = {
                                                        "name": screenData.name,
                                                        "model": screenData.model || ""
                                                    };
                                                    if (screenModelIndex >= 0) {
                                                        prefObj.modelIndex = screenModelIndex;
                                                    }
                                                    newPrefs.push(prefObj);
                                                }

                                                root.setScreenPreferences(componentId, newPrefs);
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
