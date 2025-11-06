import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

DankPopout {
    id: processListPopout

    layerNamespace: "dms:process-list-popout"

    property var parentWidget: null
    property var triggerScreen: null

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x;
        triggerY = y;
        triggerWidth = width;
        triggerSection = section;
        triggerScreen = screen;
    }

    function hide() {
        close();
        if (processContextMenu.visible) {
            processContextMenu.close();
        }
    }

    function show() {
        open();
    }

    popupWidth: 600
    popupHeight: 600
    triggerX: Screen.width - 600 - Theme.spacingL
    triggerY: Math.max(26 + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding)) + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap - 2
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    visible: shouldBeVisible
    shouldBeVisible: false

    Ref {
        service: DgopService
    }

    ProcessContextMenu {
        id: processContextMenu
    }

    content: Component {
        Rectangle {
            id: processListContent

            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
            clip: true
            antialiasing: true
            smooth: true
            focus: true
            Component.onCompleted: {
                if (processListPopout.shouldBeVisible) {
                    forceActiveFocus();
                }
            }
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    processListPopout.close();
                    event.accepted = true;
                }
            }

            Connections {
                function onShouldBeVisibleChanged() {
                    if (processListPopout.shouldBeVisible) {
                        Qt.callLater(() => {
                            processListContent.forceActiveFocus();
                        });
                    }
                }

                target: processListPopout
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL

                Rectangle {
                    Layout.fillWidth: true
                    height: systemOverview.height + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: 0

                    SystemOverview {
                        id: systemOverview

                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2
                    }

                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
                    border.width: 0

                    ProcessListView {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        contextMenu: processContextMenu
                    }

                }

            }

        }

    }

}
