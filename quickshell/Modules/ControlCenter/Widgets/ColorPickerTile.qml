import QtQuick
import qs.Common
import Quickshell
import qs.Widgets
import qs.DankCommon.Widgets as CommonWidgets

CcTile {
    id: root
    iconName: "palette"
    title: I18n.tr("Color Picker")
    subtitle: I18n.tr("Choose color", "color picker title")
    opensPage: true

    onClicked: host?.colorPickerRequested()
    expandedContent: Component {
        Column {
            id: colors
            readonly property int swatchColumns: Math.max(0, Math.floor((width + Theme.spacingS) / (Theme.minimumTouchTargetSize + Theme.spacingS)))
            readonly property int swatchRows: Math.max(0, Math.floor((height - heading.height) / (Theme.minimumTouchTargetSize + Theme.spacingS)))
            spacing: Theme.spacingS

            StyledText {
                id: heading
                width: parent.width
                text: I18n.tr("Recent Colors")
                color: root.subtitleColor
                font.pixelSize: Theme.fontSizeMedium
                elide: Text.ElideRight
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: SessionData.recentColors.slice(0, colors.swatchColumns * colors.swatchRows)

                    CommonWidgets.DankColorButton {
                        required property var modelData
                        width: Theme.minimumTouchTargetSize
                        height: width
                        swatchColor: modelData
                        Accessible.role: Accessible.Button
                        Accessible.checkable: false
                        Accessible.onPressAction: {
                            if (enabled)
                                click();
                        }
                        Accessible.name: I18n.tr("Copy") + " " + modelData
                        onClicked: Quickshell.clipboardText = modelData
                    }
                }
            }

            DankButton {
                text: I18n.tr("Choose color", "color picker title")
                maximumWidth: parent.width
                visible: SessionData.recentColors.length === 0
                onClicked: root.host?.colorPickerRequested()
            }
        }
    }
}
