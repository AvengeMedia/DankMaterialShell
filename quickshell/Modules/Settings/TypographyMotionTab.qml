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
        fonts.unshift("Default");
        cachedFontFamilies = fonts;

        var monoFonts = [];
        for (var j = 0; j < availableFonts.length; j++) {
            var fontName2 = availableFonts[j];
            if (fontName2.startsWith("."))
                continue;
            var lowerName = fontName2.toLowerCase();
            if (lowerName.includes("mono") || lowerName.includes("code") || lowerName.includes("console") || lowerName.includes("terminal") || lowerName.includes("courier") || lowerName.includes("jetbrains") || lowerName.includes("fira") || lowerName.includes("hack") || lowerName.includes("source code") || lowerName.includes("cascadia")) {
                monoFonts.push(fontName2);
            }
        }
        monoFonts.sort();
        monoFonts.unshift("Default");
        cachedMonoFamilies = monoFonts;
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
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                tab: "typography"
                tags: ["font", "family", "text", "typography"]
                title: I18n.tr("Typography")
                iconName: "text_fields"

                SettingsDropdownRow {
                    tab: "typography"
                    tags: ["font", "family", "normal", "text"]
                    settingKey: "fontFamily"
                    text: I18n.tr("Normal Font")
                    description: I18n.tr("Select the font family for UI text")
                    options: root.fontsEnumerated ? root.cachedFontFamilies : ["Default"]
                    currentValue: SettingsData.fontFamily === Theme.defaultFontFamily ? "Default" : (SettingsData.fontFamily || "Default")
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 400
                    onValueChanged: value => {
                        if (value === "Default")
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
                    options: root.fontsEnumerated ? root.cachedMonoFamilies : ["Default"]
                    currentValue: SettingsData.monoFontFamily === SettingsData.defaultMonoFontFamily ? "Default" : (SettingsData.monoFontFamily || "Default")
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 400
                    onValueChanged: value => {
                        if (value === "Default")
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
                    options: ["Thin", "Extra Light", "Light", "Regular", "Medium", "Demi Bold", "Bold", "Extra Bold", "Black"]
                    currentValue: {
                        switch (SettingsData.fontWeight) {
                        case Font.Thin:
                            return "Thin";
                        case Font.ExtraLight:
                            return "Extra Light";
                        case Font.Light:
                            return "Light";
                        case Font.Normal:
                            return "Regular";
                        case Font.Medium:
                            return "Medium";
                        case Font.DemiBold:
                            return "Demi Bold";
                        case Font.Bold:
                            return "Bold";
                        case Font.ExtraBold:
                            return "Extra Bold";
                        case Font.Black:
                            return "Black";
                        default:
                            return "Regular";
                        }
                    }
                    onValueChanged: value => {
                        var weight;
                        switch (value) {
                        case "Thin":
                            weight = Font.Thin;
                            break;
                        case "Extra Light":
                            weight = Font.ExtraLight;
                            break;
                        case "Light":
                            weight = Font.Light;
                            break;
                        case "Regular":
                            weight = Font.Normal;
                            break;
                        case "Medium":
                            weight = Font.Medium;
                            break;
                        case "Demi Bold":
                            weight = Font.DemiBold;
                            break;
                        case "Bold":
                            weight = Font.Bold;
                            break;
                        case "Extra Bold":
                            weight = Font.ExtraBold;
                            break;
                        case "Black":
                            weight = Font.Black;
                            break;
                        default:
                            weight = Font.Normal;
                            break;
                        }
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
                    text: I18n.tr("Custom Duration")
                    description: I18n.tr("Fine-tune animation timing in milliseconds")
                    minimum: 0
                    maximum: 750
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
            }
        }
    }
}
