pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Flow {
    id: root

    property var options: []
    property string currentValue: ""
    property bool compact: false
    property real maxHeight: 0
    property real minTileWidth: compact ? Theme.minimumTouchTargetSize + Theme.spacingM : SettingsMetrics.swatchTileMinWidth
    signal selected(string value)

    readonly property int columns: Math.max(1, Math.floor((width + spacing) / (minTileWidth + spacing)))
    readonly property real tileWidth: Math.floor((width - spacing * (columns - 1)) / columns)
    readonly property real compactTileHeight: Theme.minimumTouchTargetSize + Theme.spacingS * 2
    readonly property int maxRows: maxHeight > 0 && compact ? Math.max(1, Math.floor((maxHeight + spacing) / (compactTileHeight + spacing))) : 0
    readonly property var shownOptions: maxRows > 0 ? options.slice(0, columns * maxRows) : options

    width: parent?.width ?? 0
    spacing: Theme.spacingS

    Repeater {
        model: root.shownOptions

        Rectangle {
            id: tile
            required property var modelData

            readonly property bool isActive: root.currentValue === modelData.value

            width: root.tileWidth
            height: root.compact ? root.compactTileHeight : swatch.height + label.implicitHeight + Theme.spacingS * 3
            radius: Theme.cornerRadiusM
            color: Theme.floatingWindowNestedSurface
            border.width: isActive ? Theme.outlineWidthFocused : Theme.outlineWidth
            border.color: isActive ? Theme.primary : Theme.outlineMedium

            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData.label
            Accessible.checked: isActive
            Accessible.onPressAction: root.selected(modelData.value)
            Keys.onSpacePressed: root.selected(modelData.value)
            Keys.onReturnPressed: root.selected(modelData.value)

            FocusRing {}

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.primary
                opacity: tileMouse.containsMouse ? Theme.stateLayerHover : 0
            }

            DankPaletteSwatch {
                id: swatch
                width: Theme.minimumTouchTargetSize
                height: Theme.minimumTouchTargetSize
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                primaryColor: tile.modelData.primary
                secondaryColor: tile.modelData.secondary ?? tile.modelData.primary
                tertiaryColor: tile.modelData.tertiary ?? tile.modelData.secondary ?? tile.modelData.primary
            }

            DankTooltipHost {
                text: root.compact ? tile.modelData.label : null
                target: tile
                hoverArea: tileMouse
            }

            StyledText {
                id: label
                visible: !root.compact
                anchors.top: swatch.bottom
                anchors.topMargin: Theme.spacingS
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingXS
                anchors.rightMargin: Theme.spacingXS
                text: tile.modelData.label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: tile.isActive ? Theme.fontWeightMedium : Theme.fontWeight
                color: tile.isActive ? Theme.primary : Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(tile.modelData.value)
            }
        }
    }
}
