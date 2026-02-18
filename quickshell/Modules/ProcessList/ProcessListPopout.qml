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
    property string processFilter: "all"

    function hide() {
        close();
        if (processContextMenu.visible)
            processContextMenu.close();
    }

    function show() {
        open();
    }

    popupWidth: Math.round(Theme.fontSizeMedium * 46)
    popupHeight: Math.round(Theme.fontSizeMedium * 39)
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false

    onBackgroundClicked: {
        if (processContextMenu.visible)
            processContextMenu.close();
        close();
    }

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible) {
            searchText = "";
            expandedPid = "";
            processFilter = "all";
        }
    }

    Ref {
        service: DgopService
    }

    ProcessContextMenu {
        id: processContextMenu
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
                if (processContextMenu.visible)
                    return;

                switch (event.key) {
                case Qt.Key_Escape:
                    if (processListPopout.searchText.length > 0) {
                        processListPopout.searchText = "";
                        event.accepted = true;
                        return;
                    }
                    if (processesView.keyboardNavigationActive) {
                        processesView.reset();
                        event.accepted = true;
                        return;
                    }
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

            Connections {
                target: processListPopout
                function onShouldBeVisibleChanged() {
                    if (processListPopout.shouldBeVisible) {
                        Qt.callLater(() => searchField.forceActiveFocus());
                    } else {
                        processesView.reset();
                        processFilterGroup.currentIndex = 0;
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    Row {
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "analytics"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Processes")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    DankButtonGroup {
                        id: processFilterGroup
                        Layout.minimumWidth: implicitWidth
                        model: [I18n.tr("All"), I18n.tr("User"), I18n.tr("System")]
                        currentIndex: 0
                        checkEnabled: false
                        buttonHeight: Math.round(Theme.fontSizeSmall * 2.4)
                        minButtonWidth: 0
                        buttonPadding: Theme.spacingM
                        textSize: Theme.fontSizeSmall
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            currentIndex = index;
                            switch (index) {
                            case 0:
                                processListPopout.processFilter = "all";
                                return;
                            case 1:
                                processListPopout.processFilter = "user";
                                return;
                            case 2:
                                processListPopout.processFilter = "system";
                                return;
                            }
                        }
                    }

                    DankTextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.minimumWidth: Theme.fontSizeMedium * 8
                        Layout.preferredHeight: Theme.fontSizeMedium * 2.5
                        placeholderText: I18n.tr("Search...")
                        leftIconName: "search"
                        showClearButton: true
                        text: processListPopout.searchText
                        onTextChanged: processListPopout.searchText = text
                        ignoreUpDownKeys: true
                        keyForwardTargets: [processListContent]
                    }
                }

                Item {
                    id: statsContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(leftInfo.height, gaugesRow.height) + Theme.spacingS

                    function compactMem(kb) {
                        if (kb < 1024 * 1024) {
                            const mb = kb / 1024;
                            return mb >= 100 ? mb.toFixed(0) + " MB" : mb.toFixed(1) + " MB";
                        }
                        const gb = kb / (1024 * 1024);
                        return gb >= 10 ? gb.toFixed(0) + " GB" : gb.toFixed(1) + " GB";
                    }

                    readonly property real gaugeSize: Theme.fontSizeMedium * 6.5

                    readonly property var enabledGpusWithTemp: {
                        if (!SessionData.enabledGpuPciIds || SessionData.enabledGpuPciIds.length === 0)
                            return [];
                        const result = [];
                        for (const gpu of DgopService.availableGpus) {
                            if (SessionData.enabledGpuPciIds.indexOf(gpu.pciId) !== -1 && gpu.temperature > 0)
                                result.push(gpu);
                        }
                        return result;
                    }
                    readonly property bool hasGpu: enabledGpusWithTemp.length > 0

                    Row {
                        id: leftInfo
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        Rectangle {
                            width: Theme.fontSizeMedium * 3
                            height: width
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)

                            SystemLogo {
                                anchors.centerIn: parent
                                width: parent.width * 0.7
                                height: width
                                colorOverride: Theme.primary
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS / 2

                            StyledText {
                                text: DgopService.hostname || "localhost"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: DgopService.distribution || "Linux"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Row {
                                spacing: Theme.spacingS

                                Row {
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "schedule"
                                        size: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: DgopService.shortUptime || "--"
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }
                                }

                                StyledText {
                                    text: "•"
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: DgopService.processCount + " " + I18n.tr("procs", "short for processes")
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }
                    }

                    Row {
                        id: gaugesRow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        CircleGauge {
                            width: statsContainer.gaugeSize
                            height: statsContainer.gaugeSize
                            value: DgopService.cpuUsage / 100
                            label: DgopService.cpuUsage.toFixed(0) + "%"
                            sublabel: "CPU"
                            detail: DgopService.cpuTemperature > 0 ? (DgopService.cpuTemperature.toFixed(0) + "°") : ""
                            accentColor: DgopService.cpuUsage > 80 ? Theme.error : (DgopService.cpuUsage > 50 ? Theme.warning : Theme.primary)
                            detailColor: DgopService.cpuTemperature > 85 ? Theme.error : (DgopService.cpuTemperature > 70 ? Theme.warning : Theme.surfaceVariantText)
                        }

                        CircleGauge {
                            width: statsContainer.gaugeSize
                            height: statsContainer.gaugeSize
                            value: DgopService.memoryUsage / 100
                            label: statsContainer.compactMem(DgopService.usedMemoryKB)
                            sublabel: I18n.tr("Memory")
                            detail: DgopService.totalSwapKB > 0 ? ("+" + statsContainer.compactMem(DgopService.usedSwapKB)) : ""
                            accentColor: DgopService.memoryUsage > 90 ? Theme.error : (DgopService.memoryUsage > 70 ? Theme.warning : Theme.secondary)
                        }

                        CircleGauge {
                            width: statsContainer.gaugeSize
                            height: statsContainer.gaugeSize
                            visible: statsContainer.hasGpu

                            readonly property var gpu: statsContainer.enabledGpusWithTemp[0] ?? null
                            readonly property color vendorColor: {
                                const vendor = (gpu?.vendor ?? "").toLowerCase();
                                if (vendor.includes("nvidia"))
                                    return Theme.success;
                                if (vendor.includes("amd"))
                                    return Theme.error;
                                if (vendor.includes("intel"))
                                    return Theme.info;
                                return Theme.info;
                            }

                            value: Math.min(1, (gpu?.temperature ?? 0) / 100)
                            label: (gpu?.temperature ?? 0) > 0 ? ((gpu?.temperature ?? 0).toFixed(0) + "°C") : "--"
                            sublabel: "GPU"
                            accentColor: {
                                const temp = gpu?.temperature ?? 0;
                                if (temp > 85)
                                    return Theme.error;
                                if (temp > 70)
                                    return Theme.warning;
                                return vendorColor;
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    clip: true

                    ProcessesView {
                        id: processesView
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        searchText: processListPopout.searchText
                        expandedPid: processListPopout.expandedPid
                        processFilter: processListPopout.processFilter
                        contextMenu: processContextMenu
                        onExpandedPidChanged: processListPopout.expandedPid = expandedPid
                    }
                }
            }
        }
    }

    component CircleGauge: Item {
        id: gaugeRoot

        property real value: 0
        property string label: ""
        property string sublabel: ""
        property string detail: ""
        property color accentColor: Theme.primary
        property color detailColor: Theme.surfaceVariantText

        readonly property real thickness: Math.max(4, Math.min(width, height) / 15)
        readonly property real glowExtra: thickness * 1.4
        readonly property real arcPadding: (thickness + glowExtra) / 2

        readonly property real innerDiameter: width - (arcPadding + thickness + glowExtra) * 2
        readonly property real maxTextWidth: innerDiameter * 0.9
        readonly property real baseLabelSize: Math.round(width * 0.18)
        readonly property real labelSize: Math.round(Math.min(baseLabelSize, maxTextWidth / Math.max(1, label.length * 0.65)))
        readonly property real sublabelSize: Math.round(Math.min(width * 0.13, maxTextWidth / Math.max(1, sublabel.length * 0.7)))
        readonly property real detailSize: Math.round(Math.min(width * 0.12, maxTextWidth / Math.max(1, detail.length * 0.65)))

        property real animValue: 0

        onValueChanged: animValue = Math.min(1, Math.max(0, value))

        Behavior on animValue {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Easing.OutCubic
            }
        }

        Component.onCompleted: animValue = Math.min(1, Math.max(0, value))

        Canvas {
            id: glowCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2;
                const cy = height / 2;
                const radius = (Math.min(width, height) / 2) - gaugeRoot.arcPadding;
                const startAngle = -Math.PI * 0.5;
                const endAngle = Math.PI * 1.5;

                ctx.lineCap = "round";

                if (gaugeRoot.animValue > 0) {
                    const prog = startAngle + (endAngle - startAngle) * gaugeRoot.animValue;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, startAngle, prog);
                    ctx.strokeStyle = Qt.rgba(gaugeRoot.accentColor.r, gaugeRoot.accentColor.g, gaugeRoot.accentColor.b, 0.2);
                    ctx.lineWidth = gaugeRoot.thickness + gaugeRoot.glowExtra;
                    ctx.stroke();
                }
            }

            Connections {
                target: gaugeRoot
                function onAnimValueChanged() {
                    glowCanvas.requestPaint();
                }
                function onAccentColorChanged() {
                    glowCanvas.requestPaint();
                }
                function onWidthChanged() {
                    glowCanvas.requestPaint();
                }
                function onHeightChanged() {
                    glowCanvas.requestPaint();
                }
            }

            Component.onCompleted: requestPaint()
        }

        Canvas {
            id: arcCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2;
                const cy = height / 2;
                const radius = (Math.min(width, height) / 2) - gaugeRoot.arcPadding;
                const startAngle = -Math.PI * 0.5;
                const endAngle = Math.PI * 1.5;

                ctx.lineCap = "round";

                ctx.beginPath();
                ctx.arc(cx, cy, radius, startAngle, endAngle);
                ctx.strokeStyle = Qt.rgba(gaugeRoot.accentColor.r, gaugeRoot.accentColor.g, gaugeRoot.accentColor.b, 0.1);
                ctx.lineWidth = gaugeRoot.thickness;
                ctx.stroke();

                if (gaugeRoot.animValue > 0) {
                    const prog = startAngle + (endAngle - startAngle) * gaugeRoot.animValue;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, startAngle, prog);
                    ctx.strokeStyle = gaugeRoot.accentColor;
                    ctx.lineWidth = gaugeRoot.thickness;
                    ctx.stroke();
                }
            }

            Connections {
                target: gaugeRoot
                function onAnimValueChanged() {
                    arcCanvas.requestPaint();
                }
                function onAccentColorChanged() {
                    arcCanvas.requestPaint();
                }
                function onWidthChanged() {
                    arcCanvas.requestPaint();
                }
                function onHeightChanged() {
                    arcCanvas.requestPaint();
                }
            }

            Component.onCompleted: requestPaint()
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            StyledText {
                text: gaugeRoot.label
                font.pixelSize: gaugeRoot.labelSize
                font.family: SettingsData.monoFontFamily
                font.weight: Font.Bold
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: gaugeRoot.sublabel
                font.pixelSize: gaugeRoot.sublabelSize
                font.weight: Font.Medium
                color: gaugeRoot.accentColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: gaugeRoot.detail
                font.pixelSize: gaugeRoot.detailSize
                font.family: SettingsData.monoFontFamily
                color: gaugeRoot.detailColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: gaugeRoot.detail.length > 0
            }
        }
    }
}
