import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool canAdd: true
    property bool hasWidgets: true
    property string title: I18n.tr("Widgets", "noun, title of widget edit controls and settings card")
    readonly property var focusTargets: [addButton, moreButton, finishButton]

    signal addRequested(var anchor)
    signal menuRequested(var anchor)
    signal finished

    height: Theme.buttonHeightS

    StyledText {
        anchors.left: parent.left
        anchors.right: actions.left
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
        horizontalAlignment: Text.AlignLeft
        elide: Text.ElideRight
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        DankButton {
            id: addButton
            anchors.verticalCenter: parent.verticalCenter
            buttonHeight: Theme.buttonHeightS
            iconName: "add"
            text: I18n.tr("Add widget")
            backgroundColor: Theme.secondaryContainer
            textColor: Theme.onSecondaryContainer
            visible: root.hasWidgets
            enabled: root.canAdd
            KeyNavigation.tab: moreButton
            KeyNavigation.backtab: finishButton
            onClicked: root.addRequested(addButton)
        }

        DankActionButton {
            id: moreButton
            anchors.verticalCenter: parent.verticalCenter
            buttonSize: Theme.buttonHeightS
            iconName: "more_vert"
            Accessible.name: I18n.tr("Options")
            KeyNavigation.tab: finishButton
            KeyNavigation.backtab: addButton
            onClicked: root.menuRequested(moreButton)
        }

        DankButton {
            id: finishButton
            anchors.verticalCenter: parent.verticalCenter
            buttonHeight: Theme.buttonHeightS
            iconName: "check"
            text: I18n.tr("Finish")
            backgroundColor: Theme.primary
            textColor: Theme.onPrimary
            KeyNavigation.tab: addButton
            KeyNavigation.backtab: moreButton
            onClicked: root.finished()
        }
    }
}
