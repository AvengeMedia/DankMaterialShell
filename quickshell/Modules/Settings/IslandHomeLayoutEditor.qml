pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/QmlUtils.js" as QmlUtils

Item {
    id: root

    property string settingKey: "islandHomeLayout"
    required property string barId
    readonly property var groupIds: SettingsData._islandHomeGroupIds
    readonly property var layout: {
        SettingsData.barConfigs;
        return SettingsData.getIslandHomeLayout(SettingsData.getBarConfig(root.barId));
    }
    readonly property bool isHighlighted: settingKey !== "" && SettingsSearchService.highlightSection === settingKey

    readonly property var presentation: ({
            "media": {
                "icon": "music_note",
                "text": I18n.tr("Media / Launcher", "island settings: media or launcher slot row"),
                "description": I18n.tr("Search when idle, visualizer when media is playing", "island settings: media slot description")
            },
            "clock": {
                "icon": "schedule",
                "text": I18n.tr("Clock", "island settings: pinned clock row in the home layout"),
                "description": I18n.tr("Current time and date display")
            },
            "weather": {
                "icon": "wb_sunny",
                "text": I18n.tr("Weather", "island settings: weather slot row"),
                "description": SettingsData.weatherEnabled ? I18n.tr("Weather icon and temperature open the weather activity", "island settings: weather slot description") : I18n.tr("Enable weather in Time & Weather to show this shortcut", "island settings: weather slot disabled hint")
            },
            "status": {
                "icon": BatteryService.batteryAvailable ? "battery_full" : "tune",
                "text": I18n.tr("Battery / Control Center", "island settings: battery or control center slot row"),
                "description": BatteryService.batteryAvailable ? I18n.tr("Battery gauge opens Control Center", "island settings: status slot description with battery") : I18n.tr("Tools icon opens Control Center", "island settings: status slot description without battery")
            },
            "volume": {
                "icon": "volume_up",
                "text": I18n.tr("Volume", "island settings: volume slot row"),
                "description": I18n.tr("Current output volume on the home face", "island settings: volume slot description")
            },
            "brightness": {
                "icon": "brightness_6",
                "text": I18n.tr("Brightness", "island settings: brightness slot row"),
                "description": I18n.tr("Current display brightness on the home face", "island settings: brightness slot description")
            },
            "notifications": {
                "icon": "notifications",
                "text": I18n.tr("Notifications", "island settings: notification badge slot row"),
                "description": I18n.tr("Unread notification count beside the clock", "island settings: notification badge description")
            }
        })

    readonly property real rowHeight: 72
    readonly property real rowSpacing: Theme.spacingS
    readonly property real dividerGap: 40

    property var enabledOrder: []
    property var disabledOrder: []
    property string draggingId: ""
    property var dragStartOrder: []
    property string highlightedId: ""
    property bool showHidden: false

    readonly property bool hasHidden: disabledOrder.length > 0
    readonly property real dividerY: enabledOrder.length * (rowHeight + rowSpacing)
    readonly property real totalHeight: {
        const base = enabledOrder.length * (rowHeight + rowSpacing);
        if (!hasHidden)
            return Math.max(0, base - rowSpacing);
        if (!showHidden)
            return base + dividerGap;
        return base + dividerGap + disabledOrder.length * (rowHeight + rowSpacing) - rowSpacing;
    }

    width: parent?.width ?? 0
    height: totalHeight

    function isEnabled(id) {
        const entry = layout.find(g => g.id === id);
        return entry ? entry.enabled : false;
    }

    function rebuild() {
        enabledOrder = layout.filter(g => g.enabled).map(g => g.id);
        disabledOrder = layout.filter(g => !g.enabled).map(g => g.id);
    }

    function slotYForId(id) {
        const enabledIndex = enabledOrder.indexOf(id);
        if (enabledIndex >= 0)
            return enabledIndex * (rowHeight + rowSpacing);
        return dividerY + dividerGap + Math.max(0, disabledOrder.indexOf(id)) * (rowHeight + rowSpacing);
    }

    function beginDrag(id) {
        draggingId = id;
        dragStartOrder = enabledOrder.slice();
    }

    function updateDragTarget(centerY) {
        if (draggingId === "")
            return;
        const pos = Math.max(0, Math.min(Math.floor(centerY / (rowHeight + rowSpacing)), enabledOrder.length - 1));
        const arr = enabledOrder.slice();
        const from = arr.indexOf(draggingId);
        if (from < 0 || from === pos)
            return;
        arr.splice(from, 1);
        arr.splice(pos, 0, draggingId);
        enabledOrder = arr;
    }

    function commit() {
        SettingsData.setIslandHomeLayoutOrder(root.barId, enabledOrder.concat(disabledOrder));
    }

    function endDrag() {
        if (draggingId === "")
            return;
        const changed = JSON.stringify(enabledOrder) !== JSON.stringify(dragStartOrder);
        draggingId = "";
        if (changed)
            commit();
    }

    function moveEnabled(id, delta) {
        const pos = enabledOrder.indexOf(id);
        const next = pos + delta;
        if (pos < 0 || next < 0 || next >= enabledOrder.length)
            return;
        const arr = enabledOrder.slice();
        arr.splice(pos, 1);
        arr.splice(next, 0, id);
        enabledOrder = arr;
        commit();
    }

    onLayoutChanged: rebuild()
    Component.onCompleted: {
        rebuild();
        Qt.callLater(() => {
            if (!root.parent || !root.settingKey)
                return;
            const flickable = QmlUtils.findParentFlickable(root.parent);
            if (flickable)
                SettingsSearchService.registerCard(root.settingKey, root, flickable);
        });
    }
    Component.onDestruction: {
        if (settingKey)
            SettingsSearchService.unregisterCard(settingKey);
    }

    function stepHighlight(dir, move) {
        const order = enabledOrder.concat(disabledOrder);
        if (order.length === 0)
            return;
        if (move && highlightedId !== "" && isEnabled(highlightedId)) {
            moveEnabled(highlightedId, dir);
            return;
        }
        if (highlightedId === "") {
            highlightedId = dir > 0 ? order[0] : order[order.length - 1];
            return;
        }
        const idx = Math.max(0, Math.min(order.length - 1, order.indexOf(highlightedId) + dir));
        highlightedId = order[idx];
    }

    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Up:
            stepHighlight(-1, ctrl);
            event.accepted = true;
            return;
        case Qt.Key_Down:
            stepHighlight(1, ctrl);
            event.accepted = true;
            return;
        case Qt.Key_Space:
        case Qt.Key_Return:
            if (highlightedId === "")
                return;
            SettingsData.setIslandHomeGroupEnabled(root.barId, highlightedId, !isEnabled(highlightedId));
            event.accepted = true;
            return;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.primary, root.isHighlighted ? 0.2 : 0)
        visible: root.isHighlighted
    }

    Behavior on height {
        NumberAnimation {
            duration: Theme.expressiveDurations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
        }
    }

    Item {
        id: hiddenDivider

        width: parent.width
        height: root.dividerGap
        y: root.dividerY
        opacity: root.hasHidden ? 1 : 0
        visible: opacity > 0.01

        Behavior on y {
            NumberAnimation {
                duration: Theme.expressiveDurations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankIcon {
                name: "visibility_off"
                size: 14
                color: Theme.outline
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: I18n.tr("Hidden (%1)", "island settings: hidden groups divider, %1 is count").arg(root.disabledOrder.length)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.outline
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        DankIcon {
            name: root.showHidden ? "expand_less" : "expand_more"
            size: 14
            color: Theme.outline
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showHidden = !root.showHidden
        }
    }

    Repeater {
        model: root.groupIds

        delegate: Item {
            id: rowItem

            required property string modelData

            readonly property var present: root.presentation[modelData]
            readonly property bool isClock: modelData === "clock"
            readonly property bool isEnabled: root.isEnabled(modelData)
            readonly property bool dragging: root.draggingId === modelData
            readonly property bool highlighted: root.highlightedId === modelData
            readonly property bool draggable: isEnabled
            readonly property real surfaceAlphaScale: isClock ? 0.5 : (isEnabled ? 0.7 : 0.4)

            width: root.width
            height: root.rowHeight
            z: dragging ? 100 : (highlighted ? 3 : 1)
            visible: isEnabled || root.showHidden

            Binding {
                target: rowItem
                property: "y"
                value: root.slotYForId(rowItem.modelData)
                when: !rowItem.dragging
                restoreMode: Binding.RestoreNone
            }

            onYChanged: {
                if (dragging)
                    root.updateDragTarget(y + height / 2);
            }

            Behavior on y {
                enabled: !rowItem.dragging
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                }
            }

            Rectangle {
                id: surface

                anchors.fill: parent
                radius: Theme.cornerRadius
                color: surfaceColor.value
                border.width: rowItem.dragging || rowItem.highlighted ? 2 : 1
                border.color: rowItem.dragging || rowItem.highlighted ? Theme.primary : (rowItem.isClock ? Theme.outlineMedium : Theme.outlineHeavy)

                DankColorAnimation {
                    id: surfaceColor

                    to: {
                        if (rowItem.dragging)
                            return Theme.secondaryContainer;
                        return Theme.withAlpha(Theme.surfaceContainerHigh, Theme.floatingWindowForegroundLayers ? Theme.floatingWindowForegroundTransparency * rowItem.surfaceAlphaScale : 0);
                    }
                    duration: Theme.shortDuration
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.primary
                    opacity: dragArea.containsMouse && !rowItem.dragging ? 0.06 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                        }
                    }
                }

                DankIcon {
                    name: "drag_indicator"
                    size: Theme.iconSize - 4
                    color: rowItem.dragging ? Theme.primary : Theme.outline
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: !rowItem.draggable ? 0 : (dragArea.containsMouse || rowItem.dragging || rowItem.highlighted ? 1 : 0.45)
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                        }
                    }
                }

                DankIcon {
                    id: groupIcon

                    name: rowItem.present.icon
                    size: Theme.iconSize
                    color: rowItem.isEnabled ? Theme.primary : Theme.outline
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM * 2 + Theme.iconSize - 4
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                        }
                    }
                }

                Column {
                    anchors.left: groupIcon.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: visibilityButton.left
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS

                    StyledText {
                        text: rowItem.present.text
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: rowItem.isEnabled ? Theme.surfaceText : Theme.outline
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    StyledText {
                        text: rowItem.present.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: rowItem.isEnabled ? Theme.outline : Theme.outlineVariant
                        elide: Text.ElideRight
                        width: parent.width
                        visible: text.length > 0
                    }
                }

                DankIcon {
                    name: "lock"
                    size: 16
                    color: Theme.outline
                    opacity: 0.6
                    anchors.horizontalCenter: visibilityButton.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowItem.isClock
                }

                DankActionButton {
                    id: visibilityButton

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rowItem.isClock
                    buttonSize: 36
                    iconName: rowItem.isEnabled ? "visibility" : "visibility_off"
                    iconSize: 18
                    iconColor: rowItem.isEnabled ? Theme.primary : Theme.outline
                    tooltipText: rowItem.isEnabled ? I18n.tr("Hide", "island settings: hide home group") : I18n.tr("Show", "island settings: show home group")
                    onClicked: {
                        root.forceActiveFocus();
                        root.highlightedId = rowItem.modelData;
                        SettingsData.setIslandHomeGroupEnabled(root.barId, rowItem.modelData, !rowItem.isEnabled);
                    }
                }
            }

            MouseArea {
                id: dragArea

                anchors.fill: parent
                anchors.rightMargin: 48
                hoverEnabled: true
                enabled: rowItem.draggable
                cursorShape: rowItem.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: rowItem
                drag.axis: Drag.YAxis
                drag.minimumY: -rowItem.height
                drag.maximumY: root.height
                drag.smoothed: false
                onPressed: {
                    root.forceActiveFocus();
                    root.highlightedId = rowItem.modelData;
                    root.beginDrag(rowItem.modelData);
                }
                onReleased: root.endDrag()
            }
        }
    }
}
