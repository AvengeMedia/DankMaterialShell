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

    property bool disablePopupTransparency: true
    property int currentTab: 0
    property string searchText: ""
    property string expandedPid: ""
    property string processFilter: "all"
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
        if (processContextMenu.visible)
            processContextMenu.close();
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

    function formatBytes(bytes) {
        if (bytes < 1024)
            return bytes.toFixed(0) + " B/s";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KB/s";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MB/s";
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB/s";
    }

    function nextTab() {
        currentTab = (currentTab + 1) % 4;
    }

    function previousTab() {
        currentTab = (currentTab - 1 + 4) % 4;
    }

    objectName: "processListModal"
    title: I18n.tr("System Monitor", "sysmon window title")
    minimumSize: Qt.size(Math.min(Math.round(Theme.fontSizeMedium * 48), Screen.width), Math.min(Math.round(Theme.fontSizeMedium * 34), Screen.height))
    implicitWidth: Math.round(Theme.fontSizeMedium * 71)
    implicitHeight: Math.round(Theme.fontSizeMedium * 51)
    color: Theme.surfaceContainer
    visible: false

    onCurrentTabChanged: {
        if (visible && currentTab === 0 && searchField.visible)
            searchField.forceActiveFocus();
    }

    onVisibleChanged: {
        if (!visible) {
            closingModal();
            searchText = "";
            expandedPid = "";
            processFilter = "all";
            processFilterGroup.currentIndex = 0;
            if (processesTabLoader.item)
                processesTabLoader.item.reset();
            DgopService.removeRef(["cpu", "memory", "network", "disk", "system"]);
        } else {
            DgopService.addRef(["cpu", "memory", "network", "disk", "system"]);
            Qt.callLater(() => {
                if (currentTab === 0 && searchField.visible)
                    searchField.forceActiveFocus();
                else if (contentFocusScope)
                    contentFocusScope.forceActiveFocus();
            });
        }
    }

    ProcessContextMenu {
        id: processContextMenu
        parentFocusItem: contentFocusScope
        onProcessKilled: {
            if (processesTabLoader.item)
                processesTabLoader.item.forceRefresh(3);
        }
    }

    FocusScope {
        id: contentFocusScope

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (processContextMenu.visible)
                return;

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
            case Qt.Key_4:
                currentTab = 3;
                event.accepted = true;
                return;
            case Qt.Key_Tab:
                nextTab();
                event.accepted = true;
                return;
            case Qt.Key_Backtab:
                previousTab();
                event.accepted = true;
                return;
            case Qt.Key_Escape:
                if (searchText.length > 0) {
                    searchText = "";
                    event.accepted = true;
                    return;
                }
                if (currentTab === 0 && processesTabLoader.item?.keyboardNavigationActive) {
                    processesTabLoader.item.reset();
                    event.accepted = true;
                    return;
                }
                hide();
                event.accepted = true;
                return;
            case Qt.Key_F:
                if (event.modifiers & Qt.ControlModifier) {
                    searchField.forceActiveFocus();
                    event.accepted = true;
                    return;
                }
                break;
            }

            if (currentTab === 0 && processesTabLoader.item)
                processesTabLoader.item.handleKey(event);
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
                    text: I18n.tr("The 'dgop' tool is required for system monitoring.\nPlease install dgop to use this feature.", "dgop unavailable error message")
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
            spacing: 0
            visible: DgopService.dgopAvailable

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Theme.fontSizeMedium * 3.4)

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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Theme.fontSizeMedium * 3.7)
                Layout.leftMargin: Theme.spacingL
                Layout.rightMargin: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    spacing: 2

                    Repeater {
                        model: [
                            {
                                text: I18n.tr("Processes"),
                                icon: "list_alt"
                            },
                            {
                                text: I18n.tr("Performance"),
                                icon: "analytics"
                            },
                            {
                                text: I18n.tr("Disks"),
                                icon: "storage"
                            },
                            {
                                text: I18n.tr("System"),
                                icon: "computer"
                            }
                        ]

                        Rectangle {
                            width: tabRowContent.implicitWidth + Theme.spacingM * 2
                            height: Math.round(Theme.fontSizeMedium * 3.1)
                            radius: Theme.cornerRadius
                            color: currentTab === index ? Theme.primaryPressed : (tabMouseArea.containsMouse ? Theme.primaryHoverLight : "transparent")
                            border.color: currentTab === index ? Theme.primary : "transparent"
                            border.width: currentTab === index ? 1 : 0

                            Row {
                                id: tabRowContent
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: modelData.icon
                                    size: Theme.iconSize - 2
                                    color: currentTab === index ? Theme.primary : Theme.surfaceText
                                    opacity: currentTab === index ? 1 : 0.7
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.text
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: currentTab === index ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: tabMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: currentTab = index
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                DankButtonGroup {
                    id: processFilterGroup
                    model: [I18n.tr("All"), I18n.tr("User"), I18n.tr("System")]
                    currentIndex: 0
                    checkEnabled: false
                    buttonHeight: Math.round(Theme.fontSizeSmall * 2.6)
                    minButtonWidth: 0
                    buttonPadding: Theme.spacingS
                    textSize: Theme.fontSizeSmall
                    visible: currentTab === 0
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        currentIndex = index;
                        switch (index) {
                        case 0:
                            processListModal.processFilter = "all";
                            return;
                        case 1:
                            processListModal.processFilter = "user";
                            return;
                        case 2:
                            processListModal.processFilter = "system";
                            return;
                        }
                    }
                }

                DankTextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.round(Theme.fontSizeMedium * 18)
                    Layout.minimumWidth: Theme.fontSizeMedium * 4
                    Layout.preferredHeight: Math.round(Theme.fontSizeMedium * 2.8)
                    placeholderText: I18n.tr("Search processes...", "process search placeholder")
                    leftIconName: "search"
                    showClearButton: true
                    text: searchText
                    visible: currentTab === 0
                    onTextChanged: searchText = text
                    ignoreUpDownKeys: true
                    keyForwardTargets: [contentFocusScope]
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Theme.spacingL
                Layout.topMargin: Theme.spacingM
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Theme.outlineLight
                border.width: 1
                clip: true

                Loader {
                    id: processesTabLoader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    active: processListModal.visible && currentTab === 0
                    visible: currentTab === 0
                    sourceComponent: ProcessesView {
                        searchText: processListModal.searchText
                        expandedPid: processListModal.expandedPid
                        processFilter: processListModal.processFilter
                        contextMenu: processContextMenu
                        onExpandedPidChanged: processListModal.expandedPid = expandedPid
                    }
                }

                Loader {
                    id: performanceTabLoader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    active: processListModal.visible && currentTab === 1
                    visible: currentTab === 1
                    sourceComponent: PerformanceView {}
                }

                Loader {
                    id: disksTabLoader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    active: processListModal.visible && currentTab === 2
                    visible: currentTab === 2
                    sourceComponent: DisksView {}
                }

                Loader {
                    id: systemTabLoader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    active: processListModal.visible && currentTab === 3
                    visible: currentTab === 3
                    sourceComponent: SystemView {}
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Theme.fontSizeSmall * 2.7)
                Layout.leftMargin: Theme.spacingL
                Layout.rightMargin: Theme.spacingL
                Layout.bottomMargin: Theme.spacingM
                color: "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingL

                    Row {
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Processes:", "process count label in footer")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: DgopService.processCount.toString()
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }
                    }

                    Row {
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Uptime:", "uptime label in footer")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: DgopService.shortUptime || "--"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingL

                    Row {
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "swap_horiz"
                            size: 14
                            color: Theme.info
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "↓" + formatBytes(DgopService.networkRxRate) + " ↑" + formatBytes(DgopService.networkTxRate)
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            color: Theme.surfaceText
                        }
                    }

                    Row {
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "storage"
                            size: 14
                            color: Theme.warning
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "↓" + formatBytes(DgopService.diskReadRate) + " ↑" + formatBytes(DgopService.diskWriteRate)
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            color: Theme.surfaceText
                        }
                    }

                    Row {
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "memory"
                            size: 14
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: DgopService.cpuUsage.toFixed(1) + "%"
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: DgopService.cpuUsage > 80 ? Theme.error : Theme.surfaceText
                        }
                    }

                    Row {
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "sd_card"
                            size: 14
                            color: Theme.secondary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB)
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: DgopService.memoryUsage > 90 ? Theme.error : Theme.surfaceText
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
