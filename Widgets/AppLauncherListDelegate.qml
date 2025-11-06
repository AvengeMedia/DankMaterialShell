import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    required property var model
    required property int index
    required property var listView
    property int itemHeight: 60
    property int iconSize: 40
    property bool showDescription: true
    property bool hoverUpdatesSelection: true
    property bool keyboardNavigationActive: false
    property bool isCurrentItem: false
    property bool isPlugin: model?.isPlugin || false
    property real mouseAreaLeftMargin: 0
    property real mouseAreaRightMargin: 0
    property real mouseAreaBottomMargin: 0
    property real iconMargins: 0
    property real iconFallbackLeftMargin: 0
    property real iconFallbackRightMargin: 0
    property real iconFallbackBottomMargin: 0
    property real iconMaterialSizeAdjustment: Theme.spacingM
    property real iconUnicodeScale: 0.7

    signal itemClicked(int index, var modelData)
    signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)
    signal keyboardNavigationReset()

    width: listView.width
    height: itemHeight
    radius: Theme.cornerRadius
    color: isCurrentItem ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : mouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingL

        AppIconRenderer {
            width: root.iconSize
            height: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
            iconValue: model.icon && model.icon !== "" ? model.icon : model.startupClass
            iconSize: root.iconSize
            fallbackText: (model.name && model.name.length > 0) ? model.name.charAt(0).toUpperCase() : "A"
            iconMargins: root.iconMargins
            fallbackLeftMargin: root.iconFallbackLeftMargin
            fallbackRightMargin: root.iconFallbackRightMargin
            fallbackBottomMargin: root.iconFallbackBottomMargin
            materialIconSizeAdjustment: root.iconMaterialSizeAdjustment
            unicodeIconScale: root.iconUnicodeScale
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: (model.icon !== undefined && model.icon !== "") ? (parent.width - root.iconSize - Theme.spacingL) : parent.width
            spacing: Theme.spacingXS

            StyledText {
                width: parent.width
                text: model.name || ""
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                maximumLineCount: 1
            }

            StyledText {
                width: parent.width
                text: model.comment || "Application"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: root.showDescription && model.comment && model.comment.length > 0
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        anchors.leftMargin: root.mouseAreaLeftMargin
        anchors.rightMargin: root.mouseAreaRightMargin
        anchors.bottomMargin: root.mouseAreaBottomMargin
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 10
        onEntered: {
            if (root.hoverUpdatesSelection && !root.keyboardNavigationActive)
                root.listView.currentIndex = root.index
        }
        onPositionChanged: {
            root.keyboardNavigationReset()
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.itemClicked(root.index, root.model)
            } else if (mouse.button === Qt.RightButton && !root.isPlugin) {
                const globalPos = mapToItem(null, mouse.x, mouse.y)
                root.itemRightClicked(root.index, root.model, globalPos.x, globalPos.y)
            }
        }
    }
}
