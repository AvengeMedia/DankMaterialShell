import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var grid: null
    property int sourceIndex: -1
    property var widgetData: null
    property Component widgetComponent: null
    property bool isSlider: false

    property real slotX: 0
    property real slotY: 0
    property real cellW: 100
    property real cellH: 60

    property bool dragging: !!grid && grid.draggingSourceIndex === sourceIndex

    signal removeWidget(int index)
    signal toggleWidgetSize(int index)
    signal configRequested(int index, var widgetData, var anchor)

    width: cellW
    height: cellH
    z: dragging ? 10000 : 1

    Binding {
        target: root
        property: "x"
        value: root.slotX
        when: !root.dragging
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root
        property: "y"
        value: root.slotY
        when: !root.dragging
        restoreMode: Binding.RestoreNone
    }

    onXChanged: {
        if (dragging && grid)
            grid.updateDragTarget(x + width / 2, y + height / 2);
    }
    onYChanged: {
        if (dragging && grid)
            grid.updateDragTarget(x + width / 2, y + height / 2);
    }

    Behavior on x {
        enabled: !root.dragging
        NumberAnimation {
            duration: Theme.expressiveDurations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }
    Behavior on y {
        enabled: !root.dragging
        NumberAnimation {
            duration: Theme.expressiveDurations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    Rectangle {
        id: dragIndicator
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.primary
        border.width: root.dragging ? 2 : 0
        radius: Theme.cornerRadius
        opacity: root.dragging ? 0.8 : 1.0
        z: root.dragging ? 10000 : 1

        Behavior on border.width {
            NumberAnimation {
                duration: 150
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    Loader {
        id: widgetLoader
        anchors.fill: parent
        sourceComponent: root.widgetComponent
        property var widgetData: root.widgetData
        property int widgetIndex: root.sourceIndex
        property int globalWidgetIndex: root.sourceIndex
        property int widgetWidth: root.widgetData?.width || 50

        MouseArea {
            id: editModeBlocker
            anchors.fill: parent
            enabled: true
            acceptedButtons: Qt.AllButtons
            onPressed: function (mouse) {
                mouse.accepted = true;
            }
            onWheel: function (wheel) {
                wheel.accepted = true;
            }
            z: 100
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: Qt.OpenHandCursor
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.smoothed: false

        onPressed: function (mouse) {
            cursorShape = Qt.ClosedHandCursor;
            if (root.grid)
                root.grid.beginDrag(root.sourceIndex);
        }

        onReleased: function (mouse) {
            cursorShape = Qt.OpenHandCursor;
            if (root.grid)
                root.grid.endDrag();
        }
    }

    Rectangle {
        id: removeButton
        width: 16
        height: 16
        radius: 8
        color: Theme.error
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -4
        z: 10

        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: 12
            color: Theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeWidget(root.sourceIndex)
        }
    }

    SizeControls {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: -6
        z: 10
        currentSize: root.widgetData?.width || 50
        isSlider: root.isSlider
        widgetIndex: root.sourceIndex
        onSizeChanged: newSize => {
            var widgets = SettingsData.controlCenterWidgets.slice();
            if (root.sourceIndex >= 0 && root.sourceIndex < widgets.length) {
                widgets[root.sourceIndex].width = newSize;
                SettingsData.set("controlCenterWidgets", widgets);
            }
        }
    }

    readonly property bool hasConfigMenu: widgetData?.id === "diskUsage"

    Rectangle {
        id: configButton
        width: 16
        height: 16
        radius: 8
        color: Theme.primary
        anchors.top: removeButton.top
        anchors.right: removeButton.left
        anchors.rightMargin: 4
        visible: root.hasConfigMenu
        z: 10

        DankIcon {
            anchors.centerIn: parent
            name: "settings"
            size: 12
            color: Theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.configRequested(root.sourceIndex, root.widgetData, configButton)
        }
    }

    Rectangle {
        id: dragHandle
        width: 16
        height: 12
        radius: 2
        color: Theme.primary
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 4
        z: 15
        opacity: root.dragging ? 1.0 : 0.7

        DankIcon {
            anchors.centerIn: parent
            name: "drag_indicator"
            size: 10
            color: Theme.primaryText
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.primaryHoverLight
        radius: Theme.cornerRadius
        border.color: "transparent"
        border.width: 0
        z: -1
    }
}
