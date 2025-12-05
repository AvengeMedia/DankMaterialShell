pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

Item {
    id: printerTab

    property bool showAddPrinter: false
    property string newPrinterName: ""
    property string selectedDeviceUri: ""
    property var selectedDevice: null
    property string selectedPpd: ""
    property string newPrinterLocation: ""
    property string newPrinterInfo: ""
    property var suggestedPPDs: []

    function resetAddPrinterForm() {
        newPrinterName = "";
        selectedDeviceUri = "";
        selectedDevice = null;
        selectedPpd = "";
        newPrinterLocation = "";
        newPrinterInfo = "";
        suggestedPPDs = [];
    }

    function selectDevice(device) {
        if (!device)
            return;
        selectedDevice = device;
        selectedDeviceUri = device.uri;
        if (!newPrinterName) {
            newPrinterName = CupsService.suggestPrinterName(device);
        }
        if (device.location && !newPrinterLocation) {
            newPrinterLocation = CupsService.decodeUri(device.location);
        }
        suggestedPPDs = CupsService.getMatchingPPDs(device);
        if (suggestedPPDs.length > 0 && !selectedPpd) {
            selectedPpd = suggestedPPDs[0].name;
        }
    }

    Component.onCompleted: {
        CupsService.getClasses();
    }

    ConfirmModal {
        id: deletePrinterConfirm
    }

    ConfirmModal {
        id: purgeJobsConfirm
    }

    ConfirmModal {
        id: deleteClassConfirm
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            width: Math.min(600, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingL

            StyledRect {
                width: parent.width
                height: overviewSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: overviewSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "print"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("CUPS Print Server")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    }

                    Grid {
                        columns: 2
                        columnSpacing: Theme.spacingL
                        rowSpacing: Theme.spacingS
                        width: parent.width

                        StyledText {
                            text: I18n.tr("Status")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                        Row {
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: CupsService.cupsAvailable ? Theme.success : Theme.error
                            }

                            StyledText {
                                text: CupsService.cupsAvailable ? I18n.tr("Available") : I18n.tr("Unavailable")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }
                        }

                        StyledText {
                            text: I18n.tr("Printers")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                        StyledText {
                            text: CupsService.printerNames.length.toString()
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: I18n.tr("Total Jobs")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                        StyledText {
                            text: CupsService.getTotalJobsNum().toString()
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: addPrinterSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                visible: CupsService.cupsAvailable

                Column {
                    id: addPrinterSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "add_circle"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - addPrinterToggleBtn.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Add Printer")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Configure a new printer")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        Rectangle {
                            id: addPrinterToggleBtn
                            width: 28
                            height: 28
                            radius: 14
                            color: addPrinterToggleArea.containsMouse ? Theme.surfacePressed : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            DankIcon {
                                anchors.centerIn: parent
                                name: printerTab.showAddPrinter ? "expand_less" : "expand_more"
                                size: 18
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: addPrinterToggleArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    printerTab.showAddPrinter = !printerTab.showAddPrinter;
                                    if (printerTab.showAddPrinter) {
                                        if (CupsService.devices.length === 0) {
                                            CupsService.getDevices();
                                            CupsService.getPPDs();
                                        }
                                    } else {
                                        printerTab.resetAddPrinterForm();
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: printerTab.showAddPrinter

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: I18n.tr("Device")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankDropdown {
                                    id: deviceDropdown
                                    dropdownWidth: parent.width - 80 - scanDevicesBtn.width - Theme.spacingS * 2
                                    popupWidth: parent.width - 80 - scanDevicesBtn.width - Theme.spacingS * 2
                                    currentValue: {
                                        if (CupsService.loadingDevices)
                                            return I18n.tr("Scanning...");
                                        if (printerTab.selectedDevice)
                                            return CupsService.getDeviceDisplayName(printerTab.selectedDevice);
                                        return I18n.tr("Select device...");
                                    }
                                    options: {
                                        const filtered = CupsService.filteredDevices;
                                        if (filtered.length === 0)
                                            return [I18n.tr("No devices found")];
                                        return filtered.map(d => CupsService.getDeviceDisplayName(d));
                                    }
                                    onValueChanged: value => {
                                        if (value === I18n.tr("No devices found") || value === I18n.tr("Scanning..."))
                                            return;
                                        const filtered = CupsService.filteredDevices;
                                        const device = filtered.find(d => CupsService.getDeviceDisplayName(d) === value);
                                        if (device) {
                                            printerTab.selectDevice(device);
                                        }
                                    }
                                }

                                DankActionButton {
                                    id: scanDevicesBtn
                                    iconName: "refresh"
                                    buttonSize: 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    enabled: !CupsService.loadingDevices
                                    onClicked: CupsService.getDevices()

                                    RotationAnimation on rotation {
                                        running: CupsService.loadingDevices
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 1000
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                visible: printerTab.selectedDevice !== null

                                Item {
                                    width: 80
                                    height: 1
                                }

                                StyledText {
                                    text: CupsService.getDeviceSubtitle(printerTab.selectedDevice)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width - 80 - Theme.spacingS
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: I18n.tr("Driver")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankDropdown {
                                    id: ppdDropdown
                                    dropdownWidth: parent.width - 80 - refreshPpdsBtn.width - Theme.spacingS * 2
                                    popupWidth: parent.width - 80 - refreshPpdsBtn.width - Theme.spacingS * 2
                                    currentValue: {
                                        if (CupsService.loadingPPDs)
                                            return I18n.tr("Loading...");
                                        if (printerTab.selectedPpd) {
                                            const ppd = CupsService.ppds.find(p => p.name === printerTab.selectedPpd);
                                            if (ppd) {
                                                const isSuggested = printerTab.suggestedPPDs.some(s => s.name === ppd.name);
                                                return (isSuggested ? "★ " : "") + (ppd.makeModel || ppd.name);
                                            }
                                            return printerTab.selectedPpd;
                                        }
                                        return printerTab.suggestedPPDs.length > 0 ? I18n.tr("Recommended available") : I18n.tr("Select driver...");
                                    }
                                    options: {
                                        if (CupsService.ppds.length === 0)
                                            return [I18n.tr("No drivers found")];
                                        const suggested = printerTab.suggestedPPDs.map(p => "★ " + (p.makeModel || p.name));
                                        const others = CupsService.ppds.filter(p => !printerTab.suggestedPPDs.some(s => s.name === p.name)).map(p => p.makeModel || p.name);
                                        return suggested.concat(others);
                                    }
                                    onValueChanged: value => {
                                        if (value === I18n.tr("No drivers found") || value === I18n.tr("Loading..."))
                                            return;
                                        const cleanValue = value.replace(/^★ /, "");
                                        const ppd = CupsService.ppds.find(p => (p.makeModel || p.name) === cleanValue);
                                        if (ppd) {
                                            printerTab.selectedPpd = ppd.name;
                                        }
                                    }
                                }

                                DankActionButton {
                                    id: refreshPpdsBtn
                                    iconName: "refresh"
                                    buttonSize: 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    enabled: !CupsService.loadingPPDs
                                    onClicked: CupsService.getPPDs()

                                    RotationAnimation on rotation {
                                        running: CupsService.loadingPPDs
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 1000
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: I18n.tr("Name")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankTextField {
                                    width: parent.width - 80 - Theme.spacingS
                                    height: 40
                                    placeholderText: I18n.tr("Printer name (no spaces)")
                                    text: printerTab.newPrinterName
                                    onTextEdited: printerTab.newPrinterName = text.replace(/\s/g, "-")
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: I18n.tr("Location")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankTextField {
                                    width: parent.width - 80 - Theme.spacingS
                                    height: 40
                                    placeholderText: I18n.tr("Optional location")
                                    text: printerTab.newPrinterLocation
                                    onTextEdited: printerTab.newPrinterLocation = text
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: I18n.tr("Description")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankTextField {
                                    width: parent.width - 80 - Theme.spacingS
                                    height: 40
                                    placeholderText: I18n.tr("Optional description")
                                    text: printerTab.newPrinterInfo
                                    onTextEdited: printerTab.newPrinterInfo = text
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            layoutDirection: Qt.RightToLeft

                            DankButton {
                                text: CupsService.creatingPrinter ? I18n.tr("Creating...") : I18n.tr("Create Printer")
                                iconName: CupsService.creatingPrinter ? "sync" : "add"
                                buttonHeight: 36
                                enabled: printerTab.newPrinterName.length > 0 && printerTab.selectedDeviceUri.length > 0 && printerTab.selectedPpd.length > 0 && !CupsService.creatingPrinter
                                onClicked: {
                                    CupsService.createPrinter(printerTab.newPrinterName, printerTab.selectedDeviceUri, printerTab.selectedPpd, {
                                        location: printerTab.newPrinterLocation,
                                        information: printerTab.newPrinterInfo
                                    });
                                    printerTab.resetAddPrinterForm();
                                    printerTab.showAddPrinter = false;
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: printersSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                visible: CupsService.cupsAvailable

                Column {
                    id: printersSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "print"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - refreshBtn.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Printers")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: {
                                    const count = CupsService.printerNames.length;
                                    if (count === 0)
                                        return I18n.tr("No printers configured");
                                    return I18n.tr("%1 printer(s)").arg(count);
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        DankActionButton {
                            id: refreshBtn
                            iconName: "refresh"
                            buttonSize: 32
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: CupsService.getState()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    }

                    Item {
                        width: parent.width
                        height: 80
                        visible: CupsService.printerNames.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "print_disabled"
                                size: 32
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("No printers found")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: CupsService.printerNames.length > 0

                        Repeater {
                            model: CupsService.printerNames

                            delegate: Rectangle {
                                id: printerDelegate
                                required property string modelData
                                required property int index

                                readonly property var printerData: CupsService.getPrinterData(modelData)
                                readonly property bool isExpanded: CupsService.expandedPrinter === modelData || hasJobs
                                readonly property bool hasJobs: (printerData?.jobs?.length ?? 0) > 0
                                readonly property bool isIdle: printerData?.state === "idle"
                                readonly property bool isStopped: printerData?.state === "stopped"

                                width: parent.width
                                height: isExpanded ? 56 + expandedContent.height : 56
                                radius: Theme.cornerRadius
                                color: printerMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                                border.width: CupsService.selectedPrinter === modelData ? 2 : 0
                                border.color: Theme.primary
                                clip: true

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Column {
                                    anchors.fill: parent
                                    spacing: 0

                                    Item {
                                        width: parent.width
                                        height: 56

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: printerActions.left
                                            anchors.rightMargin: Theme.spacingS
                                            spacing: Theme.spacingS

                                            DankIcon {
                                                name: isStopped ? "print_disabled" : "print"
                                                size: 20
                                                color: isStopped ? Theme.error : (isIdle ? Theme.primary : Theme.warning)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2
                                                width: parent.width - 20 - Theme.spacingS

                                                StyledText {
                                                    text: modelData
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: Theme.surfaceText
                                                    font.weight: CupsService.selectedPrinter === modelData ? Font.Medium : Font.Normal
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }

                                                Row {
                                                    spacing: Theme.spacingXS

                                                    StyledText {
                                                        text: CupsService.getPrinterStateTranslation(printerData?.state || "")
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: {
                                                            switch (printerData?.state) {
                                                            case "idle":
                                                                return Theme.primary;
                                                            case "stopped":
                                                                return Theme.error;
                                                            case "processing":
                                                                return Theme.warning;
                                                            default:
                                                                return Theme.surfaceVariantText;
                                                            }
                                                        }
                                                    }

                                                    StyledText {
                                                        text: "•"
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Theme.surfaceVariantText
                                                        visible: (printerData?.jobs?.length ?? 0) > 0
                                                    }

                                                    StyledText {
                                                        text: I18n.tr("%1 job(s)").arg(printerData?.jobs?.length ?? 0)
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Theme.surfaceVariantText
                                                        visible: (printerData?.jobs?.length ?? 0) > 0
                                                    }
                                                }
                                            }
                                        }

                                        Row {
                                            id: printerActions
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.spacingS
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingXS

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: expandBtn.containsMouse ? Theme.surfacePressed : "transparent"

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: isExpanded ? "expand_less" : "expand_more"
                                                    size: 18
                                                    color: Theme.surfaceText
                                                }

                                                MouseArea {
                                                    id: expandBtn
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        CupsService.expandedPrinter = isExpanded ? "" : modelData;
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: deleteBtn.containsMouse ? Theme.errorHover : "transparent"

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "delete"
                                                    size: 18
                                                    color: deleteBtn.containsMouse ? Theme.error : Theme.surfaceVariantText
                                                }

                                                MouseArea {
                                                    id: deleteBtn
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        deletePrinterConfirm.showWithOptions({
                                                            title: I18n.tr("Delete Printer"),
                                                            message: I18n.tr("Delete \"%1\"?").arg(modelData),
                                                            confirmText: I18n.tr("Delete"),
                                                            confirmColor: Theme.error,
                                                            onConfirm: () => CupsService.deletePrinter(modelData)
                                                        });
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: printerMouseArea
                                            anchors.fill: parent
                                            anchors.rightMargin: printerActions.width + Theme.spacingM
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                CupsService.setSelectedPrinter(modelData);
                                            }
                                        }
                                    }

                                    Column {
                                        id: expandedContent
                                        width: parent.width
                                        visible: isExpanded

                                        Rectangle {
                                            width: parent.width - Theme.spacingM * 2
                                            height: 1
                                            x: Theme.spacingM
                                            color: Theme.outlineLight
                                        }

                                        Item {
                                            width: parent.width
                                            height: detailsColumn.implicitHeight + Theme.spacingM * 2

                                            Column {
                                                id: detailsColumn
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingM
                                                spacing: Theme.spacingS

                                                Flow {
                                                    width: parent.width
                                                    spacing: Theme.spacingXS

                                                    Repeater {
                                                        model: {
                                                            const fields = [];
                                                            const p = printerData;
                                                            if (!p)
                                                                return fields;

                                                            fields.push({
                                                                label: I18n.tr("State"),
                                                                value: CupsService.getPrinterStateTranslation(p.state)
                                                            });
                                                            if (p.stateReason && p.stateReason !== "none")
                                                                fields.push({
                                                                    label: I18n.tr("Reason"),
                                                                    value: CupsService.getPrinterStateReasonTranslation(p.stateReason)
                                                                });
                                                            if (p.makeModel)
                                                                fields.push({
                                                                    label: I18n.tr("Model"),
                                                                    value: p.makeModel
                                                                });
                                                            if (p.location)
                                                                fields.push({
                                                                    label: I18n.tr("Location"),
                                                                    value: p.location
                                                                });
                                                            fields.push({
                                                                label: I18n.tr("Accepting"),
                                                                value: p.accepting ? I18n.tr("Yes") : I18n.tr("No")
                                                            });

                                                            return fields;
                                                        }

                                                        delegate: Rectangle {
                                                            required property var modelData
                                                            required property int index

                                                            width: fieldContent.width + Theme.spacingM * 2
                                                            height: 32
                                                            radius: Theme.cornerRadius - 2
                                                            color: Theme.surfaceContainerHigh
                                                            border.width: 1
                                                            border.color: Theme.outlineLight

                                                            Row {
                                                                id: fieldContent
                                                                anchors.centerIn: parent
                                                                spacing: Theme.spacingXS

                                                                StyledText {
                                                                    text: modelData.label + ":"
                                                                    font.pixelSize: Theme.fontSizeSmall
                                                                    color: Theme.surfaceVariantText
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }

                                                                StyledText {
                                                                    text: modelData.value
                                                                    font.pixelSize: Theme.fontSizeSmall
                                                                    color: Theme.surfaceText
                                                                    font.weight: Font.Medium
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Row {
                                                    width: parent.width
                                                    spacing: Theme.spacingS

                                                    Rectangle {
                                                        height: 28
                                                        width: pauseResumeRow.width + Theme.spacingM * 2
                                                        radius: 14
                                                        color: pauseResumeArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight

                                                        Row {
                                                            id: pauseResumeRow
                                                            anchors.centerIn: parent
                                                            spacing: Theme.spacingXS

                                                            DankIcon {
                                                                name: isStopped ? "play_arrow" : "pause"
                                                                size: 16
                                                                color: Theme.surfaceText
                                                            }

                                                            StyledText {
                                                                text: isStopped ? I18n.tr("Resume") : I18n.tr("Pause")
                                                                font.pixelSize: Theme.fontSizeSmall
                                                                color: Theme.surfaceText
                                                                font.weight: Font.Medium
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: pauseResumeArea
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (isStopped) {
                                                                    CupsService.resumePrinter(modelData);
                                                                } else {
                                                                    CupsService.pausePrinter(modelData);
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        height: 28
                                                        width: testPageRow.width + Theme.spacingM * 2
                                                        radius: 14
                                                        color: testPageArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight

                                                        Row {
                                                            id: testPageRow
                                                            anchors.centerIn: parent
                                                            spacing: Theme.spacingXS

                                                            DankIcon {
                                                                name: "description"
                                                                size: 16
                                                                color: Theme.surfaceText
                                                            }

                                                            StyledText {
                                                                text: I18n.tr("Test Page")
                                                                font.pixelSize: Theme.fontSizeSmall
                                                                color: Theme.surfaceText
                                                                font.weight: Font.Medium
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: testPageArea
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: CupsService.printTestPage(modelData)
                                                        }
                                                    }

                                                    Rectangle {
                                                        height: 28
                                                        width: acceptRejectRow.width + Theme.spacingM * 2
                                                        radius: 14
                                                        color: acceptRejectArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight

                                                        Row {
                                                            id: acceptRejectRow
                                                            anchors.centerIn: parent
                                                            spacing: Theme.spacingXS

                                                            DankIcon {
                                                                name: printerData?.accepting ? "block" : "check_circle"
                                                                size: 16
                                                                color: Theme.surfaceText
                                                            }

                                                            StyledText {
                                                                text: printerData?.accepting ? I18n.tr("Reject Jobs") : I18n.tr("Accept Jobs")
                                                                font.pixelSize: Theme.fontSizeSmall
                                                                color: Theme.surfaceText
                                                                font.weight: Font.Medium
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: acceptRejectArea
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (printerData?.accepting) {
                                                                    CupsService.rejectJobs(modelData);
                                                                } else {
                                                                    CupsService.acceptJobs(modelData);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Column {
                                                    width: parent.width
                                                    spacing: Theme.spacingXS
                                                    visible: (printerData?.jobs?.length ?? 0) > 0

                                                    Row {
                                                        width: parent.width
                                                        spacing: Theme.spacingS

                                                        StyledText {
                                                            text: I18n.tr("Jobs")
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            font.weight: Font.Medium
                                                            color: Theme.surfaceText
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Item {
                                                            width: 1
                                                            height: 1
                                                            Layout.fillWidth: true
                                                        }

                                                        Rectangle {
                                                            height: 24
                                                            width: purgeRow.width + Theme.spacingM * 2
                                                            radius: 12
                                                            color: purgeArea.containsMouse ? Theme.errorHover : Theme.surfaceLight

                                                            Row {
                                                                id: purgeRow
                                                                anchors.centerIn: parent
                                                                spacing: Theme.spacingXS

                                                                DankIcon {
                                                                    name: "delete_sweep"
                                                                    size: 14
                                                                    color: purgeArea.containsMouse ? Theme.error : Theme.surfaceText
                                                                }

                                                                StyledText {
                                                                    text: I18n.tr("Clear All")
                                                                    font.pixelSize: Theme.fontSizeSmall - 1
                                                                    color: purgeArea.containsMouse ? Theme.error : Theme.surfaceText
                                                                    font.weight: Font.Medium
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: purgeArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    purgeJobsConfirm.showWithOptions({
                                                                        title: I18n.tr("Clear All Jobs"),
                                                                        message: I18n.tr("Cancel all jobs for \"%1\"?").arg(modelData),
                                                                        confirmText: I18n.tr("Clear"),
                                                                        confirmColor: Theme.error,
                                                                        onConfirm: () => CupsService.purgeJobs(modelData)
                                                                    });
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Repeater {
                                                        model: printerData?.jobs ?? []

                                                        delegate: Rectangle {
                                                            required property var modelData
                                                            required property int index

                                                            width: parent.width
                                                            height: 44
                                                            radius: Theme.cornerRadius - 2
                                                            color: Theme.surfaceContainerHighest
                                                            border.width: 1
                                                            border.color: Theme.outlineLight

                                                            Row {
                                                                anchors.left: parent.left
                                                                anchors.leftMargin: Theme.spacingS
                                                                anchors.right: jobActions.left
                                                                anchors.rightMargin: Theme.spacingS
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                spacing: Theme.spacingS

                                                                DankIcon {
                                                                    name: "description"
                                                                    size: 18
                                                                    color: Theme.surfaceVariantText
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }

                                                                Column {
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    spacing: 1
                                                                    width: parent.width - 18 - Theme.spacingS

                                                                    StyledText {
                                                                        text: "[" + modelData.id + "] " + CupsService.getJobStateTranslation(modelData.state)
                                                                        font.pixelSize: Theme.fontSizeSmall
                                                                        color: Theme.surfaceText
                                                                        elide: Text.ElideRight
                                                                        width: parent.width
                                                                    }

                                                                    StyledText {
                                                                        text: {
                                                                            const size = Math.round((modelData.size || 0) / 1024);
                                                                            const date = new Date(modelData.timeCreated);
                                                                            return size + " KB • " + date.toLocaleString(Qt.locale(), Locale.ShortFormat);
                                                                        }
                                                                        font.pixelSize: Theme.fontSizeSmall - 1
                                                                        color: Theme.surfaceVariantText
                                                                    }
                                                                }
                                                            }

                                                            Row {
                                                                id: jobActions
                                                                anchors.right: parent.right
                                                                anchors.rightMargin: Theme.spacingS
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                spacing: 4

                                                                Rectangle {
                                                                    width: 24
                                                                    height: 24
                                                                    radius: 12
                                                                    color: holdJobBtn.containsMouse ? Theme.surfacePressed : "transparent"
                                                                    visible: modelData.state === "pending"

                                                                    DankIcon {
                                                                        anchors.centerIn: parent
                                                                        name: "pause"
                                                                        size: 14
                                                                        color: Theme.surfaceVariantText
                                                                    }

                                                                    MouseArea {
                                                                        id: holdJobBtn
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: CupsService.holdJob(modelData.id)
                                                                    }
                                                                }

                                                                Rectangle {
                                                                    width: 24
                                                                    height: 24
                                                                    radius: 12
                                                                    color: restartJobBtn.containsMouse ? Theme.surfacePressed : "transparent"
                                                                    visible: modelData.state === "pending-held" || modelData.state === "completed" || modelData.state === "aborted"

                                                                    DankIcon {
                                                                        anchors.centerIn: parent
                                                                        name: "replay"
                                                                        size: 14
                                                                        color: Theme.surfaceVariantText
                                                                    }

                                                                    MouseArea {
                                                                        id: restartJobBtn
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: CupsService.restartJob(modelData.id)
                                                                    }
                                                                }

                                                                Rectangle {
                                                                    width: 24
                                                                    height: 24
                                                                    radius: 12
                                                                    color: cancelJobBtn.containsMouse ? Theme.errorHover : "transparent"

                                                                    DankIcon {
                                                                        anchors.centerIn: parent
                                                                        name: "close"
                                                                        size: 14
                                                                        color: cancelJobBtn.containsMouse ? Theme.error : Theme.surfaceVariantText
                                                                    }

                                                                    MouseArea {
                                                                        id: cancelJobBtn
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: CupsService.cancelJob(printerDelegate.modelData, modelData.id)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: classesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                visible: CupsService.cupsAvailable && CupsService.printerClasses.length > 0

                Column {
                    id: classesSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "workspaces"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - refreshClassesBtn.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Printer Classes")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("%1 class(es)").arg(CupsService.printerClasses.length)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        DankActionButton {
                            id: refreshClassesBtn
                            iconName: "refresh"
                            buttonSize: 32
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: CupsService.getClasses()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: CupsService.printerClasses

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: classMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.right: classActions.left
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "workspaces"
                                        size: 20
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        StyledText {
                                            text: modelData.name || I18n.tr("Unknown")
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            text: I18n.tr("%1 printer(s)").arg(modelData.members?.length ?? 0)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                Row {
                                    id: classActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: deleteClassBtn.containsMouse ? Theme.errorHover : "transparent"

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "delete"
                                            size: 18
                                            color: deleteClassBtn.containsMouse ? Theme.error : Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            id: deleteClassBtn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                deleteClassConfirm.showWithOptions({
                                                    title: I18n.tr("Delete Class"),
                                                    message: I18n.tr("Delete class \"%1\"?").arg(modelData.name),
                                                    confirmText: I18n.tr("Delete"),
                                                    confirmColor: Theme.error,
                                                    onConfirm: () => CupsService.deleteClass(modelData.name)
                                                });
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: classMouseArea
                                    anchors.fill: parent
                                    anchors.rightMargin: classActions.width + Theme.spacingM
                                    hoverEnabled: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
