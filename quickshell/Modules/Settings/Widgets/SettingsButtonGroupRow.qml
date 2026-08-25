pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../../Common/QmlUtils.js" as QmlUtils

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string tab: ""
    property var tags: []
    property string settingKey: ""

    property string text: ""
    property string description: ""

    readonly property bool isHighlighted: settingKey !== "" && SettingsSearchService.highlightSection === settingKey

    Component.onCompleted: {
        if (!settingKey)
            return;
        var key = settingKey;
        Qt.callLater(() => {
            if (!root.parent)
                return;
            var flickable = QmlUtils.findParentFlickable(root.parent);
            if (flickable)
                SettingsSearchService.registerCard(key, root, flickable);
        });
    }

    Component.onDestruction: {
        if (settingKey)
            SettingsSearchService.unregisterCard(settingKey);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.primary, root.isHighlighted ? 0.2 : 0)
        visible: root.isHighlighted

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    property alias model: buttonGroup.model
    property alias currentIndex: buttonGroup.currentIndex
    property alias initialSelection: buttonGroup.initialSelection
    property alias currentSelection: buttonGroup.currentSelection
    property alias selectionMode: buttonGroup.selectionMode
    property alias buttonHeight: buttonGroup.buttonHeight
    property alias minButtonWidth: buttonGroup.minButtonWidth
    property alias buttonPadding: buttonGroup.buttonPadding
    property alias checkIconSize: buttonGroup.checkIconSize
    property alias textSize: buttonGroup.textSize
    property alias spacing: buttonGroup.spacing
    property alias checkEnabled: buttonGroup.checkEnabled

    signal selectionChanged(int index, bool selected)

    // Stack label/description above a centered button group when the text
    // column would be crushed by the buttons; sit side-by-side otherwise.
    readonly property bool compact: width - buttonGroup.width - Theme.spacingM * 3 < 200

    width: parent?.width ?? 0
    height: {
        if (compact)
            return textColumn.implicitHeight + Theme.spacingS + buttonGroup.height + Theme.spacingM * 2;
        return Math.max(60, Math.max(textColumn.implicitHeight, buttonGroup.height) + Theme.spacingM * 2);
    }

    Column {
        id: textColumn
        x: Theme.spacingM
        y: root.compact ? Theme.spacingM : (root.height - height) / 2
        width: root.compact ? root.width - Theme.spacingM * 2 : root.width - buttonGroup.width - Theme.spacingM * 3
        spacing: Theme.spacingXS

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            elide: Text.ElideRight
            width: parent.width
            visible: root.text !== ""
            horizontalAlignment: Text.AlignLeft
        }

        StyledText {
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width
            visible: root.description !== ""
            horizontalAlignment: Text.AlignLeft
        }
    }

    DankButtonGroup {
        id: buttonGroup
        x: root.compact ? (root.width - width) / 2 : root.width - width - Theme.spacingM
        y: root.compact ? textColumn.y + textColumn.implicitHeight + Theme.spacingS : (root.height - height) / 2
        selectionMode: "single"
        onSelectionChanged: (index, selected) => root.selectionChanged(index, selected)
    }
}
