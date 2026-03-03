import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var cachedFontFamilies: []
    property var cachedMonoFamilies: []
    property bool fontsEnumerated: false

    function enumerateFonts() {
        var fonts = [];
        var availableFonts = Qt.fontFamilies();

        for (var i = 0; i < availableFonts.length; i++) {
            var fontName = availableFonts[i];
            if (fontName.startsWith("."))
                continue;
            fonts.push(fontName);
        }
        fonts.sort();
        fonts.unshift(I18n.tr("Default"));
        cachedFontFamilies = fonts;
        cachedMonoFamilies = fonts;
    }

    Timer {
        id: fontEnumerationTimer
        interval: 50
        running: false
        onTriggered: {
            if (fontsEnumerated)
                return;
            enumerateFonts();
            fontsEnumerated = true;
        }
    }

    Component.onCompleted: {
        fontEnumerationTimer.start();
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                tab: "typography"
                tags: ["font", "family", "text", "typography"]
                title: I18n.tr("Typography")
                settingKey: "typography"
                iconName: "text_fields"

                SettingsDropdownRow {
                    tab: "typography"
                    tags: ["font", "family", "normal", "text"]
                    settingKey: "fontFamily"
                    text: I18n.tr("Normal Font")
                    description: I18n.tr("Select the font family for UI text")
                    options: root.fontsEnumerated ? root.cachedFontFamilies : [I18n.tr("Default")]
                    currentValue: SettingsData.fontFamily === Theme.defaultFontFamily ? I18n.tr("Default") : (SettingsData.fontFamily || I18n.tr("Default"))
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 400
                    onValueChanged: value => {
                        if (value === I18n.tr("Default"))
                            SettingsData.set("fontFamily", Theme.defaultFontFamily);
                        else
                            SettingsData.set("fontFamily", value);
                    }
                }

                SettingsDropdownRow {
                    tab: "typography"
                    tags: ["font", "monospace", "code", "terminal"]
                    settingKey: "monoFontFamily"
                    text: I18n.tr("Monospace Font")
                    description: I18n.tr("Select monospace font for process list and technical displays")
                    options: root.fontsEnumerated ? root.cachedMonoFamilies : [I18n.tr("Default")]
                    currentValue: SettingsData.monoFontFamily === SettingsData.defaultMonoFontFamily ? I18n.tr("Default") : (SettingsData.monoFontFamily || I18n.tr("Default"))
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 400
                    onValueChanged: value => {
                        if (value === I18n.tr("Default"))
                            SettingsData.set("monoFontFamily", SettingsData.defaultMonoFontFamily);
                        else
                            SettingsData.set("monoFontFamily", value);
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsDropdownRow {
                    tab: "typography"
                    tags: ["font", "weight", "bold", "light"]
                    settingKey: "fontWeight"
                    text: I18n.tr("Font Weight")
                    description: I18n.tr("Select font weight for UI text")
                    options: [
                        I18n.tr("Thin"),
                        I18n.tr("Extra Light"),
                        I18n.tr("Light"),
                        I18n.tr("Regular"),
                        I18n.tr("Medium"),
                        I18n.tr("Demi Bold"),
                        I18n.tr("Bold"),
                        I18n.tr("Extra Bold"),
                        I18n.tr("Black")
                    ]
                    currentValue: {
                        switch (SettingsData.fontWeight) {
                        case Font.Thin:
                            return I18n.tr("Thin");
                        case Font.ExtraLight:
                            return I18n.tr("Extra Light");
                        case Font.Light:
                            return I18n.tr("Light");
                        case Font.Normal:
                            return I18n.tr("Regular");
                        case Font.Medium:
                            return I18n.tr("Medium");
                        case Font.DemiBold:
                            return I18n.tr("Demi Bold");
                        case Font.Bold:
                            return I18n.tr("Bold");
                        case Font.ExtraBold:
                            return I18n.tr("Extra Bold");
                        case Font.Black:
                            return I18n.tr("Black");
                        default:
                            return I18n.tr("Regular");
                        }
                    }
                    onValueChanged: value => {
                        var weight;
                        if (value === I18n.tr("Thin"))
                            weight = Font.Thin;
                        else if (value === I18n.tr("Extra Light"))
                            weight = Font.ExtraLight;
                        else if (value === I18n.tr("Light"))
                            weight = Font.Light;
                        else if (value === I18n.tr("Regular"))
                            weight = Font.Normal;
                        else if (value === I18n.tr("Medium"))
                            weight = Font.Medium;
                        else if (value === I18n.tr("Demi Bold"))
                            weight = Font.DemiBold;
                        else if (value === I18n.tr("Bold"))
                            weight = Font.Bold;
                        else if (value === I18n.tr("Extra Bold"))
                            weight = Font.ExtraBold;
                        else if (value === I18n.tr("Black"))
                            weight = Font.Black;
                        else
                            weight = Font.Normal;
                        SettingsData.set("fontWeight", weight);
                    }
                }

                SettingsSliderRow {
                    tab: "typography"
                    tags: ["font", "scale", "size", "zoom"]
                    settingKey: "fontScale"
                    text: I18n.tr("Font Scale")
                    description: I18n.tr("Scale all font sizes throughout the shell")
                    minimum: 75
                    maximum: 150
                    value: Math.round(SettingsData.fontScale * 100)
                    unit: "%"
                    defaultValue: 100
                    onSliderValueChanged: newValue => SettingsData.set("fontScale", newValue / 100)
                }
            }

            SettingsCard {
                tab: "typography"
                tags: ["animation", "speed", "motion", "duration"]
                title: I18n.tr("Animation Speed")
                settingKey: "animationSpeed"
                iconName: "animation"

                Item {
                    width: parent.width
                    height: animationSpeedGroup.implicitHeight
                    clip: true

                    DankButtonGroup {
                        id: animationSpeedGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        buttonPadding: parent.width < 480 ? Theme.spacingS : Theme.spacingL
                        minButtonWidth: parent.width < 480 ? 44 : 64
                        textSize: parent.width < 480 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                        model: [I18n.tr("None"), I18n.tr("Short"), I18n.tr("Medium"), I18n.tr("Long"), I18n.tr("Custom")]
                        selectionMode: "single"
                        currentIndex: SettingsData.animationSpeed
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            SettingsData.set("animationSpeed", index);
                        }

                        Connections {
                            target: SettingsData
                            function onAnimationSpeedChanged() {
                                animationSpeedGroup.currentIndex = SettingsData.animationSpeed;
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsSliderRow {
                    id: durationSlider
                    tab: "typography"
                    tags: ["animation", "duration", "custom", "speed"]
                    settingKey: "customAnimationDuration"
                    text: I18n.tr("Animation Duration")
                    description: I18n.tr("Globally scale all animation durations")
                    minimum: 0
                    maximum: 1000
                    value: Theme.currentAnimationBaseDuration
                    unit: "ms"
                    defaultValue: 200
                    onSliderValueChanged: newValue => {
                        SettingsData.set("animationSpeed", SettingsData.AnimationSpeed.Custom);
                        SettingsData.set("customAnimationDuration", newValue);
                    }

                    Connections {
                        target: SettingsData
                        function onAnimationSpeedChanged() {
                            if (SettingsData.animationSpeed === SettingsData.AnimationSpeed.Custom)
                                return;
                            durationSlider.value = Theme.currentAnimationBaseDuration;
                        }
                    }

                    Connections {
                        target: Theme
                        function onCurrentAnimationBaseDurationChanged() {
                            if (SettingsData.animationSpeed === SettingsData.AnimationSpeed.Custom)
                                return;
                            durationSlider.value = Theme.currentAnimationBaseDuration;
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsToggleRow {
                    tab: "typography"
                    tags: ["animation", "sync", "popout", "modal", "global"]
                    settingKey: "syncComponentAnimationSpeeds"
                    text: I18n.tr("Sync Popouts & Modals")
                    description: I18n.tr("Popouts and Modals follow global Animation Speed (disable to customize independently)")
                    checked: SettingsData.syncComponentAnimationSpeeds
                    onToggled: checked => SettingsData.set("syncComponentAnimationSpeeds", checked)

                    Connections {
                        target: SettingsData
                        function onSyncComponentAnimationSpeedsChanged() {
                        }
                    }
                }
            }

            SettingsCard {
                tab: "typography"
                tags: ["animation", "speed", "motion", "duration", "popout", "sync"]
                title: I18n.tr("%1 Animation Speed").arg(I18n.tr("Popouts"))
                settingKey: "popoutAnimationSpeed"
                iconName: "open_in_new"

                Item {
                    width: parent.width
                    height: popoutSpeedGroup.implicitHeight
                    clip: true

                    DankButtonGroup {
                        id: popoutSpeedGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        buttonPadding: parent.width < 480 ? Theme.spacingS : Theme.spacingL
                        minButtonWidth: parent.width < 480 ? 44 : 64
                        textSize: parent.width < 480 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                        model: [I18n.tr("None"), I18n.tr("Short"), I18n.tr("Medium"), I18n.tr("Long"), I18n.tr("Custom")]
                        selectionMode: "single"
                        currentIndex: SettingsData.popoutAnimationSpeed
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            if (SettingsData.syncComponentAnimationSpeeds)
                                SettingsData.set("syncComponentAnimationSpeeds", false);
                            SettingsData.set("popoutAnimationSpeed", index);
                        }

                        Connections {
                            target: SettingsData
                            function onPopoutAnimationSpeedChanged() {
                                popoutSpeedGroup.currentIndex = SettingsData.popoutAnimationSpeed;
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsSliderRow {
                    id: popoutDurationSlider
                    tab: "typography"
                    tags: ["animation", "duration", "custom", "speed", "popout"]
                    settingKey: "popoutCustomAnimationDuration"
                    text: I18n.tr("Custom Duration")
                    description: I18n.tr("%1 custom animation duration").arg(I18n.tr("Popouts"))
                    minimum: 0
                    maximum: 1000
                    value: Theme.popoutAnimationDuration
                    unit: "ms"
                    defaultValue: 150
                    onSliderValueChanged: newValue => {
                        if (SettingsData.syncComponentAnimationSpeeds)
                            SettingsData.set("syncComponentAnimationSpeeds", false);
                        SettingsData.set("popoutAnimationSpeed", SettingsData.AnimationSpeed.Custom);
                        SettingsData.set("popoutCustomAnimationDuration", newValue);
                    }

                    Connections {
                        target: SettingsData
                        function onPopoutAnimationSpeedChanged() {
                            if (SettingsData.popoutAnimationSpeed === SettingsData.AnimationSpeed.Custom)
                                return;
                            popoutDurationSlider.value = Theme.popoutAnimationDuration;
                        }
                    }

                    Connections {
                        target: Theme
                        function onPopoutAnimationDurationChanged() {
                            if (!SettingsData.syncComponentAnimationSpeeds && SettingsData.popoutAnimationSpeed === SettingsData.AnimationSpeed.Custom)
                                return;
                            popoutDurationSlider.value = Theme.popoutAnimationDuration;
                        }
                    }
                }
            }

            SettingsCard {
                tab: "typography"
                tags: ["animation", "speed", "motion", "duration", "modal", "sync"]
                title: I18n.tr("%1 Animation Speed").arg(I18n.tr("Modals"))
                settingKey: "modalAnimationSpeed"
                iconName: "web_asset"

                Item {
                    width: parent.width
                    height: modalSpeedGroup.implicitHeight
                    clip: true

                    DankButtonGroup {
                        id: modalSpeedGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        buttonPadding: parent.width < 480 ? Theme.spacingS : Theme.spacingL
                        minButtonWidth: parent.width < 480 ? 44 : 64
                        textSize: parent.width < 480 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                        model: [I18n.tr("None"), I18n.tr("Short"), I18n.tr("Medium"), I18n.tr("Long"), I18n.tr("Custom")]
                        selectionMode: "single"
                        currentIndex: SettingsData.modalAnimationSpeed
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            if (SettingsData.syncComponentAnimationSpeeds)
                                SettingsData.set("syncComponentAnimationSpeeds", false);
                            SettingsData.set("modalAnimationSpeed", index);
                        }

                        Connections {
                            target: SettingsData
                            function onModalAnimationSpeedChanged() {
                                modalSpeedGroup.currentIndex = SettingsData.modalAnimationSpeed;
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsSliderRow {
                    id: modalDurationSlider
                    tab: "typography"
                    tags: ["animation", "duration", "custom", "speed", "modal"]
                    settingKey: "modalCustomAnimationDuration"
                    text: I18n.tr("Custom Duration")
                    description: I18n.tr("%1 custom animation duration").arg(I18n.tr("Modals"))
                    minimum: 0
                    maximum: 1000
                    value: Theme.modalAnimationDuration
                    unit: "ms"
                    defaultValue: 150
                    onSliderValueChanged: newValue => {
                        if (SettingsData.syncComponentAnimationSpeeds)
                            SettingsData.set("syncComponentAnimationSpeeds", false);
                        SettingsData.set("modalAnimationSpeed", SettingsData.AnimationSpeed.Custom);
                        SettingsData.set("modalCustomAnimationDuration", newValue);
                    }

                    Connections {
                        target: SettingsData
                        function onModalAnimationSpeedChanged() {
                            if (SettingsData.modalAnimationSpeed === SettingsData.AnimationSpeed.Custom)
                                return;
                            modalDurationSlider.value = Theme.modalAnimationDuration;
                        }
                    }

                    Connections {
                        target: Theme
                        function onModalAnimationDurationChanged() {
                            if (!SettingsData.syncComponentAnimationSpeeds && SettingsData.modalAnimationSpeed === SettingsData.AnimationSpeed.Custom)
                                return;
                            modalDurationSlider.value = Theme.modalAnimationDuration;
                        }
                    }
                }
            }

            SettingsCard {
                tab: "typography"
                tags: ["animation", "ripple", "effect", "material", "feedback"]
                title: I18n.tr("Ripple Effects")
                settingKey: "enableRippleEffects"
                iconName: "radio_button_unchecked"

                SettingsToggleRow {
                    tab: "typography"
                    tags: ["animation", "ripple", "effect", "material", "click"]
                    settingKey: "enableRippleEffects"
                    text: I18n.tr("Enable Ripple Effects")
                    description: I18n.tr("Show Material Design ripple animations on interactive elements")
                    checked: SettingsData.enableRippleEffects ?? true
                    onToggled: newValue => SettingsData.set("enableRippleEffects", newValue)

                    Connections {
                        target: SettingsData
                        function onEnableRippleEffectsChanged() {
                        }
                    }
                }
            }
        }
    }
}
