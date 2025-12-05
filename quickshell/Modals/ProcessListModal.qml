import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

FloatingWindow {
    id: processListModal

    property int currentTab: 0
    property var tabNames: ["Processes", "Performance", "System"]
    property bool shouldHaveFocus: visible
    property alias shouldBeVisible: processListModal.visible

    signal closingModal

    function show() {
        if (!DgopService.dgopAvailable) {
            console.warn("ProcessListModal: dgop is not available");
            return;
        }
        visible = true;
    }

    function hide() {
        visible = false;
        if (processContextMenu.visible) {
            processContextMenu.close();
        }
    }

    function toggle() {
        if (!DgopService.dgopAvailable) {
            console.warn("ProcessListModal: dgop is not available");
            return;
        }
        visible = !visible;
    }

    function focusOrToggle() {
        if (!DgopService.dgopAvailable) {
            console.warn("ProcessListModal: dgop is not available");
            return;
        }
        if (visible) {
            const modalTitle = I18n.tr("System Monitor", "sysmon window title");
            for (const toplevel of ToplevelManager.toplevels.values) {
                if (toplevel.title !== "System Monitor" && toplevel.title !== modalTitle)
                    continue;
                if (toplevel.activated) {
                    hide();
                    return;
                }
                toplevel.activate();
                return;
            }
        }
        show();
    }

    objectName: "processListModal"
    title: I18n.tr("System Monitor", "sysmon window title")
    minimumSize: Qt.size(650, 400)
    implicitWidth: 900
    implicitHeight: 680
    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    visible: false

    onVisibleChanged: {
        if (!visible) {
            closingModal();
        } else {
            Qt.callLater(() => {
                if (contentFocusScope) {
                    contentFocusScope.forceActiveFocus();
                }
            });
        }
    }

    Component {
        id: processesTabComponent

        ProcessesTab {
            contextMenu: processContextMenu
        }
    }

    Component {
        id: performanceTabComponent

        PerformanceTab {}
    }

    Component {
        id: systemTabComponent

        SystemTab {}
    }

    ProcessContextMenu {
        id: processContextMenu
    }

    FocusScope {
        id: contentFocusScope

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                hide();
                event.accepted = true;
                return;
            }

            switch (event.key) {
            case Qt.Key_1:
                currentTab = 0;
                event.accepted = true;
                return;
            case Qt.Key_2:
                currentTab = 1;
                event.accepted = true;
                return;
            case Qt.Key_3:
                currentTab = 2;
                event.accepted = true;
                return;
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 400
            height: 200
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)
            border.color: Theme.error
            border.width: 2
            visible: !DgopService.dgopAvailable

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingL

                DankIcon {
                    name: "error"
                    size: 48
                    color: Theme.error
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("System Monitor Unavailable")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.error
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("The 'dgop' tool is required for system monitoring.\nPlease install dgop to use this feature.")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingL
            visible: DgopService.dgopAvailable

            RowLayout {
                Layout.fillWidth: true
                height: 40

                StyledText {
                    text: I18n.tr("System Monitor")
                    font.pixelSize: Theme.fontSizeLarge + 4
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                DankActionButton {
                    circular: false
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: () => {
                        processListModal.hide();
                    }
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 52
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                radius: Theme.cornerRadius
                border.color: Theme.outlineLight
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    Repeater {
                        model: tabNames

                        Rectangle {
                            width: (parent.width - (tabNames.length - 1) * 2) / tabNames.length
                            height: 44
                            radius: Theme.cornerRadius
                            color: currentTab === index ? Theme.primaryPressed : (tabMouseArea.containsMouse ? Theme.primaryHoverLight : "transparent")
                            border.color: currentTab === index ? Theme.primary : "transparent"
                            border.width: currentTab === index ? 1 : 0

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: {
                                        const tabIcons = ["list_alt", "analytics", "settings"];
                                        return tabIcons[index] || "tab";
                                    }
                                    size: Theme.iconSize - 2
                                    color: currentTab === index ? Theme.primary : Theme.surfaceText
                                    opacity: currentTab === index ? 1 : 0.7
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                        }
                                    }
                                }

                                StyledText {
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: currentTab === index ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: () => {
                                    currentTab = index;
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                }
                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Theme.outlineLight
                border.width: 1

                Loader {
                    id: processesTab

                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    active: processListModal.visible && currentTab === 0
                    visible: currentTab === 0
                    opacity: currentTab === 0 ? 1 : 0
                    sourceComponent: processesTabComponent

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }

                Loader {
                    id: performanceTab

                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    active: processListModal.visible && currentTab === 1
                    visible: currentTab === 1
                    opacity: currentTab === 1 ? 1 : 0
                    sourceComponent: performanceTabComponent

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }

                Loader {
                    id: systemTab

                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    active: processListModal.visible && currentTab === 2
                    visible: currentTab === 2
                    opacity: currentTab === 2 ? 1 : 0
                    sourceComponent: systemTabComponent

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }
            }
        }
    }
}
