import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:hyprkeybinds"

    width: 1400
    height: 900
    onBackgroundClicked: close()

    function categorizeKeybinds() {
        const categories = {
            "Workspace": [],
            "Window": [],
            "Monitor": [],
            "Execute": [],
            "System": [],
            "Other": []
        }

        function addKeybind(keybind) {
            const dispatcher = keybind.dispatcher || ""
            if (dispatcher.includes("workspace")) {
                categories["Workspace"].push(keybind)
            } else if (dispatcher.includes("monitor")) {
                categories["Monitor"].push(keybind)
            } else if (dispatcher.includes("window") || dispatcher.includes("focus") || dispatcher.includes("move") || dispatcher.includes("swap") || dispatcher.includes("resize") || dispatcher === "killactive" || dispatcher === "fullscreen" || dispatcher === "togglefloating") {
                categories["Window"].push(keybind)
            } else if (dispatcher === "exec") {
                categories["Execute"].push(keybind)
            } else if (dispatcher === "exit" || dispatcher.includes("dpms")) {
                categories["System"].push(keybind)
            } else {
                categories["Other"].push(keybind)
            }
        }

        const allKeybinds = HyprKeybindsService.keybinds.keybinds || []
        for (let i = 0; i < allKeybinds.length; i++) {
            addKeybind(allKeybinds[i])
        }

        const children = HyprKeybindsService.keybinds.children || []
        for (let i = 0; i < children.length; i++) {
            const child = children[i]
            const childKeybinds = child.keybinds || []
            for (let j = 0; j < childKeybinds.length; j++) {
                addKeybind(childKeybinds[j])
            }
        }

        categories["Workspace"].sort((a, b) => {
            const dispA = a.dispatcher || ""
            const dispB = b.dispatcher || ""
            return dispA.localeCompare(dispB)
        })

        categories["Window"].sort((a, b) => {
            const dispA = a.dispatcher || ""
            const dispB = b.dispatcher || ""
            return dispA.localeCompare(dispB)
        })

        categories["Monitor"].sort((a, b) => {
            const dispA = a.dispatcher || ""
            const dispB = b.dispatcher || ""
            return dispA.localeCompare(dispB)
        })

        categories["Execute"].sort((a, b) => {
            const modsA = a.mods || []
            const keyA = a.key || ""
            const bindA = [...modsA, keyA].join("+")

            const modsB = b.mods || []
            const keyB = b.key || ""
            const bindB = [...modsB, keyB].join("+")

            return bindA.localeCompare(bindB)
        })

        return categories
    }

    content: Component {
        Item {
            anchors.fill: parent

            DankFlickable {
                id: mainFlickable
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                contentWidth: rowLayout.implicitWidth
                contentHeight: rowLayout.implicitHeight
                clip: true

                Row {
                    id: rowLayout
                    spacing: Theme.spacingM

                    property var categories: root.categorizeKeybinds()
                    property real columnWidth: (mainFlickable.width - spacing * 2) / 3

                    Column {
                        width: rowLayout.columnWidth
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Window / Monitor"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.primary
                            opacity: 0.3
                        }

                        Item { width: 1; height: Theme.spacingXS }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: [...(rowLayout.categories["Window"] || []), ...(rowLayout.categories["Monitor"] || [])]

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledRect {
                                        width: Math.min(140, parent.width * 0.42)
                                        height: 22
                                        radius: 4
                                        opacity: 0.3

                                        StyledText {
                                            anchors.centerIn: parent
                                            anchors.margins: 2
                                            width: parent.width - 4
                                            text: {
                                                const mods = modelData.mods || []
                                                const key = modelData.key || ""
                                                const parts = [...mods, key]
                                                return parts.join("+")
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            isMonospace: true
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    StyledText {
                                        width: parent.width - 150
                                        text: {
                                            const comment = modelData.comment || ""
                                            if (comment) return comment

                                            const dispatcher = modelData.dispatcher || ""
                                            const params = modelData.params || ""
                                            return params ? `${dispatcher} ${params}` : dispatcher
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        opacity: 0.9
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: ["Workspace", "Execute"]

                        Column {
                            width: rowLayout.columnWidth
                            spacing: Theme.spacingXS

                            StyledText {
                                text: modelData
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.primary
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.primary
                                opacity: 0.3
                            }

                            Item { width: 1; height: Theme.spacingXS }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingXS

                                Repeater {
                                    model: rowLayout.categories[modelData] || []

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        StyledRect {
                                            width: Math.min(140, parent.width * 0.42)
                                            height: 22
                                            radius: 4
                                            opacity: 0.3

                                            StyledText {
                                                anchors.centerIn: parent
                                                anchors.margins: 2
                                                width: parent.width - 4
                                                text: {
                                                    const mods = modelData.mods || []
                                                    const key = modelData.key || ""
                                                    const parts = [...mods, key]
                                                    return parts.join("+")
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                isMonospace: true
                                                elide: Text.ElideRight
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }

                                        StyledText {
                                            width: parent.width - 150
                                            text: {
                                                const comment = modelData.comment || ""
                                                if (comment) return comment

                                                const dispatcher = modelData.dispatcher || ""
                                                const params = modelData.params || ""
                                                return params ? `${dispatcher} ${params}` : dispatcher
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            opacity: 0.9
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
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
