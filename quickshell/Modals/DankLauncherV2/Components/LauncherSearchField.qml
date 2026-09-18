import QtQuick
import qs.Common
import qs.Widgets

DankSearchField {
    id: root

    property var categories: []
    property int categoryIndex: 0
    property bool showCategories: true
    property string pluginName: ""
    signal categorySelected(int index)

    function revealCategory() {
        const chip = chips.children.find(child => child.index === root.categoryIndex);
        if (!chip)
            return;
        const left = chip.x;
        const right = left + chip.width;
        const maxX = Math.max(0, categoryViewport.contentWidth - categoryViewport.width);
        if (left < categoryViewport.contentX) {
            categoryViewport.contentX = Math.max(0, left);
            return;
        }
        if (right > categoryViewport.contentX + categoryViewport.width)
            categoryViewport.contentX = Math.min(maxX, right - categoryViewport.width);
    }

    onCategoryIndexChanged: revealTimer.restart()

    Timer {
        id: revealTimer
        interval: 0
        onTriggered: root.revealCategory()
    }

    height: LauncherMetrics.pillHeight
    textColor: Theme.onSurface
    font.pixelSize: Theme.fontSizeLarge
    leadingContent: pluginName ? pluginBadge : null
    rightAccessoryWidth: categoryViewport.visible ? categoryViewport.width + Theme.spacingS : 0

    Component {
        id: pluginBadge

        Rectangle {
            implicitWidth: pluginLabel.implicitWidth + Theme.chipIconSize + Theme.spacingS + Theme.spacingM * 2
            width: Math.min(implicitWidth, Math.max(0, root.width - root.contentPadding - LauncherMetrics.minSearchWidth - root.accessorySize - Theme.spacingS * 3))
            height: Theme.buttonHeightXS
            radius: Theme.fullRadius(width, height)
            color: Theme.primary
            clip: true

            DankIcon {
                id: pluginIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                name: "extension"
                size: Theme.chipIconSize
                color: Theme.onPrimary
            }

            StyledText {
                id: pluginLabel
                anchors.left: pluginIcon.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                text: root.pluginName
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.onPrimary
                wrapMode: Text.NoWrap
                elide: I18n.isRtl ? Text.ElideLeft : Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    DankFlickable {
        id: categoryViewport
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(chips.implicitWidth, Math.max(0, root.width - LauncherMetrics.minSearchWidth - root.leftPadding - root.accessorySize - Theme.spacingS * 3))
        height: Theme.buttonHeightXS
        visible: root.showCategories && root.categories.length > 0 && width > 0
        onWidthChanged: revealTimer.restart()
        contentWidth: chips.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        DankFilterChips {
            id: chips
            width: implicitWidth
            flow: Flow.TopToBottom
            height: chipHeight
            model: root.categories
            Binding on currentIndex {
                value: root.categoryIndex
                restoreMode: Binding.RestoreNone
            }
            showCheck: false
            chipPadding: Theme.spacingS
            activeFocusOnTab: false
            onPositioningComplete: revealTimer.restart()
            onSelectionChanged: index => {
                root.categorySelected(index);
                root.forceActiveFocus();
            }
        }
    }
}
