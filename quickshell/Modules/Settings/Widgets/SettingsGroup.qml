pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    readonly property bool isSettingsGroup: true
    default property alias content: host.data
    property real spacing: Theme.groupedListGap
    property real customPaddingH: SettingsMetrics.rowPaddingH
    property real customPaddingV: SettingsMetrics.rowPaddingV
    property bool highlighted: false
    property color slotColor: SettingsMetrics.rowColor
    property var slots: []

    width: parent?.width ?? 0
    implicitHeight: 0
    height: implicitHeight

    onWidthChanged: root.scheduleLayout()
    onSpacingChanged: root.scheduleLayout()
    onCustomPaddingHChanged: root.scheduleLayout()
    onCustomPaddingVChanged: root.scheduleLayout()
    onVisibleChanged: root.scheduleLayout()

    function scheduleLayout() {
        layoutTimer.restart();
    }

    Timer {
        id: layoutTimer
        interval: 0
        onTriggered: root.layout()
    }

    function isRowContainer(c) {
        const kids = c.visibleChildren;
        if (!kids || kids.length === 0)
            return false;
        for (let i = 0; i < kids.length; i++) {
            if (kids[i].isSettingsRow !== true && typeof kids[i].itemAt !== "function")
                return false;
        }
        return true;
    }

    function layout() {
        if (!visible)
            return;
        const items = [];
        let cursor = 0;
        for (let i = 0; i < host.children.length; i++) {
            const c = host.children[i];
            if (!c.visible || (c.isSettingsRow !== true && typeof c.itemAt === "function"))
                continue;
            if (c.isSettingsRow === true) {
                items.push(c);
                continue;
            }
            if (c.height <= 1 && c.children.length === 0 && c.border !== undefined) {
                c.height = 0;
                continue;
            }
            if (c.height <= 0)
                continue;
            items.push(c);
        }
        let y = 0;
        const next = [];
        for (let i = 0; i < items.length; i++) {
            const c = items[i];
            const container = c.isSettingsRow !== true && isRowContainer(c);
            const custom = c.isSettingsRow !== true && !container;
            const top = y;
            if (custom) {
                c.x = customPaddingH;
                c.width = root.width - customPaddingH * 2;
                c.y = top + customPaddingV;
            } else {
                c.x = 0;
                c.width = root.width;
                c.y = top;
            }
            const h = c.height + (custom ? customPaddingV * 2 : 0);
            next.push({
                "item": c,
                "y": top,
                "height": h,
                "transparent": c.transparentSlot === true || container
            });
            y += h + spacing;
        }
        slots = next;
        implicitHeight = Math.max(0, y - spacing);
    }

    Repeater {
        model: root.slots.length

        Rectangle {
            required property int index
            readonly property var slot: root.slots[index]
            readonly property bool first: index === 0
            readonly property bool last: index === root.slots.length - 1

            z: -1
            x: 0
            y: slot.y
            width: root.width
            height: slot.height
            visible: !slot.transparent
            topLeftRadius: first ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
            topRightRadius: first ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
            bottomLeftRadius: last ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
            bottomRightRadius: last ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
            color: root.highlighted ? Theme.blend(root.slotColor, Theme.primary, SettingsMetrics.highlightBlend) : root.slotColor

            Behavior on color {
                enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                ColorAnimation {
                    duration: SettingsMetrics.fadeDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }
        }
    }

    Item {
        id: host

        readonly property bool isSettingsGroupHost: true

        function isEdge(item, first) {
            const slot = root.slots[first ? 0 : root.slots.length - 1];
            return slot?.item === item;
        }

        anchors.left: parent.left
        anchors.right: parent.right
        height: root.implicitHeight

        onChildrenChanged: root.scheduleLayout()
    }

    Instantiator {
        model: host.children.length

        QtObject {
            required property int index
            readonly property Item child: host.children[index] ?? null
            readonly property bool childVisible: child?.visible ?? false
            readonly property real childHeight: child?.height ?? 0

            onChildVisibleChanged: root.scheduleLayout()
            onChildHeightChanged: root.scheduleLayout()
        }
    }
}
