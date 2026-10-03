pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import "../../../DankCommon/Common/MaterialWallpaper.js" as Art

Flow {
    id: root

    property string preset: Art.defaultPreset
    property string seed: Art.defaultSeed
    property real aspectRatio: Art.designWidth / Art.designHeight
    readonly property var options: MaterialWallpaperOptions.presets
    readonly property int columns: Math.max(1, Math.min(options.length, Math.floor(width / SettingsMetrics.previewTileMinWidth)))
    readonly property real tileWidth: (width - spacing * (columns - 1)) / columns
    signal selected(string preset)

    width: parent.width
    spacing: Theme.spacingS

    Repeater {
        model: root.options
        Rectangle {
            id: tile
            required property var modelData
            readonly property bool selected: root.preset === modelData.value
            readonly property var scene: Art.preset(modelData.value, root.seed)
            width: root.tileWidth
            height: preview.height + label.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadiusM
            color: selected ? Theme.selectedContainer : SettingsMetrics.controlColor
            border.width: selected ? Theme.outlineWidthFocused : Theme.layerOutlineWidth
            border.color: selected ? Theme.primary : Theme.outlineMedium
            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData.label
            Accessible.checked: selected
            Accessible.onPressAction: root.selected(modelData.value)
            Keys.onSpacePressed: root.selected(modelData.value)
            Keys.onReturnPressed: root.selected(modelData.value)
            Keys.onEnterPressed: root.selected(modelData.value)

            ClippingRectangle {
                id: preview
                x: Theme.spacingS
                y: Theme.spacingS
                width: parent.width - Theme.spacingS * 2
                height: width / root.aspectRatio
                radius: Theme.cornerRadiusS
                color: Theme.surface
                MaterialWallpaper {
                    anchors.fill: parent
                    composition: tile.scene
                }
            }
            StyledText {
                id: label
                anchors.top: preview.bottom
                anchors.topMargin: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Theme.spacingM * 2
                text: tile.modelData.label
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: tile.selected ? Theme.onSelectedContainer : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
            FocusRing {
                id: ring
            }
            StateLayer {
                anchors.fill: parent
                cornerRadius: tile.radius
                stateColor: Theme.primary
                focused: ring.visible
                onClicked: {
                    ring.pointerFocused = true;
                    tile.forceActiveFocus(Qt.MouseFocusReason);
                    root.selected(tile.modelData.value);
                }
            }
        }
    }
}
