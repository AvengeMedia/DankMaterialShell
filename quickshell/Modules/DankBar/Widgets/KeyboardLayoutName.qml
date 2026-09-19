import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import "KeyboardLayoutLabels.js" as KeyboardLayoutLabels

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: SettingsData.widgetOption("keyboard_layout_name", widgetData, "keyboardLayoutNameCompactMode")
    property bool showIcon: SettingsData.widgetOption("keyboard_layout_name", widgetData, "keyboardLayoutNameShowIcon")
    readonly property var labelOverrides: SettingsData.widgetOption("keyboard_layout_name", widgetData, "keyboardLayoutNameLabelOverrides") ?? ({})
    readonly property var validVariants: ["US", "UK", "GB", "AZERTY", "QWERTY", "Dvorak", "Colemak", "Mac", "Intl", "International"]
    readonly property bool codesOnly: KeyboardLayoutService.namesAreXkbCodes
    readonly property string currentLayout: compactMode ? KeyboardLayoutService.compactLayout : KeyboardLayoutService.currentLayout
    readonly property var _allLayoutLabels: (compactMode || !codesOnly ? KeyboardLayoutService.layoutNames : []).map(n => displayLabel(n))
    readonly property string reserveLabel: widestLabel(_allLayoutLabels)
    readonly property var _allVerticalLabels: (compactMode || !codesOnly ? KeyboardLayoutService.layoutNames : []).map(n => verticalLabel(n))
    readonly property string verticalReserveLabel: widestLabel(_allVerticalLabels)

    Component.onCompleted: KeyboardLayoutService.consumers++
    Component.onDestruction: KeyboardLayoutService.consumers--

    function widestLabel(labels) {
        let widest = "";
        for (let i = 0; i < labels.length; i++) {
            if (labels[i].length > widest.length)
                widest = labels[i];
        }
        return widest;
    }

    function displayLabel(layoutName) {
        return KeyboardLayoutLabels.displayLabel(layoutName, compactMode, codesOnly, validVariants, labelOverrides);
    }

    function verticalLabel(layoutName) {
        return KeyboardLayoutLabels.verticalLabel(layoutName, labelOverrides);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? root.contentThickness : contentRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? contentColumn.implicitHeight : root.contentThickness

            Column {
                id: contentColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "keyboard"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: root.contentColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showIcon
                }

                NumericText {
                    isMonospace: false
                    text: root.verticalLabel(root.currentLayout)
                    reserveText: root.verticalReserveLabel
                    width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: root.contentColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: contentRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "keyboard"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: root.contentColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showIcon
                }

                NumericText {
                    isMonospace: false
                    text: root.displayLabel(root.currentLayout)
                    reserveText: root.reserveLabel
                    width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: root.contentColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    MouseArea {
        z: 1
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
        }
        onClicked: KeyboardLayoutService.cycle()
    }
}
