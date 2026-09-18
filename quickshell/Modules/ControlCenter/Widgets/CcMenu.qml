pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Widgets

Item {
    id: root

    property var items: []
    readonly property bool open: _open
    property bool _open: false
    property var _anchor: null
    property int _focusIndex: -1

    readonly property var visibleItems: (items || []).filter(item => item.visible !== false)

    signal closed

    anchors.fill: parent
    visible: _open || panel.opacity > 0
    z: CcMetrics.overlayZ

    function _measure() {
        let widest = 0;
        let hasIcon = false;
        for (const item of visibleItems) {
            labelMetrics.text = item.label || "";
            widest = Math.max(widest, labelMetrics.advanceWidth);
            hasIcon = hasIcon || !!item.iconName;
        }
        const iconSpan = hasIcon ? Theme.iconSizeMedium + Theme.spacingM : 0;
        panel.width = Math.max(CcMetrics.menuMinWidth, widest + iconSpan + Theme.spacingM * 2 + Theme.spacingS * 2);
    }

    function openAt(anchor) {
        _anchor = anchor;
        _focusIndex = -1;
        _measure();
        _reposition();
        _open = true;
        focusScope.forceActiveFocus();
    }

    function close() {
        if (!_open)
            return;
        _open = false;
        closed();
        if (_anchor)
            _anchor.forceActiveFocus();
    }

    function _reposition() {
        if (!_anchor)
            return;
        const pos = _anchor.mapToItem(root, 0, 0);
        const maxX = root.width - panel.width - Theme.spacingS;
        const preferredX = I18n.isRtl ? pos.x : pos.x + _anchor.width - panel.width;
        panel.x = Math.max(Theme.spacingS, Math.min(preferredX, maxX));
        let y = pos.y + _anchor.height + Theme.spacingXS;
        if (y + panel.height > root.height - Theme.spacingS)
            y = pos.y - panel.height - Theme.spacingXS;
        panel.y = Math.max(Theme.spacingS, y);
    }

    function _activate(index) {
        const item = visibleItems[index];
        if (!item || item.enabled === false)
            return;
        close();
        if (typeof item.action === "function")
            item.action();
    }

    function _moveFocus(delta) {
        const count = visibleItems.length;
        if (count === 0)
            return;
        let next = _focusIndex;
        for (let i = 0; i < count; i++) {
            next = (next + delta + count) % count;
            if (visibleItems[next].enabled !== false)
                break;
        }
        _focusIndex = next;
    }

    MouseArea {
        anchors.fill: parent
        enabled: root._open
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
        onWheel: wheel => wheel.accepted = true
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: root._open

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.close();
                break;
            case Qt.Key_Down:
                root._moveFocus(1);
                break;
            case Qt.Key_Up:
                root._moveFocus(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root._activate(root._focusIndex);
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    StyledTextMetrics {
        id: labelMetrics
        font.pixelSize: Theme.fontSizeMedium
    }

    Rectangle {
        id: panel
        width: CcMetrics.menuMinWidth
        height: column.implicitHeight + Theme.spacingS * 2
        radius: Theme.windowRadius
        color: Theme.nestedSurface
        opacity: root._open ? 1 : 0
        scale: root._open ? 1 : CcMetrics.popupEnterScale
        transformOrigin: I18n.isRtl ? Item.TopLeft : Item.TopRight

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
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: mouse => mouse.accepted = true
            onWheel: wheel => wheel.accepted = true
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.spacingS
            width: parent.width - Theme.spacingS * 2

            Repeater {
                model: root.visibleItems

                Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool itemEnabled: modelData.enabled !== false
                    readonly property color contentColor: {
                        if (!itemEnabled)
                            return Theme.onSurface_38;
                        return modelData.destructive ? Theme.error : Theme.surfaceText;
                    }

                    width: parent.width
                    height: Theme.menuItemHeight
                    radius: Theme.cornerRadiusS
                    color: root._focusIndex === index && !rowLayer.containsMouse ? Theme.withAlpha(contentColor, Theme.stateLayerFocus) : "transparent"

                    Row {
                        id: rowContent
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: row.modelData.iconName || ""
                            size: Theme.iconSizeMedium
                            color: row.contentColor
                            visible: name !== ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: row.modelData.label || ""
                            font.pixelSize: Theme.fontSizeMedium
                            color: row.contentColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StateLayer {
                        id: rowLayer
                        disabled: !row.itemEnabled
                        stateColor: row.contentColor
                        cornerRadius: row.radius
                        onClicked: root._activate(row.index)
                    }
                }
            }
        }
    }
}
