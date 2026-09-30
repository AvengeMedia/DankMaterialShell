pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool editMode: false
    property bool showEdit: true
    property string pendingAction: ""

    signal addWidgetRequested
    signal resetRequested
    signal clearRequested
    signal editToggled
    signal cancelRequested

    readonly property real leadingWidth: Math.max(0, width - trailing.width - CcMetrics.footerGap)
    readonly property bool occupied: editMode || showEdit

    implicitHeight: occupied ? CcMetrics.footerHeight : 0
    visible: occupied

    function cancelConfirmation() {
        pendingAction = "";
    }

    function confirm(action) {
        if (pendingAction !== action) {
            pendingAction = action;
            return false;
        }
        pendingAction = "";
        return true;
    }

    onEditModeChanged: cancelConfirmation()

    Row {
        id: editActions

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS
        visible: root.editMode

        DankButton {
            id: addButton
            buttonHeight: CcMetrics.footerHeight
            maximumWidth: root.leadingWidth
            iconName: "add"
            text: I18n.tr("Add widget")
            backgroundColor: Theme.secondaryContainer
            textColor: Theme.onSecondaryContainer
            onClicked: {
                root.cancelConfirmation();
                root.addWidgetRequested();
            }
        }

        DankButton {
            readonly property string label: I18n.tr("Defaults", "noun, control center edit button restoring the default layout")
            readonly property string confirmLabel: I18n.tr("Confirm")
            readonly property bool armed: root.pendingAction === "reset"

            buttonHeight: CcMetrics.footerHeight
            maximumWidth: Math.max(0, root.leadingWidth - addButton.width - clearButton.width - editActions.spacing * 2)
            iconName: "settings_backup_restore"
            text: armed ? confirmLabel : label
            reserveText: armed ? label : confirmLabel
            backgroundColor: armed ? Theme.primary : CcMetrics.tileInactiveColor
            textColor: armed ? Theme.onPrimary : CcMetrics.tileInactiveContent
            onClicked: {
                if (root.confirm("reset"))
                    root.resetRequested();
            }
        }

        DankActionButton {
            id: clearButton

            readonly property bool armed: root.pendingAction === "clear"

            buttonSize: CcMetrics.footerHeight
            iconName: "clear_all"
            iconSize: CcMetrics.iconBoxIconSize
            iconColor: armed ? Theme.onError : Theme.error
            backgroundColor: armed ? Theme.error : CcMetrics.tileInactiveColor
            tooltipText: armed ? I18n.tr("Confirm") : I18n.tr("Clear All")
            onClicked: {
                if (root.confirm("clear"))
                    root.clearRequested();
            }
        }
    }

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        DankActionButton {
            buttonSize: CcMetrics.footerHeight
            iconName: "close"
            iconSize: CcMetrics.iconBoxIconSize
            iconColor: CcMetrics.tileInactiveContent
            backgroundColor: CcMetrics.tileInactiveColor
            border.width: Theme.layerOutlineWidth
            border.color: Theme.outlineMedium
            tooltipText: I18n.tr("Discard")
            visible: root.editMode
            onClicked: root.cancelRequested()
        }

        DankActionButton {
            buttonSize: CcMetrics.footerHeight
            iconName: "check"
            iconSize: CcMetrics.iconBoxIconSize
            iconColor: Theme.onPrimary
            backgroundColor: Theme.primary
            tooltipText: I18n.tr("Save")
            visible: root.editMode
            onClicked: root.editToggled()
        }

        DankActionButton {
            buttonSize: CcMetrics.footerHeight
            iconName: "edit"
            iconSize: CcMetrics.iconBoxIconSize
            iconColor: CcMetrics.tileInactiveContent
            backgroundColor: CcMetrics.tileInactiveColor
            border.width: Theme.layerOutlineWidth
            border.color: Theme.outlineMedium
            tooltipText: I18n.tr("Edit")
            visible: !root.editMode && root.showEdit
            onClicked: root.editToggled()
        }
    }
}
