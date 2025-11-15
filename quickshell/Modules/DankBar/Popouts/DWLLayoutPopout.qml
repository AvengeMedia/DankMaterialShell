import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:layout"

    property var triggerScreen: null

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
        updateOutputState()
    }

    function updateOutputState() {
        if (triggerScreen && DwlService.dwlAvailable) {
            outputState = DwlService.getOutputState(triggerScreen.name)
        } else {
            outputState = null
        }
    }

    property var outputState: null
    property string currentLayoutSymbol: outputState?.layoutSymbol || ""

    readonly property var layoutNames: ({
        "CT": I18n.tr("Center Tiling"),
        "G": I18n.tr("Grid"),
        "K": I18n.tr("Deck"),
        "M": I18n.tr("Monocle"),
        "RT": I18n.tr("Right Tiling"),
        "S": I18n.tr("Scrolling"),
        "T": I18n.tr("Tiling"),
        "VG": I18n.tr("Vertical Grid"),
        "VK": I18n.tr("Vertical Deck"),
        "VS": I18n.tr("Vertical Scrolling"),
        "VT": I18n.tr("Vertical Tiling")
    })

    readonly property var layoutIcons: ({
        "CT": "view_compact",
        "G": "grid_view",
        "K": "layers",
        "M": "fullscreen",
        "RT": "view_sidebar",
        "S": "view_carousel",
        "T": "view_quilt",
        "VG": "grid_on",
        "VK": "view_day",
        "VS": "scrollable_header",
        "VT": "clarify"
    })

    function getLayoutName(symbol) {
        return layoutNames[symbol] || symbol
    }

    function getLayoutIcon(symbol) {
        return layoutIcons[symbol] || "view_quilt"
    }

    Connections {
        target: DwlService
        function onStateChanged() {
            updateOutputState()
        }
    }

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            updateOutputState()
        }
    }

    Component.onCompleted: {
        updateOutputState()
    }

    popupWidth: 300
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 550
    triggerX: Screen.width - 380 - Theme.spacingL
    triggerY: Theme.barHeight - 4 + SettingsData.dankBarSpacing
    triggerWidth: 70
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false

    content: Component {
        Rectangle {
            id: layoutContent

            implicitHeight: contentColumn.implicitHeight + Theme.spacingL * 2
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: Theme.outlineMedium
            border.width: 0
            antialiasing: true
            smooth: true
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    forceActiveFocus()
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(() => {
                            layoutContent.forceActiveFocus()
                        })
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Theme.outlineStrong
                border.width: 0
                radius: parent.radius
                z: -1
            }

            Column {
                id: contentColumn

                width: parent.width - Theme.spacingL * 2
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    height: 40
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "view_quilt"
                        size: Theme.iconSizeLarge
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSizeLarge - 32 - Theme.spacingM * 2

                        StyledText {
                            text: I18n.tr("Layout")
                            font.pixelSize: Theme.fontSizeXLarge
                            color: Theme.surfaceText
                            font.weight: Font.Bold
                        }

                        StyledText {
                            text: root.currentLayoutSymbol
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: closeLayoutArea.containsMouse ? Theme.errorHover : "transparent"
                        anchors.top: parent.top

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: Theme.iconSize - 4
                            color: closeLayoutArea.containsMouse ? Theme.error : Theme.surfaceText
                        }

                        MouseArea {
                            id: closeLayoutArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                root.close()
                            }
                        }
                    }
                }

                StyledText {
                    text: I18n.tr("Available Layouts")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                    font.weight: Font.Medium
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: DwlService.layouts

                        delegate: Rectangle {
                            required property string modelData
                            required property int index

                            property bool isActive: modelData === root.currentLayoutSymbol

                            width: parent.width
                            height: 40
                            radius: Theme.cornerRadius
                            color: layoutArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: root.getLayoutIcon(modelData)
                                    size: 20
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: root.getLayoutName(modelData)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: parent.parent.parent.isActive ? Theme.primary : Theme.surfaceText
                                        font.weight: parent.parent.parent.isActive ? Font.Medium : Font.Normal
                                    }

                                    StyledText {
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceTextMedium
                                    }
                                }
                            }

                            MouseArea {
                                id: layoutArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    console.log("DWLLayoutPopout: Pressed layout", modelData, "at index", index)
                                    console.log("DWLLayoutPopout: triggerScreen:", root.triggerScreen, "dwlAvailable:", DwlService.dwlAvailable)

                                    if (!root.triggerScreen) {
                                        console.error("DWLLayoutPopout: triggerScreen is null!")
                                        return
                                    }
                                    if (!DwlService.dwlAvailable) {
                                        console.error("DWLLayoutPopout: DwlService not available!")
                                        return
                                    }

                                    console.log("DWLLayoutPopout: CALLING setLayout with output:", root.triggerScreen.name, "index:", index)
                                    DwlService.setLayout(root.triggerScreen.name, index)
                                    root.close()
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }

                StyledText {
                    text: I18n.tr("Right-click bar widget to cycle")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.outline
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
