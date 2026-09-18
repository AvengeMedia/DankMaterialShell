import QtQuick
import qs.Common
import qs.Widgets

WidgetPickerWindow {
    id: root

    property string targetSection: ""
    readonly property bool blurActive: Theme.blurLayersActive
    readonly property bool floatingForegroundLayers: Theme.floatingWindowForegroundLayers
    readonly property bool transparentBlurLayers: Theme.blurLayersActive && !floatingForegroundLayers
    readonly property real rowAlpha: blurActive ? Math.min(Theme.floatingWindowTransparency, transparentBlurLayers ? 0.12 : 0.52) : 0.30

    signal widgetSelected(string widgetId, string targetSection)

    function translateSection(section) {
        switch (section.toLowerCase()) {
        case "left":
            return I18n.tr("Left section");
        case "center":
            return I18n.tr("Center section");
        case "right":
            return I18n.tr("Right section");
        default:
            return section;
        }
    }

    objectName: "widgetSelectionPopup"
    title: I18n.tr("Add widget")
    headerTitle: I18n.tr("Add widget to %1", "widget picker header, %1 is the bar section name").arg(translateSection(targetSection))
    intro: I18n.tr("Select a widget to add. You can add multiple instances of the same widget if needed.")
    widgetDelegate: rowDelegate

    onWidgetChosen: widget => {
        widgetSelected(widget.id, targetSection);
        hide();
    }

    onVisibleChanged: {
        if (visible)
            return;
        widgets = [];
        targetSection = "";
    }

    Component {
        id: rowDelegate

        Rectangle {
            width: ListView.view.width
            height: Math.max(60, textColumn.implicitHeight + 24)
            radius: Theme.cornerRadius
            property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex
            color: isSelected ? Theme.withAlpha(Theme.primary, root.blurActive ? 0.22 : 0.16) : widgetArea.containsMouse ? Theme.withAlpha(Theme.primary, root.blurActive ? 0.14 : 0.08) : Theme.floatingWindowNestedSurface
            border.color: isSelected ? Theme.primary : Theme.outlineMedium
            border.width: isSelected ? Theme.outlineWidthFocused : Theme.layerOutlineWidth
            antialiasing: true

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                DankIcon {
                    name: modelData.icon
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    id: textColumn
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS
                    width: parent.width - Theme.iconSize * 2 - Theme.spacingM * 4 + 4

                    StyledText {
                        text: modelData.text
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        text: modelData.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outline
                        elide: Text.ElideRight
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }

                DankIcon {
                    name: "add"
                    size: Theme.iconSizeMedium
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: widgetArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.widgetChosen(modelData)
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }
}
