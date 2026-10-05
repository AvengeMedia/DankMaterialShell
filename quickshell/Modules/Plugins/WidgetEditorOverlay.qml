pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankDash.Overview
import qs.Modules.Settings.DesktopWidgetSettings
import qs.Modules.Settings.Widgets

FocusScope {
    id: root

    required property WidgetEditLayer editLayer
    readonly property bool lockScreen: editLayer.lockScreen
    readonly property bool greeter: editLayer.greeter
    property bool libraryOpen: false
    readonly property real fabReserved: fabBar.reservedHeight
    readonly property var singletonTypes: ["lockAuth", "greeterSession"]
    readonly property var libraryWidgets: DesktopWidgetRegistry.getListWidgets(editLayer.listKey).filter(widget => {
        if (!lockScreen)
            return true;
        return !singletonTypes.includes(widget.id) || !SettingsData.widgetInstanceOfType(editLayer.listKey, widget.id);
    }).map(widget => ({
                id: widget.id,
                text: widget.name,
                icon: widget.icon,
                description: widget.description
            }))

    readonly property string surfaceLabel: {
        if (greeter)
            return SettingsData.greeterFollowLockScreen ? I18n.tr("Editing the login screen, shared with the lock screen", "widget editor banner") : I18n.tr("Editing the login screen", "widget editor banner");
        if (!lockScreen || !GreeterService.available)
            return "";
        return SettingsData.greeterFollowLockScreen && GreeterService.slotState !== "" ? I18n.tr("Editing the lock screen, the login screen follows it", "widget editor banner") : I18n.tr("Editing the lock screen", "widget editor banner");
    }

    signal finished

    function closeLibrary() {
        libraryOpen = false;
        forceActiveFocus();
    }

    function showOptions(instanceData) {
        optionsSheet.instanceId = instanceData?.id ?? "";
        optionsSheet.opened = true;
    }

    function addWidget(widgetType) {
        const def = DesktopWidgetRegistry.getWidget(widgetType);
        const instance = SettingsData.createDesktopWidgetInstance(widgetType, def?.name ?? widgetType, DesktopWidgetRegistry.getDefaultConfig(widgetType), editLayer.listKey);
        editLayer.pendingIds = editLayer.pendingIds.concat([instance.id]);
    }

    function resetLayout() {
        if (greeter) {
            SettingsData.resetGreeterWidgets();
            return;
        }
        if (lockScreen) {
            SettingsData.resetLockScreenWidgets();
            return;
        }
        for (const instance of SettingsData.desktopWidgetInstances || [])
            SessionData.resetDesktopWidgetInstanceGeometry(instance.id, ["x", "y", "width", "height"]);
    }

    function dismiss() {
        if (editControls.pendingAction !== "") {
            editControls.cancelConfirmation();
            return;
        }
        if (libraryOpen) {
            closeLibrary();
            return;
        }
        finished();
    }

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: dismiss()

    MouseArea {
        anchors.fill: parent
        visible: root.libraryOpen
        acceptedButtons: Qt.AllButtons
        onClicked: root.closeLibrary()
    }

    Loader {
        anchors.centerIn: parent
        active: root.libraryOpen

        sourceComponent: CcWidgetLibrary {
            width: Math.min(implicitWidth, root.width - Theme.spacingL * 2)
            height: Math.min(implicitHeight, root.height - Theme.spacingL * 2)
            widgets: root.libraryWidgets
            Component.onCompleted: reset()
            onChosen: widgetId => {
                root.addWidget(widgetId);
                root.closeLibrary();
            }
            onDismissed: root.closeLibrary()
        }
    }

    DankBottomSheet {
        id: optionsSheet

        property string instanceId: ""
        readonly property var instanceData: SettingsData.getDesktopWidgetInstance(instanceId)
        readonly property var widgetDef: DesktopWidgetRegistry.getWidget(instanceData?.widgetType ?? "")

        maximumWidth: Math.min(Theme.mediumBreakpoint, root.width - Theme.spacingXL * 2)
        topMargin: root.height * 0.3
        returnFocusItem: root
        title: instanceData?.name || widgetDef?.name || ""
        onDismissRequested: opened = false
        onActiveChanged: {
            if (!active)
                instanceId = "";
        }

        DesktopWidgetTypeSettings {
            width: parent.width
            instanceId: optionsSheet.instanceId
            instanceData: optionsSheet.instanceData
            widgetDef: optionsSheet.widgetDef
        }
    }

    Rectangle {
        visible: root.surfaceLabel !== "" && fabBar.shown
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: fabBar.reservedHeight + Theme.spacingL + (gridHint.visible ? gridHint.height + Theme.spacingS : 0)
        width: surfaceRow.implicitWidth + Theme.spacingL * 2
        height: Theme.buttonHeightM
        radius: Theme.fullRadius(width, height)
        color: Theme.readableSurface
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium

        Row {
            id: surfaceRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.greeter ? "login" : "lock"
                size: Theme.iconSizeMedium
                color: Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.surfaceLabel
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }
        }
    }

    DesktopWidgetGridHint {
        id: gridHint
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: fabBar.reservedHeight + Theme.spacingL
        visible: fabBar.shown && (root.editLayer.selectedInstanceId !== "" || root.editLayer.interactingItem !== null)
        gridEnabled: root.editLayer.gridEnabled
        gridSize: root.editLayer.gridSize
    }

    SettingsFabBar {
        id: fabBar
        shown: !root.libraryOpen && !optionsSheet.active

        DashEditControls {
            id: editControls
            canClear: false
            onAddRequested: root.libraryOpen = true
            onResetRequested: root.resetLayout()
            onFinished: root.finished()
        }
    }
}
