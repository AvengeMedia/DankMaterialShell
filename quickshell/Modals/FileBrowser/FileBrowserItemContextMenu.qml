import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Popup {
    id: root

    property string filePath: ""
    property string fileName: ""
    property bool fileIsDir: false
    property var parentFocusItem: null

    signal trashed
    signal menuClosed

    readonly property var menuItems: [
        {
            text: I18n.tr("Move to Trash"),
            icon: "delete",
            action: trashItem,
            enabled: filePath.length > 0,
            dangerous: true
        },
        {
            text: I18n.tr("Copy Path"),
            icon: "content_copy",
            action: copyPath,
            enabled: filePath.length > 0
        }
    ]

    function showAt(parentItem, localX, localY, path, name, isDir) {
        if (!parentItem)
            return;
        parent = parentItem;
        filePath = path || "";
        fileName = name || "";
        fileIsDir = !!isDir;
        x = Math.max(0, Math.min(parentItem.width - width, localX));
        y = Math.max(0, Math.min(parentItem.height - height, localY));
        open();
    }

    function trashItem() {
        if (!filePath)
            return;
        TrashService.trashPath(filePath, ok => {
            if (ok)
                root.trashed();
        });
        close();
    }

    function copyPath() {
        if (!filePath)
            return;
        Quickshell.execDetached(["dms", "cl", "copy", filePath]);
        close();
    }

    width: 220
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    padding: 0
    modal: false
    closePolicy: Popup.CloseOnEscape

    onClosed: {
        closePolicy = Popup.CloseOnEscape;
        menuClosed();
        if (parentFocusItem)
            Qt.callLater(() => parentFocusItem.forceActiveFocus());
    }

    onOpened: outsideClickTimer.start()

    Timer {
        id: outsideClickTimer
        interval: 100
        onTriggered: root.closePolicy = Popup.CloseOnEscape | Popup.CloseOnPressOutside
    }

    background: Rectangle {
        color: "transparent"
    }

    contentItem: Rectangle {
        color: Theme.floatingSurface
        radius: Theme.cornerRadius
        border.color: BlurService.enabled ? BlurService.borderColor : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: BlurService.enabled ? BlurService.borderWidth : 1

        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: 1

            Repeater {
                model: root.menuItems

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    opacity: modelData.enabled ? 1 : 0.5
                    color: {
                        if (!modelData.enabled || !area.containsMouse)
                            return "transparent";
                        if (modelData.dangerous)
                            return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12);
                        return BlurService.hoverColor(Theme.widgetBaseHoverColor);
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.icon
                            size: 16
                            color: modelData.dangerous && area.containsMouse && modelData.enabled ? Theme.error : Theme.surfaceText
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            font.pixelSize: Theme.fontSizeSmall
                            color: modelData.dangerous && area.containsMouse && modelData.enabled ? Theme.error : Theme.surfaceText
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.action()
                    }
                }
            }
        }
    }
}
