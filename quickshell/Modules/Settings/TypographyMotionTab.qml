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
                tags: ["animation", "variant", "style", "slide", "fluent", "dynamic", "motion"]
                title: I18n.tr("Animation Style")
                settingKey: "animationVariant"
                iconName: "auto_awesome_motion"

                Item {
                    width: parent.width
                    height: animVariantGroup.implicitHeight
                    clip: true

                    DankButtonGroup {
                        id: animVariantGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        buttonPadding: parent.width < 480 ? Theme.spacingS : Theme.spacingL
                        minButtonWidth: parent.width < 480 ? 64 : 96
                        textSize: parent.width < 480 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                        model: [I18n.tr("Material"), I18n.tr("Fluent"), I18n.tr("Dynamic")]
                        selectionMode: "single"
                        currentIndex: SettingsData.animationVariant
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            SettingsData.set("animationVariant", index);
                        }

                        Connections {
                            target: SettingsData
                            function onAnimationVariantChanged() {
                                animVariantGroup.currentIndex = SettingsData.animationVariant;
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

                Item {
                    width: parent.width
                    height: variantDescription.implicitHeight + Theme.spacingS * 2

                    StyledText {
                        id: variantDescription
                        x: Theme.spacingM
                        y: Theme.spacingS
                        width: parent.width - Theme.spacingM * 2
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        text: {
                            switch (SettingsData.animationVariant) {
                            case 1:
                                return I18n.tr("Fluent: Smooth cubic deceleration in, quick snap out — clean, elegant curves.");
                            case 2:
                                return I18n.tr("Dynamic: Spring bezier with overshoot — entry briefly exceeds its target then settles. Expressive and alive.");
                            default:
                                return I18n.tr("Material: Material Design 3 Expressive bezier curves. The DMS default feel.");
                            }
                        }
                    }
                }
            }

            SettingsCard {
                tab: "typography"
                tags: ["animation", "motion", "effect", "slide", "directional", "depth", "spring", "physics"]
                title: I18n.tr("Motion Effects")
                settingKey: "motionEffect"
                iconName: "motion_photos_on"

                Item {
                    width: parent.width
                    height: motionEffectGroup.implicitHeight
                    clip: true

                    DankButtonGroup {
                        id: motionEffectGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        buttonPadding: parent.width < 480 ? Theme.spacingS : Theme.spacingL
                        minButtonWidth: parent.width < 480 ? 64 : 96
                        textSize: parent.width < 480 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                        model: [I18n.tr("Standard"), I18n.tr("Directional"), I18n.tr("Depth")]
                        selectionMode: "single"
                        currentIndex: SettingsData.motionEffect
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            SettingsData.set("motionEffect", index);
                        }

                        Connections {
                            target: SettingsData
                            function onMotionEffectChanged() {
                                motionEffectGroup.currentIndex = SettingsData.motionEffect;
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

                Item {
                    width: parent.width
                    height: motionEffectDescription.implicitHeight + Theme.spacingS * 2

                    StyledText {
                        id: motionEffectDescription
                        x: Theme.spacingM
                        y: Theme.spacingS
                        width: parent.width - Theme.spacingM * 2
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        text: {
                            switch (SettingsData.motionEffect) {
                            case 1:
                                return I18n.tr("Directional: Panels glide in from a larger distance at full size — no scale change, pure clean motion.");
                            case 2:
                                return I18n.tr("Depth: Panels scale up from small as they slide in — a dramatic pop-forward depth effect.");
                            default:
                                return I18n.tr("Standard: Classic Material Design 3 — panels rise from below with a subtle scale. The DMS default.");
                            }
                        }
                    }
                }
            }

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
