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
                    currentValue: SettingsData.monoFontFamily === Theme.defaultMonoFontFamily ? "Default" : (SettingsData.monoFontFamily || "Default")
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 400
                    onValueChanged: value => {
                        if (value === "Default")
                            SettingsData.set("monoFontFamily", Theme.defaultMonoFontFamily);
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
                    options: [I18n.tr("Thin", "font weight"), I18n.tr("Extra Light", "font weight"), I18n.tr("Light", "font weight"), I18n.tr("Regular", "font weight"), I18n.tr("Medium", "font weight"), I18n.tr("Demi Bold", "font weight"), I18n.tr("Bold", "font weight"), I18n.tr("Extra Bold", "font weight"), I18n.tr("Black", "font weight")]
                    currentValue: {
                        switch (SettingsData.fontWeight) {
                        case Font.Thin:
                            return I18n.tr("Thin", "font weight");
                        case Font.ExtraLight:
                            return I18n.tr("Extra Light", "font weight");
                        case Font.Light:
                            return I18n.tr("Light", "font weight");
                        case Font.Normal:
                            return I18n.tr("Regular", "font weight");
                        case Font.Medium:
                            return I18n.tr("Medium", "font weight");
                        case Font.DemiBold:
                            return I18n.tr("Demi Bold", "font weight");
                        case Font.Bold:
                            return I18n.tr("Bold", "font weight");
                        case Font.ExtraBold:
                            return I18n.tr("Extra Bold", "font weight");
                        case Font.Black:
                            return I18n.tr("Black", "font weight");
                        default:
                            return I18n.tr("Regular", "font weight");
                        }
                    }
                    onValueChanged: value => {
                        var weight;
                        switch (value) {
                        case I18n.tr("Thin", "font weight"):
                            weight = Font.Thin;
                            break;
                        case I18n.tr("Extra Light", "font weight"):
                            weight = Font.ExtraLight;
                            break;
                        case I18n.tr("Light", "font weight"):
                            weight = Font.Light;
                            break;
                        case I18n.tr("Regular", "font weight"):
                            weight = Font.Normal;
                            break;
                        case I18n.tr("Medium", "font weight"):
                            weight = Font.Medium;
                            break;
                        case I18n.tr("Demi Bold", "font weight"):
                            weight = Font.DemiBold;
                            break;
                        case I18n.tr("Bold", "font weight"):
                            weight = Font.Bold;
                            break;
                        case I18n.tr("Extra Bold", "font weight"):
                            weight = Font.ExtraBold;
                            break;
                        case I18n.tr("Black", "font weight"):
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
                tags: ["text", "render", "rendering", "quality", "anti-aliasing", "freetype", "distance", "field"]
                title: I18n.tr("Text Rendering")
                settingKey: "textRenderType"
                iconName: "text_format"

                SettingsButtonGroupRow {
                    tab: "typography"
                    tags: ["text", "render", "rendering", "type", "native", "qt", "curve", "freetype"]
                    settingKey: "textRenderType"
                    text: I18n.tr("Render Type")
                    description: {
                        switch (SettingsData.textRenderType) {
                        case SettingsData.TextRenderType.Qt:
                            return I18n.tr("Distance-field renderer.");
                        case SettingsData.TextRenderType.Curve:
                            return I18n.tr("Curve rasterizer.");
                        default:
                            return I18n.tr("Platform renderer (FreeType).");
                        }
                    }
                    model: [I18n.tr("Native"), I18n.tr("Qt"), I18n.tr("Curve")]
                    currentIndex: {
                        switch (SettingsData.textRenderType) {
                        case SettingsData.TextRenderType.Qt:
                            return 1;
                        case SettingsData.TextRenderType.Curve:
                            return 2;
                        default:
                            return 0;
                        }
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        switch (index) {
                        case 1:
                            SettingsData.set("textRenderType", SettingsData.TextRenderType.Qt);
                            break;
                        case 2:
                            SettingsData.set("textRenderType", SettingsData.TextRenderType.Curve);
                            break;
                        default:
                            SettingsData.set("textRenderType", SettingsData.TextRenderType.Native);
                            break;
                        }
                    }
                }

                SettingsDropdownRow {
                    id: renderQualityRow
                    tab: "typography"
                    tags: ["text", "render", "quality", "level"]
                    settingKey: "textRenderQuality"
                    text: I18n.tr("Quality")
                    options: [I18n.tr("Default"), I18n.tr("Low", "quality level option"), I18n.tr("Normal", "quality level option"), I18n.tr("High", "quality level option"), I18n.tr("Very High", "quality level option")]
                    currentValue: options[SettingsData.textRenderQuality] ?? options[0]
                    onValueChanged: value => {
                        const index = renderQualityRow.options.indexOf(value);
                        if (index < 0)
                            return;
                        SettingsData.set("textRenderQuality", index);
                    }
                }
            }

            SettingsCard {
                tab: "typography"
                tags: ["animation", "variant", "style", "slide", "fluent", "dynamic", "motion", "effect", "directional", "depth", "spring", "physics", "bounce", "accessibility", "reduce"]
                title: I18n.tr("Motion")
                settingKey: "animationVariant"
                iconName: "auto_awesome_motion"

                SettingsButtonGroupRow {
                    tab: "typography"
                    tags: ["animation", "variant", "style", "slide", "fluent", "dynamic", "motion"]
                    settingKey: "animationVariant"
                    text: I18n.tr("Animation Style")
                    description: {
                        switch (SettingsData.animationVariant) {
                        case 1:
                            return I18n.tr("Smooth cubic deceleration in, quick snap out, clean, elegant curves.");
                        case 2:
                            return I18n.tr("Spring bezier with overshoot, entry briefly exceeds its target then settles.");
                        default:
                            return I18n.tr("Material 3 Expressive bezier curves, default.");
                        }
                    }
                    model: [I18n.tr("Material"), I18n.tr("Fluent"), I18n.tr("Dynamic")]
                    currentIndex: SettingsData.animationVariant
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        SettingsData.set("animationVariant", index);
                    }
                }

                SettingsButtonGroupRow {
                    tab: "typography"
                    tags: ["animation", "motion", "effect", "slide", "directional", "depth", "spring", "physics"]
                    settingKey: "motionEffect"
                    text: I18n.tr("Motion Effects")
                    description: {
                        switch (SettingsData.motionEffect) {
                        case 1:
                            return I18n.tr("Panels glide in from a larger distance at full size, no scale change, pure clean motion.");
                        case 2:
                            return I18n.tr("Panels scale up from small as they slide in, a dramatic pop-forward depth effect.");
                        default:
                            return I18n.tr("Material 3 Expressive panels rise from below with a subtle scale, default.");
                        }
                    }
                    model: [I18n.tr("Standard"), I18n.tr("Directional"), I18n.tr("Depth")]
                    currentIndex: SettingsData.motionEffect
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        SettingsData.set("motionEffect", index);
                    }
                }

                SettingsButtonGroupRow {
                    tab: "typography"
                    tags: ["animation", "spring", "physics", "bounce", "motion"]
                    settingKey: "springBounce"
                    text: I18n.tr("Spring Motion")
                    description: {
                        switch (SettingsData.springBounce) {
                        case 0:
                            return I18n.tr("Damped springs settle straight to their target with no overshoot");
                        case 2:
                            return I18n.tr("Springs carry extra energy and visibly bounce before settling");
                        default:
                            return I18n.tr("A slight natural settle, DMS default");
                        }
                    }
                    model: [I18n.tr("Smooth"), I18n.tr("Balanced"), I18n.tr("Playful")]
                    currentIndex: SettingsData.springBounce
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        SettingsData.set("springBounce", index);
                    }
                }

                SettingsToggleRow {
                    tab: "typography"
                    tags: ["animation", "spring", "physics", "accessibility", "reduce", "motion"]
                    settingKey: "reduceMotion"
                    text: I18n.tr("Reduce Motion")
                    description: I18n.tr("Snap spring-driven motion straight to its target without physics travel")
                    checked: SettingsData.reduceMotion
                    onToggled: checked => SettingsData.set("reduceMotion", checked)
                }
            }

            SettingsCard {
                tab: "typography"
                tags: ["animation", "speed", "motion", "duration"]
                title: I18n.tr("Animation Speed")
                settingKey: "animationSpeed"
                iconName: "animation"

                SettingsButtonGroupRow {
                    tab: "typography"
                    tags: ["animation", "speed", "motion", "duration"]
                    settingKey: "animationSpeed"
                    text: I18n.tr("Speed")
                    model: [I18n.tr("None"), I18n.tr("Short"), I18n.tr("Medium"), I18n.tr("Long"), I18n.tr("Custom")]
                    currentIndex: SettingsData.animationSpeed
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        SettingsData.set("animationSpeed", index);
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
                    description: I18n.tr("Globally scale animation durations with geometric motion & spring based physics with bezier curves")
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
                }
            }

            SettingsCard {
                tab: "typography"
                tags: ["animation", "speed", "motion", "duration", "popout", "sync", "spring", "physics"]
                title: I18n.tr("%1 Animation Speed").arg(I18n.tr("Popouts"))
                settingKey: "popoutAnimationSpeed"
                iconName: "open_in_new"
                visible: !SettingsData.syncComponentAnimationSpeeds

                SettingsButtonGroupRow {
                    tab: "typography"
                    tags: ["animation", "speed", "motion", "duration", "popout"]
                    settingKey: "popoutAnimationSpeed"
                    text: I18n.tr("Speed")
                    model: [I18n.tr("None"), I18n.tr("Short"), I18n.tr("Medium"), I18n.tr("Long"), I18n.tr("Custom")]
                    currentIndex: SettingsData.popoutAnimationSpeed
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        if (SettingsData.syncComponentAnimationSpeeds)
                            SettingsData.set("syncComponentAnimationSpeeds", false);
                        SettingsData.set("popoutAnimationSpeed", index);
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
                tags: ["animation", "speed", "motion", "duration", "modal", "sync", "spring", "physics"]
                title: I18n.tr("%1 Animation Speed").arg(I18n.tr("Modals"))
                settingKey: "modalAnimationSpeed"
                iconName: "web_asset"
                visible: !SettingsData.syncComponentAnimationSpeeds

                SettingsButtonGroupRow {
                    tab: "typography"
                    tags: ["animation", "speed", "motion", "duration", "modal"]
                    settingKey: "modalAnimationSpeed"
                    text: I18n.tr("Speed")
                    model: [I18n.tr("None"), I18n.tr("Short"), I18n.tr("Medium"), I18n.tr("Long"), I18n.tr("Custom")]
                    currentIndex: SettingsData.modalAnimationSpeed
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        if (SettingsData.syncComponentAnimationSpeeds)
                            SettingsData.set("syncComponentAnimationSpeeds", false);
                        SettingsData.set("modalAnimationSpeed", index);
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
