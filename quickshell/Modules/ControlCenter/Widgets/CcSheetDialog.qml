import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Widgets
import "../../../DankCommon/Common/FocusNavigation.js" as FocusNavigation

Item {
    id: root

    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property string statusText: ""
    property color statusColor: Theme.surfaceVariantText
    property bool shown: false
    property real panelWidth: CcMetrics.dialogWidth
    property vector4d cornerRadii: Qt.vector4d(Theme.windowRadius, Theme.windowRadius, Theme.windowRadius, Theme.windowRadius)
    default property alias content: contentSlot.data

    signal dismissed

    anchors.fill: parent
    visible: shown || panel.opacity > 0
    z: CcMetrics.overlayZ

    function present() {
        contentFlickable.contentY = 0;
        shown = true;
        focusScope.forceActiveFocus();
    }

    function dismiss() {
        shown = false;
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.AllButtons
        onClicked: root.dismiss()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.cornerRadii.x
        topRightRadius: root.cornerRadii.y
        bottomRightRadius: root.cornerRadii.z
        bottomLeftRadius: root.cornerRadii.w
        color: Qt.rgba(0, 0, 0, Theme.scrimAlpha)
        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            enabled: CcMetrics.animationsEnabled
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: root.shown
        enabled: root.shown

        Keys.onEscapePressed: event => {
            root.dismiss();
            event.accepted = true;
        }
    }

    Rectangle {
        id: panel
        parent: focusScope
        anchors.centerIn: parent
        width: Math.min(root.panelWidth, root.width - Theme.spacingL * 2)
        height: column.implicitHeight + Theme.spacingL * 2
        radius: Theme.windowRadius
        color: Theme.nestedSurface
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : CcMetrics.popupEnterScale

        onOpacityChanged: {
            if (opacity > 0 || root.shown)
                return;
            root.dismissed();
        }

        Behavior on opacity {
            enabled: CcMetrics.animationsEnabled
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }

        Behavior on scale {
            enabled: CcMetrics.animationsEnabled
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            acceptedButtons: Qt.AllButtons
            onClicked: mouse => mouse.accepted = true
            onWheel: wheel => wheel.accepted = true
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                id: header
                width: parent.width
                spacing: Theme.spacingM

                DankIcon {
                    name: root.iconName
                    size: Theme.iconSizeLarge
                    color: Theme.primary
                    visible: name !== ""
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - (root.iconName !== "" ? Theme.iconSizeLarge + parent.spacing : 0)
                    spacing: Theme.spacingXXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        text: root.title
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: root.subtitle
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }
            }

            StyledText {
                id: status
                width: parent.width
                text: root.statusText
                font.pixelSize: Theme.fontSizeSmall
                color: root.statusColor
                wrapMode: Text.WordWrap
                visible: text !== ""
            }

            DankFlickable {
                id: contentFlickable
                width: parent.width
                height: Math.min(contentHeight, Math.max(0, root.height - Theme.spacingL * 4 - header.height - column.spacing - (status.visible ? status.height + column.spacing : 0)))
                contentHeight: contentSlot.implicitHeight
                clip: true

                readonly property Item windowFocusItem: Window.activeFocusItem
                onWindowFocusItemChanged: {
                    const item = windowFocusItem;
                    if (!root.shown || !item || !FocusNavigation.containsFocus(contentSlot))
                        return;
                    const top = item.mapToItem(contentSlot, 0, 0).y;
                    const y = Math.min(top, Math.max(contentFlickable.contentY, top + item.height - contentFlickable.height));
                    contentFlickable.contentY = Math.max(0, Math.min(contentFlickable.contentHeight - contentFlickable.height, y));
                }

                Column {
                    id: contentSlot
                    width: parent.width
                    spacing: CcMetrics.detailContentGap
                }
            }
        }
    }
}
