import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: widgetData?.keyboardLayoutNameCompactMode !== undefined ? widgetData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode
    readonly property var langCodes: ({
        "afrikaans": "af", "albanian": "sq", "amharic": "am", "arabic": "ar",
        "armenian": "hy", "azerbaijani": "az", "basque": "eu", "belarusian": "be",
        "bengali": "bn", "bosnian": "bs", "bulgarian": "bg", "burmese": "my",
        "catalan": "ca", "chinese": "zh", "croatian": "hr", "czech": "cs",
        "danish": "da", "dutch": "nl", "english": "en", "esperanto": "eo",
        "estonian": "et", "filipino": "fil", "finnish": "fi", "french": "fr",
        "galician": "gl", "georgian": "ka", "german": "de", "greek": "el",
        "gujarati": "gu", "hausa": "ha", "hebrew": "he", "hindi": "hi",
        "hungarian": "hu", "icelandic": "is", "igbo": "ig", "indonesian": "id",
        "irish": "ga", "italian": "it", "japanese": "ja", "javanese": "jv",
        "kannada": "kn", "kazakh": "kk", "khmer": "km", "korean": "ko",
        "kurdish": "ku", "kyrgyz": "ky", "lao": "lo", "latvian": "lv",
        "lithuanian": "lt", "luxembourgish": "lb", "macedonian": "mk", "malay": "ms",
        "malayalam": "ml", "maltese": "mt", "maori": "mi", "marathi": "mr",
        "mongolian": "mn", "nepali": "ne", "norwegian": "no", "pashto": "ps",
        "persian": "fa", "iranian": "fa", "farsi": "fa", "polish": "pl",
        "portuguese": "pt", "punjabi": "pa", "romanian": "ro", "russian": "ru",
        "serbian": "sr", "sindhi": "sd", "sinhala": "si", "slovak": "sk",
        "slovenian": "sl", "somali": "so", "spanish": "es", "swahili": "sw",
        "swedish": "sv", "tajik": "tg", "tamil": "ta", "tatar": "tt",
        "telugu": "te", "thai": "th", "tibetan": "bo", "turkish": "tr",
        "turkmen": "tk", "ukrainian": "uk", "urdu": "ur", "uyghur": "ug",
        "uzbek": "uz", "vietnamese": "vi", "welsh": "cy", "yiddish": "yi",
        "yoruba": "yo", "zulu": "zu"
    })
    readonly property var validVariants: ["US", "UK", "GB", "AZERTY", "QWERTY", "Dvorak", "Colemak", "Mac", "Intl", "International"]
    property string currentLayout: {
        if (CompositorService.isNiri) {
            return NiriService.getCurrentKeyboardLayoutName();
        } else if (CompositorService.isDwl) {
            return DwlService.currentKeyboardLayout;
        }
        return "";
    }
    property string hyprlandKeyboard: ""

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : contentRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? contentColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: contentColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "keyboard"
                    size: Theme.barIconSize(root.barThickness)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (!root.currentLayout)
                            return "";
                        const lang = root.currentLayout.split(" ")[0].toLowerCase();
                        const code = root.langCodes[lang] || lang.substring(0, 2);
                        return code.toUpperCase();
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: contentRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingS

                StyledText {
                    text: {
                        if (!root.currentLayout)
                            return "";
                        if (root.compactMode && !CompositorService.isHyprland) {
                            const match = root.currentLayout.match(/^(\S+)(?:.*\(([^)]+)\))?/);
                            if (match) {
                                const lang = match[1].toLowerCase();
                                const code = root.langCodes[lang] || lang.substring(0, 2);
                                if (match[2]) {
                                    const variant = match[2].trim();
                                    const isValid = root.validVariants.some(v => variant.toUpperCase().includes(v.toUpperCase())) || variant.length <= 3;
                                    if (isValid)
                                        return code + "-" + variant;
                                }
                                return code.toUpperCase();
                            }
                            return root.currentLayout.substring(0, 2).toUpperCase();
                        }
                        return root.currentLayout;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    MouseArea {
        z: 1
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (CompositorService.isNiri) {
                NiriService.cycleKeyboardLayout();
            } else if (CompositorService.isHyprland) {
                Quickshell.execDetached(["hyprctl", "switchxkblayout", root.hyprlandKeyboard, "next"]);
            } else if (CompositorService.isDwl) {
                Quickshell.execDetached(["mmsg", "-d", "switch_keyboard_layout"]);
            }
        }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        enabled: CompositorService.isHyprland

        function onRawEvent(event) {
            if (event.name === "activelayout") {
                updateLayout();
            }
        }
    }

    Component.onCompleted: {
        if (CompositorService.isHyprland) {
            updateLayout();
        }
    }

    function updateLayout() {
        if (CompositorService.isHyprland) {
            Proc.runCommand(null, ["hyprctl", "-j", "devices"], (output, exitCode) => {
                if (exitCode !== 0) {
                    root.currentLayout = "Unknown";
                    return;
                }
                try {
                    const data = JSON.parse(output);
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true);
                    root.hyprlandKeyboard = mainKeyboard.name;

                    if (mainKeyboard) {
                        const layout = mainKeyboard.layout;
                        const variant = mainKeyboard.variant;
                        const index = mainKeyboard.active_layout_index;

                        if (root.compactMode && layout && variant && index !== undefined) {
                            const layouts = mainKeyboard.layout.split(",");
                            const variants = mainKeyboard.variant.split(",");
                            const index = mainKeyboard.active_layout_index;

                            if (layouts[index] && variants[index] !== undefined) {
                                if (variants[index] === "") {
                                    root.currentLayout = layouts[index];
                                } else {
                                    root.currentLayout = layouts[index] + "-" + variants[index];
                                }
                            } else {
                                root.currentLayout = "Unknown";
                            }
                        } else if (mainKeyboard && mainKeyboard.active_keymap) {
                            root.currentLayout = mainKeyboard.active_keymap;
                        } else {
                            root.currentLayout = "Unknown";
                        }
                    } else {
                        root.currentLayout = "Unknown";
                    }
                } catch (e) {
                    root.currentLayout = "Unknown";
                }
            });
        }
    }
}
