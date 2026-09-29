import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.DankDash
import qs.Widgets

Item {
    id: root

    property var widgetData: ({})
    property var widgetDef: null
    property var host: null
    property bool live: true
    property bool interactive: true
    property real columns: 4
    property real rows: 1.5
    property bool compact: false

    readonly property bool tapToClose: interactive && (host?.tapToClose ?? false)
    readonly property bool background: widgetData?.background !== false
    readonly property real bodyRadius: Theme.cornerRadiusXL

    width: parent?.width ?? 0
    height: CcMetrics.headerHeight
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    Rectangle {
        anchors.fill: parent
        radius: root.bodyRadius
        color: Theme.foregroundColor(Theme.cardSurface)
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        visible: root.background
    }

    UserIdentity {
        id: identity

        anchors.fill: parent
        anchors.leftMargin: root.background ? Theme.spacingL : 0
        anchors.rightMargin: anchors.leftMargin
        anchors.topMargin: Theme.spacingS
        anchors.bottomMargin: Theme.spacingS
        live: root.live
        options: DashRegistry.resolvedOptions("user", root.widgetData)
        avatarSize: narrow ? height : Math.min(height - Theme.spacingM, width / 3)
        narrow: width < Theme.minimumTouchTargetSize + Theme.spacingM + Theme.buttonHeightM
        stacked: root.height >= CcMetrics.headerHeight
        contentColor: Theme.onSurface
        mutedColor: Theme.onSurfaceVariant
    }

    StyledButton {
        anchors.fill: parent
        visible: root.tapToClose
        radius: root.bodyRadius
        Accessible.name: I18n.tr("Close")
        onClicked: root.host?.headerTapped()

        FocusRing {
            anchors.fill: parent
            radius: parent.radius
            visible: parent.visualFocus
        }

        StateLayer {
            control: parent
            tooltipText: I18n.tr("Close")
        }
    }
}
