import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    required property var model
    required property int index
    required property var gridView
    property int cellWidth: 120
    property int cellHeight: 120
    property int cellPadding: 8
    property int minIconSize: 32
    property int maxIconSize: 64
    property real iconSizeRatio: 0.5
    property bool hoverUpdatesSelection: true
    property bool keyboardNavigationActive: false
    property int currentIndex: -1
    property bool isPlugin: model?.isPlugin || false
    property real mouseAreaLeftMargin: 0
    property real mouseAreaRightMargin: 0
    property real mouseAreaBottomMargin: 0
    property real iconFallbackLeftMargin: 0
    property real iconFallbackRightMargin: 0
    property real iconFallbackBottomMargin: 0
    property real iconMaterialSizeAdjustment: 0
    property real iconUnicodeScale: 0.8

    signal itemClicked(int index, var modelData)
    signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)
    signal keyboardNavigationReset()

    width: cellWidth - cellPadding
    height: cellHeight - cellPadding
    radius: Theme.cornerRadius
    color: currentIndex === index ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : mouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS

        AppIconRenderer {
            property int computedIconSize: Math.min(root.maxIconSize, Math.max(root.minIconSize, root.cellWidth * root.iconSizeRatio))

            width: computedIconSize
            height: computedIconSize
            anchors.horizontalCenter: parent.horizontalCenter
            iconValue: model.icon || ""
            iconSize: computedIconSize
            fallbackText: (model.name && model.name.length > 0) ? model.name.charAt(0).toUpperCase() : "A"
            materialIconSizeAdjustment: root.iconMaterialSizeAdjustment
            unicodeIconScale: root.iconUnicodeScale
            fallbackTextScale: Math.min(28, computedIconSize * 0.5) / computedIconSize
            iconMargins: 0
            fallbackLeftMargin: root.iconFallbackLeftMargin
            fallbackRightMargin: root.iconFallbackRightMargin
            fallbackBottomMargin: root.iconFallbackBottomMargin
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.cellWidth - 12
            text: model.name || ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            font.weight: Font.Medium
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            wrapMode: Text.NoWrap
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
                root.gridView.currentIndex = root.index
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
