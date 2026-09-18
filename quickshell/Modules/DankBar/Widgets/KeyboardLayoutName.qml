import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import "../../../DankCommon/Common/LayoutCodes.js" as LayoutCodes

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: SettingsData.widgetOption("keyboard_layout_name", widgetData, "keyboardLayoutNameCompactMode")
    property bool showIcon: SettingsData.widgetOption("keyboard_layout_name", widgetData, "keyboardLayoutNameShowIcon")
    readonly property var validVariants: ["US", "UK", "GB", "AZERTY", "QWERTY", "Dvorak", "Colemak", "Mac", "Intl", "International"]
    readonly property bool codesOnly: KeyboardLayoutService.namesAreXkbCodes
    readonly property string currentLayout: compactMode ? KeyboardLayoutService.compactLayout : KeyboardLayoutService.currentLayout
    readonly property var _allLayoutLabels: (compactMode || !codesOnly ? KeyboardLayoutService.layoutNames : []).map(n => displayLabel(n))
    readonly property string reserveLabel: widestLabel(_allLayoutLabels)
    readonly property string verticalReserveLabel: widestLabel(_allLayoutLabels.map(n => LayoutCodes.layoutCode(n)))

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
        if (!layoutName)
            return "";
        if (!compactMode || codesOnly)
            return layoutName;
        const match = layoutName.match(/^(\S+)(?:.*\(([^)]+)\))?/);
        if (!match)
            return LayoutCodes.layoutCode(layoutName);
        const lang = match[1].toLowerCase();
        const code = LayoutCodes.LANG_CODES[lang] || lang.substring(0, 2);
        if (!match[2])
            return code.toUpperCase();
        const variant = match[2].trim();
        const isValid = validVariants.some(v => variant.toUpperCase().includes(v.toUpperCase())) || variant.length <= 3;
        return isValid ? code + "-" + variant : code.toUpperCase();
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
                    text: LayoutCodes.layoutCode(root.currentLayout)
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
