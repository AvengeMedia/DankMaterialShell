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
    color: Theme.surfaceContainer
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

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
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

        Column {
            anchors.fill: parent
            spacing: 0
            visible: DgopService.dgopAvailable

            Item {
                width: parent.width
                height: 48

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "analytics"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("System Monitor")
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankActionButton {
                        visible: windowControls.supported
                        circular: false
                        iconName: processListModal.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        circular: false
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: processListModal.hide()
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 48

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.bottomMargin: Theme.spacingL
                    anchors.topMargin: 0
                    spacing: Theme.spacingL

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

    FloatingWindowControls {
        id: windowControls
        targetWindow: processListModal
    }
}
