import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

DankPopout {
    id: processListPopout

    layerNamespace: "dms:process-list-popout"

    property var parentWidget: null
    property var triggerScreen: null
    property string searchText: ""
    property string expandedPid: ""

    function hide() {
        close();
        processContextMenu.dismiss();
    }

    function show() {
        open();
    }

    function prepareForTrigger(triggerSource) {
        switch (triggerSource) {
        case "memory":
            DgopService.setSortBy("memory");
            break;
        case "cpu":
        case "cpu_temp":
        case "gpu_temp":
            DgopService.setSortBy("cpu");
            break;
        }
    }

    popupWidth: Math.round(Theme.fontSizeMedium * 46)
    popupHeight: Math.round(Theme.fontSizeMedium * 43)
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false

    onBackgroundClicked: {
        processContextMenu.dismiss();
        close();
    }

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible) {
            processContextMenu.dismiss();
            searchText = "";
            expandedPid = "";
        }
    }

    ProcessContextMenu {
        id: processContextMenu
        transientSurfaceTracker: processListPopout.transientSurfaceTracker
    }

    content: Component {
        Rectangle {
            id: processListContent

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            radius: Theme.cornerRadius
            color: "transparent"
            clip: true
            focus: true

            Component.onCompleted: {
                if (processListPopout.shouldBeVisible)
                    searchField.forceActiveFocus();
                processContextMenu.parent = processListContent;
                processContextMenu.parentFocusItem = processListContent;
            }

            Keys.onPressed: event => {
                if (processContextMenu.visible || processContextMenu.confirmationOpen)
                    return;

                switch (event.key) {
                case Qt.Key_Escape:
                    processListPopout.close();
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

                processesView.handleKey(event);
            }

            readonly property bool popoutShouldBeVisible: processListPopout.shouldBeVisible

            onPopoutShouldBeVisibleChanged: {
                if (popoutShouldBeVisible) {
                    Qt.callLater(() => searchField.forceActiveFocus());
                } else {
                    processesView.reset();
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: PopoutMetrics.contentPadding
                spacing: PopoutMetrics.contentGap

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    ProcessFilterChips {
                        id: processFilterGroup
                        Layout.preferredWidth: singleRowWidth
                    }

                    DankSearchField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.minimumWidth: Theme.fontSizeMedium * 8
                        Layout.preferredHeight: Theme.buttonHeightS
                        placeholderText: I18n.tr("Search", "search field placeholder") + "…"
                        text: processListPopout.searchText
                        onTextChanged: processListPopout.searchText = text
                        ignoreUpDownKeys: true
                        keyForwardTargets: [processListContent]
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    SystemLogo {
                        Layout.preferredWidth: Theme.iconSize
                        Layout.preferredHeight: Theme.iconSize
                        colorOverride: Theme.primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: (DgopService.hostname || "localhost") + " · " + (DgopService.distribution || "Linux") + " · " + (DgopService.shortUptime || "--") + " · " + DgopService.processCount + " " + I18n.tr("procs", "short for processes")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    Repeater {
                        model: DgopService.availableGpus.filter(gpu => (SessionData.enabledGpuPciIds || []).includes(gpu.pciId) && gpu.temperature > 0)
                        NumericText {
                            required property var modelData
                            text: I18n.tr("GPU") + " " + modelData.temperature.toFixed(0) + "°C"
                            reserveText: I18n.tr("GPU") + " 100°C"
                            font.pixelSize: Theme.fontSizeSmall
                            color: modelData.temperature > 85 ? Theme.error : Theme.onSurfaceVariant
                        }
                    }
                }

                ProcessSummary {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ProcessListMetrics.graphHeight
                    Layout.maximumHeight: ProcessListMetrics.graphHeight
                    Layout.fillHeight: false
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.cornerRadius
                    color: Theme.nestedSurface
                    clip: true

                    ProcessesView {
                        id: processesView
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS

                        active: processListPopout.shouldBeVisible
                        searchText: processListPopout.searchText
                        expandedPid: processListPopout.expandedPid
                        contextMenu: processContextMenu
                        onExpandedPidChanged: processListPopout.expandedPid = expandedPid
                    }
                }
            }
        }
    }
}
