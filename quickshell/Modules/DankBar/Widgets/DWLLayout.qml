import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: layout

    property bool layoutPopupVisible: false
    property var popoutTarget: null

    signal toggleLayoutPopup()

    visible: CompositorService.isDwl && DwlService.dwlAvailable

    property var outputState: parentScreen ? DwlService.getOutputState(parentScreen.name) : null
    property string currentLayoutSymbol: outputState?.layoutSymbol || ""
    property int currentLayoutIndex: outputState?.layout || 0

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

    function getLayoutIcon(symbol) {
        return layoutIcons[symbol] || "view_quilt"
    }

    Connections {
        target: DwlService
        function onStateChanged() {
            outputState = parentScreen ? DwlService.getOutputState(parentScreen.name) : null
        }
    }

    content: Component {
        Item {
            implicitWidth: layout.isVerticalOrientation ? (layout.widgetThickness - layout.horizontalPadding * 2) : layoutContent.implicitWidth
            implicitHeight: layout.isVerticalOrientation ? layoutColumn.implicitHeight : (layout.widgetThickness - layout.horizontalPadding * 2)

            Column {
                id: layoutColumn
                visible: layout.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: layout.getLayoutIcon(layout.currentLayoutSymbol)
                    size: Theme.barIconSize(layout.barThickness)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: layout.currentLayoutSymbol
                    font.pixelSize: Theme.barTextSize(layout.barThickness, layout.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: layoutContent
                visible: !layout.isVerticalOrientation
                anchors.centerIn: parent
                spacing: (barConfig?.noBackground ?? false) ? 1 : 2

                DankIcon {
                    name: layout.getLayoutIcon(layout.currentLayoutSymbol)
                    size: Theme.barIconSize(layout.barThickness, -4)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: layout.currentLayoutSymbol
                    font.pixelSize: Theme.barTextSize(layout.barThickness, layout.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    onClicked: {
        toggleLayoutPopup()
    }

    onRightClicked: {
        if (!parentScreen || !DwlService.dwlAvailable || DwlService.layouts.length === 0) {
            return
        }

        const currentIndex = layout.currentLayoutIndex
        const nextIndex = (currentIndex + 1) % DwlService.layouts.length

        DwlService.setLayout(parentScreen.name, nextIndex)
    }
}
