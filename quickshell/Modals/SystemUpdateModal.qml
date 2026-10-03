import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Modules.SystemUpdate
import qs.Services
import qs.Widgets

DankFloatingWindow {
    id: root

    function show() {
        visible = true;
    }

    function hide() {
        visible = false;
    }

    objectName: "systemUpdateModal"
    title: I18n.tr("Software updates")
    minimumSize: Qt.size(SettingsMetrics.windowMinWidth, SettingsMetrics.windowMinHeight)
    implicitWidth: SettingsMetrics.formDialogWidth + SettingsMetrics.pagePaddingH * 2
    readonly property real defaultHeight: SettingsMetrics.windowHeight - SettingsMetrics.pagePaddingV * 4
    implicitHeight: screen ? Math.min(defaultHeight, screen.height - SettingsMetrics.pagePaddingH * 2 - Theme.spacingL) : defaultHeight
    visible: false

    Ref {
        service: SystemUpdateService
        active: root.visible
    }

    onClosed: hide()

    Column {
        anchors.fill: parent
        spacing: 0

        DankWindowHeader {
            id: titleBar
            width: parent.width
            controls: windowControls
            title: root.title
            onCloseRequested: root.hide()
        }

        SystemUpdatePanel {
            width: parent.width
            height: parent.height - titleBar.height
            hostVisible: root.visible
            onCloseRequested: root.hide()
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
