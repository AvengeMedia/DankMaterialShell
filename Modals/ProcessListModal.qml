import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modals.Common
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

DankModal {
    id: processListModal

    layerNamespace: "dms:process-list-modal"

    property int currentTab: 0
    property var tabNames: ["Processes", "Performance", "System"]

    function show() {
        if (!DgopService.dgopAvailable) {
            console.warn("ProcessListModal: dgop is not available");
            return ;
        }
        open();
        UserInfoService.getUptime();
    }

    function hide() {
        close();
        if (processContextMenu.visible) {
            processContextMenu.close();
        }

    }

    function toggle() {
        if (!DgopService.dgopAvailable) {
            console.warn("ProcessListModal: dgop is not available");
            return ;
        }
        if (shouldBeVisible) {
            hide();
        } else {
            show();
        }
    }

    width: 900
    height: 680
    visible: false
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    enableShadow: true
    onBackgroundClicked: () => {
        return hide();
    }

    Component {
        id: processesTabComponent

        ProcessesTab {
            contextMenu: processContextMenu
        }

    }

    Component {
        id: performanceTabComponent

        PerformanceTab {
        }

    }

    Component {
        id: systemTabComponent

        SystemTab {
        }

    }

    ProcessContextMenu {
        id: processContextMenu
    }

    content: Component {
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    processListModal.hide();
                    event.accepted = true;
                } else if (event.key === Qt.Key_1) {
                    currentTab = 0;
                    event.accepted = true;
                } else if (event.key === Qt.Key_2) {
                    currentTab = 1;
                    event.accepted = true;
                } else if (event.key === Qt.Key_3) {
                    currentTab = 2;
                    event.accepted = true;
                }
            }

            // Show error message when dgop is not available
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
                            return processListModal.hide();
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

}
