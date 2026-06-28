pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    focus: true
    property string highlightedId: ""

    readonly property var __presentation: ({
            "overview": {
                "icon": "dashboard",
                "text": I18n.tr("Overview"),
                "description": I18n.tr("Clock, calendar, system info and profile")
            },
            "media": {
                "icon": "music_note",
                "text": I18n.tr("Media"),
                "description": I18n.tr("Now playing and media controls")
            },
            "wallpaper": {
                "icon": "wallpaper",
                "text": I18n.tr("Wallpapers"),
                "description": I18n.tr("Browse and set wallpapers")
            },
            "weather": {
                "icon": "wb_sunny",
                "text": I18n.tr("Weather"),
                "description": SettingsData.weatherEnabled ? I18n.tr("Forecast and conditions") : I18n.tr("Hidden until weather is enabled")
            },
            "settings": {
                "icon": "settings",
                "text": I18n.tr("Settings"),
                "description": I18n.tr("Shortcut that opens this settings window")
            }
        })

    // Stable model: the canonical id list never reorders, so the Repeater keeps
    // its delegates alive across commits (preserving focus for keyboard reorder)
    readonly property var tabIds: SettingsData._dashTabIds
    readonly property var tabState: SettingsData.getDashTabs()
    readonly property int enabledContentCount: tabState.filter(t => t.enabled && t.id !== "settings").length

    function presentationFor(id) {
        return __presentation[id] ?? {
            "icon": "tab",
            "text": id,
            "description": ""
        };
    }
    function isEnabled(id) {
        const t = tabState.find(t => t.id === id);
        return t ? t.enabled : false;
    }

    readonly property real rowHeight: 70
    readonly property real rowSpacing: Theme.spacingS
    readonly property real dividerGap: 40

    property var enabledOrder: []
    property var disabledOrder: []
    property string draggingId: ""
    property var dragStartOrder: []

    readonly property bool hasHidden: disabledOrder.length > 0
    readonly property real dividerY: enabledOrder.length * (rowHeight + rowSpacing)
    readonly property real totalHeight: {
        const base = enabledOrder.length * (rowHeight + rowSpacing);
        if (!hasHidden)
            return Math.max(0, base - rowSpacing);
        return base + dividerGap + disabledOrder.length * (rowHeight + rowSpacing) - rowSpacing;
    }

    function rebuild() {
        const en = [];
        const dis = [];
        for (var i = 0; i < tabState.length; i++) {
            if (tabState[i].enabled)
                en.push(tabState[i].id);
            else
                dis.push(tabState[i].id);
        }
        enabledOrder = en;
        disabledOrder = dis;
    }

    onTabStateChanged: rebuild()
    Component.onCompleted: rebuild()

    function slotYForId(id) {
        const p = enabledOrder.indexOf(id);
        if (p >= 0)
            return p * (rowHeight + rowSpacing);
        const k = disabledOrder.indexOf(id);
        return dividerY + dividerGap + Math.max(0, k) * (rowHeight + rowSpacing);
    }

    function beginDrag(id) {
        draggingId = id;
        dragStartOrder = enabledOrder.slice();
    }

    function updateDragTarget(centerY) {
        if (draggingId === "")
            return;
        var pos = Math.floor(centerY / (rowHeight + rowSpacing));
        pos = Math.max(0, Math.min(pos, enabledOrder.length - 1));
        const arr = enabledOrder.slice();
        const d = arr.indexOf(draggingId);
        if (d < 0 || d === pos)
            return;
        arr.splice(d, 1);
        arr.splice(pos, 0, draggingId);
        enabledOrder = arr;
    }

    function commit() {
        SettingsData.setDashTabOrder(enabledOrder.concat(disabledOrder));
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

    function canHide(id) {
        return !isEnabled(id) || id === "settings" || enabledContentCount > 1;
    }

    // Keyboard nav is handled at the tab root (not per-row activeFocusOnTab)
    Keys.onPressed: function (event) {
        const order = enabledOrder.concat(disabledOrder);
        if (order.length === 0)
            return;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            const dir = event.key === Qt.Key_Down ? 1 : -1;
            if (ctrl) {
                if (highlightedId !== "" && isEnabled(highlightedId))
                    moveEnabled(highlightedId, dir);
            } else if (highlightedId === "") {
                highlightedId = dir > 0 ? order[0] : order[order.length - 1];
            } else {
                var idx = order.indexOf(highlightedId);
                idx = Math.max(0, Math.min(order.length - 1, idx + dir));
                highlightedId = order[idx];
            }
            event.accepted = true;
        } else if ((event.key === Qt.Key_Space || event.key === Qt.Key_Return) && highlightedId !== "") {
            if (canHide(highlightedId))
                SettingsData.setDashTabEnabled(highlightedId, !isEnabled(highlightedId));
            event.accepted = true;
        }
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: headerContent.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                Column {
                    id: headerContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        id: headerText
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "space_dashboard"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Dank Dash")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            height: 1
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            id: resetButton
                            width: resetContentRow.implicitWidth + Theme.spacingM * 2
                            height: 28
                            radius: Theme.cornerRadius
                            color: resetArea.containsMouse ? Theme.surfacePressed : Theme.surfaceVariant
                            border.width: 0
                            Layout.alignment: Qt.AlignVCenter

                            Row {
                                id: resetContentRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "refresh"
                                    size: 14
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Reset")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: resetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsData.resetDashTabs()
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }

                    StyledText {
                        text: I18n.tr("Drag to reorder or click to hide tabs. Use ↑/↓ to highlight a tab and Ctrl+↑/↓ to move it.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: root.totalHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                Item {
                    id: reorderArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    height: root.totalHeight

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
                        y: root.dividerY + (root.rowSpacing / 2)
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
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "visibility_off"
                                size: 14
                                color: Theme.outline
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Hidden")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.outline
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: parent.width - x
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Repeater {
                        model: root.tabIds

                        delegate: Item {
                            id: rowItem
                            required property int index
                            required property string modelData

                            readonly property var present: root.presentationFor(modelData)
                            readonly property bool isEnabled: root.isEnabled(modelData)
                            readonly property bool dragging: root.draggingId === modelData
                            readonly property bool highlighted: root.highlightedId === modelData
                            readonly property bool canHide: root.canHide(modelData)

                            width: reorderArea.width
                            height: root.rowHeight
                            z: dragging ? 100 : (highlighted ? 3 : 1)

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

                            Item {
                                id: content
                                anchors.fill: parent
                                scale: rowItem.dragging ? 1.02 : 1.0
                                transformOrigin: Item.Center

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Rectangle {
                                    id: surface
                                    anchors.fill: parent
                                    radius: rowItem.dragging ? Theme.cornerRadius + 6 : Theme.cornerRadius
                                    color: {
                                        if (rowItem.dragging)
                                            return Theme.secondaryContainer;
                                        const base = Theme.surfaceContainer;
                                        return Qt.rgba(base.r, base.g, base.b, rowItem.isEnabled ? 0.7 : 0.4);
                                    }
                                    border.width: rowItem.dragging ? 2 : 1
                                    border.color: rowItem.dragging ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                                    Behavior on radius {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                        }
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
                                        opacity: (dragArea.containsMouse && !rowItem.dragging) ? 0.06 : 0
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                            }
                                        }
                                    }

                                    DankIcon {
                                        id: dragHandle
                                        name: "drag_indicator"
                                        size: Theme.iconSize - 4
                                        color: rowItem.dragging ? Theme.primary : Theme.outline
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: rowItem.isEnabled ? ((dragArea.containsMouse || rowItem.dragging || rowItem.highlighted) ? 1.0 : 0.45) : 0
                                        visible: opacity > 0.01

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                            }
                                        }
                                    }

                                    DankIcon {
                                        id: tabIcon
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
                                        anchors.left: tabIcon.right
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.right: visibilityButton.left
                                        anchors.rightMargin: Theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

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
                                            color: rowItem.isEnabled ? Theme.outline : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
                                            elide: Text.ElideRight
                                            width: parent.width
                                            visible: text.length > 0
                                        }
                                    }

                                    DankActionButton {
                                        id: visibilityButton
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        buttonSize: 36
                                        iconName: rowItem.isEnabled ? "visibility" : "visibility_off"
                                        iconSize: 18
                                        iconColor: rowItem.isEnabled ? Theme.primary : Theme.outline
                                        enabled: rowItem.canHide
                                        onClicked: {
                                            root.forceActiveFocus();
                                            root.highlightedId = rowItem.modelData;
                                            SettingsData.setDashTabEnabled(rowItem.modelData, !rowItem.isEnabled);
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -2
                                radius: Theme.cornerRadius + 2
                                color: "transparent"
                                border.width: 2
                                border.color: Theme.primary
                                opacity: rowItem.highlighted && !rowItem.dragging ? 0.6 : 0
                                visible: opacity > 0.01

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                    }
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                anchors.rightMargin: 48
                                hoverEnabled: true
                                enabled: rowItem.isEnabled
                                cursorShape: rowItem.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                drag.target: rowItem
                                drag.axis: Drag.YAxis
                                drag.minimumY: -rowItem.height
                                drag.maximumY: reorderArea.height
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
            }
        }
    }
}
