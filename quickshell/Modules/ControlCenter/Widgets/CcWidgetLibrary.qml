import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Widgets

Rectangle {
    id: root

    property var widgets: []
    readonly property var matches: {
        const query = searchField.text.trim().toLowerCase();
        if (!query)
            return widgets;
        return widgets.filter(widget => [widget.text, widget.description, widget.id].some(value => (value || "").toLowerCase().includes(query)));
    }

    signal chosen(string widgetId)
    signal dismissed

    function reset() {
        searchField.text = "";
        widgetList.positionViewAtBeginning();
        searchField.forceActiveFocus();
    }

    implicitWidth: CcMetrics.libraryPanelWidth
    implicitHeight: CcMetrics.libraryPanelHeight
    radius: Theme.windowRadius
    color: Theme.nestedSurface

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => mouse.accepted = true
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacingL

        Row {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.spacingM

            DankIcon {
                name: "add_circle"
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: I18n.tr("Add widget")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        DankSearchField {
            id: searchField
            anchors.top: headerRow.bottom
            anchors.topMargin: Theme.spacingM
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.fieldHeightLarge
            textColor: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            placeholderText: I18n.tr("Search widgets...")
            onAccepted: {
                if (root.matches.length > 0)
                    root.chosen(root.matches[0].id);
            }
            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Escape)
                    return;
                root.dismissed();
                event.accepted = true;
            }
        }

        DankListView {
            id: widgetList

            anchors.top: searchField.bottom
            anchors.topMargin: Theme.spacingM
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: Theme.groupedListGap
            clip: true
            model: root.matches

            delegate: CcListRow {
                required property var modelData
                required property int index

                width: widgetList.width
                iconName: modelData.icon
                title: modelData.text
                subtitle: modelData.description ?? ""
                clickable: true
                topRadius: index === 0 ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
                bottomRadius: index === widgetList.count - 1 ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
                onClicked: root.chosen(modelData.id)

                DankIcon {
                    name: "add"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
