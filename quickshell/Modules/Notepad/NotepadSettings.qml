pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool isVisible: false
    property var cachedFontFamilies: []
    property var cachedMonoFamilies: []
    property bool fontsEnumerated: false
    property bool shortcutsExpanded: false

    signal settingsRequested
    signal findRequested

    function enumerateFonts() {
        var fonts = ["Default"];
        var availableFonts = Qt.fontFamilies();
        var rootFamilies = [];
        var seenFamilies = new Set();
        for (var i = 0; i < availableFonts.length; i++) {
            var fontName = availableFonts[i];
            if (fontName.startsWith("."))
                continue;
            if (fontName === Theme.defaultFontFamily)
                continue;
            var rootName = fontName.replace(/ (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i, "").replace(/ (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i, "").replace(/ (UI|Display|Text|Mono|Sans|Serif)$/i, function (match, suffix) {
                return match;
            }).trim();
            if (!seenFamilies.has(rootName) && rootName !== "") {
                seenFamilies.add(rootName);
                rootFamilies.push(rootName);
            }
        }
        cachedFontFamilies = fonts.concat(rootFamilies.sort());
        var monoFonts = ["Default"];
        var monoFamilies = [];
        var seenMonoFamilies = new Set();
        for (var j = 0; j < availableFonts.length; j++) {
            var fontName2 = availableFonts[j];
            if (fontName2.startsWith("."))
                continue;
            if (fontName2 === Theme.defaultMonoFontFamily)
                continue;
            var lowerName = fontName2.toLowerCase();
            if (lowerName.includes("mono") || lowerName.includes("code") || lowerName.includes("console") || lowerName.includes("terminal") || lowerName.includes("courier") || lowerName.includes("dejavu sans mono") || lowerName.includes("jetbrains") || lowerName.includes("fira") || lowerName.includes("hack") || lowerName.includes("source code") || lowerName.includes("ubuntu mono") || lowerName.includes("cascadia")) {
                var rootName2 = fontName2.replace(/ (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i, "").replace(/ (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i, "").trim();
                if (!seenMonoFamilies.has(rootName2) && rootName2 !== "") {
                    seenMonoFamilies.add(rootName2);
                    monoFamilies.push(rootName2);
                }
            }
        }
        cachedMonoFamilies = monoFonts.concat(monoFamilies.sort());
        fontsEnumerated = true;
    }

    Component.onCompleted: {
        if (!fontsEnumerated) {
            enumerateFonts();
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.isVisible
        z: 50
        color: Theme.withAlpha(Theme.surface, 0.85)

        WheelHandler {
            // Hold scroll so the editor beneath doesn't move while settings are open.
            onWheel: event => {
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.settingsRequested()
        }
    }

    Rectangle {
        id: settingsMenu
        visible: root.isVisible
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(360, root.width - Theme.spacingL * 2)
        height: Math.min(settingsColumn.implicitHeight + Theme.spacingXL * 2, root.height - Theme.spacingL * 2)
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.notepadTransparency)
        border.color: Theme.outlineMedium
        border.width: 1
        z: 100

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
        }

        DankFlickable {
            id: settingsFlickable
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight + Theme.spacingXL * 2

            Column {
                id: settingsColumn
                x: Theme.spacingXL
                y: Theme.spacingXL
                width: settingsFlickable.width - Theme.spacingXL * 2
                spacing: Theme.spacingS

                Rectangle {
                    width: parent.width
                    height: 36
                    color: "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: -Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Notepad Settings")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outlineHeavy
                }

                DankToggle {
                    anchors.left: parent.left
                    anchors.leftMargin: -Theme.spacingM
                    width: parent.width + Theme.spacingM
                    text: I18n.tr("Use Monospace Font")
                    description: I18n.tr("Toggle fonts")
                    checked: SettingsData.notepadUseMonospace
                    onToggled: checked => {
                        SettingsData.notepadUseMonospace = checked;
                    }
                }

                DankToggle {
                    anchors.left: parent.left
                    anchors.leftMargin: -Theme.spacingM
                    width: parent.width + Theme.spacingM
                    text: I18n.tr("Show Line Numbers")
                    description: I18n.tr("Display line numbers in editor")
                    checked: SettingsData.notepadShowLineNumbers
                    onToggled: checked => {
                        SettingsData.notepadShowLineNumbers = checked;
                    }
                }

                DankToggle {
                    anchors.left: parent.left
                    anchors.leftMargin: -Theme.spacingM
                    width: parent.width + Theme.spacingM
                    text: I18n.tr("Auto-save to disk")
                    description: I18n.tr("Automatically save changes to opened files as you type")
                    checked: SettingsData.notepadAutoSave
                    onToggled: checked => {
                        SettingsData.notepadAutoSave = checked;
                    }
                }

                StyledRect {
                    width: parent.width
                    height: 60
                    radius: Theme.cornerRadius
                    color: "transparent"

                    StateLayer {
                        anchors.fill: parent
                        anchors.leftMargin: -Theme.spacingM
                        width: parent.width + Theme.spacingM
                        stateColor: Theme.primary
                        cornerRadius: parent.radius
                        onClicked: root.findRequested()
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: -Theme.spacingM
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "search"
                            size: Theme.iconSize - 2
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Find in Text")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Open search bar to find text")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: visible ? (fontDropdown.height + Theme.spacingS) : 0
                    color: "transparent"
                    visible: !SettingsData.notepadUseMonospace

                    DankDropdown {
                        id: fontDropdown
                        anchors.left: parent.left
                        anchors.leftMargin: -Theme.spacingM
                        width: parent.width + Theme.spacingM
                        text: I18n.tr("Font Family")
                        options: cachedFontFamilies
                        currentValue: {
                            if (!SettingsData.notepadFontFamily || SettingsData.notepadFontFamily === "")
                                return I18n.tr("Default (Global)");
                            else
                                return SettingsData.notepadFontFamily;
                        }
                        enableFuzzySearch: true
                        onValueChanged: value => {
                            if (value && (value.startsWith("Default") || value === "Default (Global)")) {
                                SettingsData.notepadFontFamily = "";
                            } else {
                                SettingsData.notepadFontFamily = value;
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: fontSizeRow.height + Theme.spacingS
                    color: "transparent"

                    Row {
                        id: fontSizeRow
                        width: parent.width
                        spacing: Theme.spacingS

                        Column {
                            width: parent.width - fontSizeControls.width - Theme.spacingM
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Font Size")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: SettingsData.notepadFontSize + "px"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                            }
                        }

                        Row {
                            id: fontSizeControls
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 32
                                iconName: "remove"
                                iconSize: Theme.iconSizeSmall
                                enabled: SettingsData.notepadFontSize > 8
                                backgroundColor: Theme.withAlpha(Theme.surfaceVariant, 0.5)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newSize = Math.max(8, SettingsData.notepadFontSize - 1);
                                    SettingsData.notepadFontSize = newSize;
                                }
                            }

                            Rectangle {
                                width: 60
                                height: 32
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceVariant, 0.3)
                                border.color: Theme.outlineHeavy
                                border.width: 1

                                StyledText {
                                    anchors.centerIn: parent
                                    text: SettingsData.notepadFontSize + "px"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }

                            DankActionButton {
                                buttonSize: 32
                                iconName: "add"
                                iconSize: Theme.iconSizeSmall
                                enabled: SettingsData.notepadFontSize < 48
                                backgroundColor: Theme.withAlpha(Theme.surfaceVariant, 0.5)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newSize = Math.min(48, SettingsData.notepadFontSize + 1);
                                    SettingsData.notepadFontSize = newSize;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: transparencySliderColumn.height + Theme.spacingS
                    color: "transparent"

                    Column {
                        id: transparencySliderColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        DankToggle {
                            anchors.left: parent.left
                            anchors.leftMargin: -Theme.spacingM
                            width: parent.width + Theme.spacingM
                            text: I18n.tr("Surface Opacity")
                            description: I18n.tr("Override global transparency for Notepad")
                            checked: SettingsData.notepadTransparencyOverride >= 0
                            onToggled: checked => {
                                if (checked) {
                                    SettingsData.notepadTransparencyOverride = SettingsData.notepadLastCustomTransparency;
                                } else {
                                    SettingsData.notepadTransparencyOverride = -1;
                                }
                            }
                        }

                        DankSlider {
                            anchors.left: parent.left
                            anchors.leftMargin: -Theme.spacingM
                            width: parent.width + Theme.spacingM
                            height: 24
                            visible: SettingsData.notepadTransparencyOverride >= 0
                            value: Math.round((SettingsData.notepadTransparencyOverride >= 0 ? SettingsData.notepadTransparencyOverride : SettingsData.popupTransparency) * 100)
                            minimum: 0
                            maximum: 100
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            onSliderValueChanged: newValue => {
                                if (SettingsData.notepadTransparencyOverride >= 0) {
                                    SettingsData.notepadTransparencyOverride = newValue / 100;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: gapColumn.height + Theme.spacingS
                    color: "transparent"

                    Column {
                        id: gapColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Default Mode")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            DankButtonGroup {
                                model: [I18n.tr("Slideout"), I18n.tr("Popout")]
                                size: "small"
                                currentIndex: SettingsData.notepadDefaultMode === "popout" ? 1 : 0
                                onSelectionChanged: (index, selected) => {
                                    if (!selected)
                                        return;
                                    SettingsData.notepadDefaultMode = index === 1 ? "popout" : "slideout";
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS
                            visible: SettingsData.notepadDefaultMode !== "popout"

                            StyledText {
                                text: I18n.tr("Open From")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            DankButtonGroup {
                                model: [I18n.tr("Right"), I18n.tr("Left")]
                                size: "small"
                                currentIndex: SettingsData.notepadSlideoutSide === "left" ? 1 : 0
                                onSelectionChanged: (index, selected) => {
                                    if (!selected)
                                        return;
                                    SettingsData.notepadSlideoutSide = index === 1 ? "left" : "right";
                                }
                            }
                        }

                        DankToggle {
                            anchors.left: parent.left
                            anchors.leftMargin: -Theme.spacingM
                            width: parent.width + Theme.spacingM
                            text: I18n.tr("Auto Compositor Gaps")
                            description: I18n.tr("Inset the Notepad from screen edges using the compositor's configured gaps")
                            checked: SettingsData.notepadUseCompositorGap
                            onToggled: checked => {
                                SettingsData.notepadUseCompositorGap = checked;
                            }
                        }

                        StyledText {
                            visible: !SettingsData.notepadUseCompositorGap
                            text: I18n.tr("Manual Gaps")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        DankSlider {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingXS
                            width: parent.width - Theme.spacingXS * 2
                            height: 24
                            visible: !SettingsData.notepadUseCompositorGap
                            value: SettingsData.notepadEdgeGap
                            minimum: 0
                            maximum: 64
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            onSliderValueChanged: newValue => {
                                SettingsData.notepadEdgeGap = newValue;
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: SettingsData.notepadUseMonospace ? I18n.tr("Using global monospace font from Settings → Personalization") : I18n.tr("Global fonts can be configured in Settings → Personalization")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                    wrapMode: Text.WordWrap
                    opacity: 0.8
                }

                StyledRect {
                    width: parent.width
                    implicitHeight: shortcutsHeader.height + (root.shortcutsExpanded ? shortcutsColumn.implicitHeight + Theme.spacingM : 0)
                    radius: Theme.cornerRadius
                    color: root.shortcutsExpanded ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : Theme.withAlpha(Theme.surfaceContainer, 0)
                    border.color: root.shortcutsExpanded ? Theme.primary : Theme.outlineMedium
                    border.width: root.shortcutsExpanded ? 2 : 1

                    StateLayer {
                        anchors.fill: parent
                        stateColor: Theme.primary
                        cornerRadius: parent.radius
                        onClicked: root.shortcutsExpanded = !root.shortcutsExpanded
                    }

                    Row {
                        id: shortcutsHeader
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingS
                        height: 36
                        spacing: Theme.spacingS

                        DankIcon {
                            name: root.shortcutsExpanded ? "expand_less" : "expand_more"
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Keyboard Shortcuts")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        id: shortcutsColumn
                        visible: root.shortcutsExpanded
                        width: parent.width - Theme.spacingL * 2
                        anchors.top: shortcutsHeader.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        StyledText {
                            width: parent.width
                            text: I18n.tr("Ctrl+S: Save • Ctrl+O: Open • Ctrl+N: New • Ctrl+F: Find")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        StyledText {
                            width: parent.width
                            text: I18n.tr("Ctrl+A: Select All • Ctrl+P: Preview • Enter/Shift+Enter: Find Next/Previous • Esc: Close")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
