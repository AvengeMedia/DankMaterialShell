import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "emoji-cycler"

    property var enabledEmojis: pluginData.emojis || ["😊", "😢", "❤️"]
    property int cycleInterval: pluginData.cycleInterval || 3000
    property int maxBarEmojis: pluginData.maxBarEmojis || 3

    property int currentIndex: 0
    property var displayedEmojis: []

    Timer {
        interval: root.cycleInterval
        running: true
        repeat: true
        onTriggered: {
            if (root.enabledEmojis.length > 0) {
                root.currentIndex = (root.currentIndex + 1) % root.enabledEmojis.length
                root.updateDisplayedEmojis()
            }
        }
    }

    function updateDisplayedEmojis() {
        const maxToShow = Math.min(root.maxBarEmojis, root.enabledEmojis.length)
        let emojis = []
        for (let i = 0; i < maxToShow; i++) {
            const idx = (root.currentIndex + i) % root.enabledEmojis.length
            emojis.push(root.enabledEmojis[idx])
        }
        root.displayedEmojis = emojis
    }

    Component.onCompleted: {
        updateDisplayedEmojis()
    }

    onEnabledEmojisChanged: updateDisplayedEmojis()
    onMaxBarEmojisChanged: updateDisplayedEmojis()

    horizontalBarPill: Component {
        Row {
            id: emojiRow
            spacing: Theme.spacingXS

            Repeater {
                model: root.displayedEmojis
                StyledText {
                    text: modelData
                    font.pixelSize: Theme.fontSizeLarge
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            id: emojiColumn
            spacing: Theme.spacingXS

            Repeater {
                model: root.displayedEmojis
                StyledText {
                    text: modelData
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn

            headerText: "Emoji Picker"
            detailsText: "Click an emoji to copy it to clipboard"
            showCloseButton: true

            property var allEmojis: [
                "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
                "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙",
                "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔",
                "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬", "🤥",
                "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢", "🤮",
                "🤧", "🥵", "🥶", "😶‍🌫️", "😵", "😵‍💫", "🤯", "🤠", "🥳", "😎",
                "🤓", "🧐", "😕", "😟", "🙁", "☹️", "😮", "😯", "😲", "😳",
                "🥺", "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖",
                "😣", "😞", "😓", "😩", "😫", "🥱", "😤", "😡", "😠", "🤬",
                "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
                "❤️‍🔥", "❤️‍🩹", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟",
                "👍", "👎", "👊", "✊", "🤛", "🤜", "🤞", "✌️", "🤟", "🤘",
                "👌", "🤌", "🤏", "👈", "👉", "👆", "👇", "☝️", "✋", "🤚"
            ]

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutColumn.headerHeight - popoutColumn.detailsHeight - Theme.spacingXL

                DankGridView {
                    id: emojiGrid
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.floor(parent.width / 50) * 50
                    height: parent.height
                    clip: true
                    cellWidth: 50
                    cellHeight: 50
                    model: popoutColumn.allEmojis

                    delegate: StyledRect {
                        width: 45
                        height: 45
                        radius: Theme.cornerRadius
                        color: emojiMouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        border.width: 0

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Theme.fontSizeXLarge
                        }

                        MouseArea {
                            id: emojiMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                Quickshell.execDetached(["sh", "-c", "echo -n '" + modelData + "' | wl-copy"])
                                ToastService.showInfo("Copied " + modelData + " to clipboard")
                                popoutColumn.closePopout()
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 500
}
