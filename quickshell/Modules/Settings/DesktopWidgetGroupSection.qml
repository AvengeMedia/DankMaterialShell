pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: section

    required property Item coordinator
    property var groupId: null
    property string groupName: ""
    property bool isUngrouped: false
    property bool showHeader: true
    property bool collapsed: false
    property var instances: []
    property var expandedStates: ({})

    readonly property string sectionKey: groupId ? groupId : ""
    readonly property bool dragActive: coordinator.dragActive
    readonly property bool isDropTarget: dragActive && coordinator.dragTargetValid && coordinator.dragTargetKey === sectionKey
    readonly property int dropIndex: isDropTarget ? coordinator.dragTargetIndex : -1

    signal collapseToggled(string key)
    signal expandedToggled(string instanceId, bool expanded)
    signal duplicateRequested(string instanceId)
    signal deleteRequested(string instanceId)
    signal dragStarted(string instanceId, var groupId, int index, var widgetData, var globalCenter)
    signal dragMoved(var globalCenter)
    signal dragEnded

    function insertionIndexForGlobalY(gy) {
        const n = cardRepeater.count;
        for (var i = 0; i < n; i++) {
            const it = cardRepeater.itemAt(i);
            if (!it)
                continue;
            const midGlobal = it.mapToItem(coordinator, 0, it.height / 2).y;
            if (gy < midGlobal)
                return i;
        }
        return n;
    }

    function indicatorY() {
        if (cardRepeater.count === 0)
            return bodyContainer.height / 2;
        if (dropIndex >= cardRepeater.count) {
            const last = cardRepeater.itemAt(cardRepeater.count - 1);
            return last ? last.y + last.height + Theme.spacingM / 2 : 0;
        }
        const it = cardRepeater.itemAt(Math.max(0, dropIndex));
        return it ? it.y - Theme.spacingM / 2 : 0;
    }

    width: parent.width
    spacing: Theme.spacingM

    Rectangle {
        width: parent.width
        height: 44
        radius: Theme.cornerRadius
        visible: section.showHeader
        color: section.isDropTarget ? Theme.primaryContainer : Theme.surfaceContainer
        border.width: section.isDropTarget ? 2 : 0
        border.color: Theme.primary

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingS

            DankIcon {
                name: section.collapsed ? "expand_more" : "expand_less"
                size: Theme.iconSize
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            DankIcon {
                name: section.isUngrouped ? "widgets" : "folder"
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: section.groupName
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "(" + section.instances.length + ")"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: section.collapseToggled(section.sectionKey)
        }
    }

    Item {
        id: bodyContainer

        property real leftPadding: section.showHeader ? Theme.spacingM : 0

        width: parent.width
        height: section.collapsed ? 0 : Math.max(cardsColumn.height, emptyDropZone.visible ? emptyDropZone.height : 0)
        visible: !section.collapsed
        clip: false

        Column {
            id: cardsColumn
            x: bodyContainer.leftPadding
            width: parent.width - bodyContainer.leftPadding
            spacing: Theme.spacingM

            Repeater {
                id: cardRepeater
                model: ScriptModel {
                    objectProp: "id"
                    values: section.instances
                }

                Item {
                    id: delegateItem
                    required property var modelData
                    required property int index

                    readonly property string instanceIdRef: modelData.id
                    readonly property var liveInstanceData: (SettingsData.desktopWidgetInstances || []).find(inst => inst.id === instanceIdRef) ?? modelData
                    readonly property bool beingDragged: section.dragActive && coordinator.dragInstanceId === instanceIdRef

                    width: cardsColumn.width
                    height: instanceCard.height
                    opacity: beingDragged ? 0.35 : 1

                    DesktopWidgetInstanceCard {
                        id: instanceCard
                        width: parent.width
                        headerLeftPadding: 20
                        instanceData: delegateItem.liveInstanceData
                        isExpanded: section.expandedStates[delegateItem.instanceIdRef] ?? false

                        onExpandedChanged: {
                            if (expanded === (section.expandedStates[delegateItem.instanceIdRef] ?? false))
                                return;
                            section.expandedToggled(delegateItem.instanceIdRef, expanded);
                        }

                        onDuplicateRequested: section.duplicateRequested(delegateItem.instanceIdRef)
                        onDeleteRequested: section.deleteRequested(delegateItem.instanceIdRef)
                    }

                    MouseArea {
                        id: dragArea
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: 40
                        height: 50
                        hoverEnabled: true
                        cursorShape: dragArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true

                        property bool dragging: false

                        onPressed: mouse => {
                            dragArea.dragging = true;
                            const def = DesktopWidgetRegistry.getWidget(delegateItem.liveInstanceData.widgetType);
                            const widgetData = {
                                "icon": def?.icon ?? "widgets",
                                "name": delegateItem.liveInstanceData.name ?? def?.name ?? delegateItem.liveInstanceData.widgetType
                            };
                            section.dragStarted(delegateItem.instanceIdRef, section.groupId, delegateItem.index, widgetData, dragArea.mapToItem(section.coordinator, mouse.x, mouse.y));
                        }
                        onPositionChanged: mouse => {
                            if (!dragArea.dragging)
                                return;
                            section.dragMoved(dragArea.mapToItem(section.coordinator, mouse.x, mouse.y));
                        }
                        onReleased: {
                            if (!dragArea.dragging)
                                return;
                            dragArea.dragging = false;
                            section.dragEnded();
                        }
                        onCanceled: {
                            if (!dragArea.dragging)
                                return;
                            dragArea.dragging = false;
                            section.dragEnded();
                        }
                    }

                    DankIcon {
                        x: Theme.spacingL - 2
                        y: Theme.spacingL + (Theme.iconSize / 2) - (size / 2)
                        name: "drag_indicator"
                        size: 18
                        color: Theme.outline
                        opacity: dragArea.containsMouse || dragArea.pressed ? 1 : 0.5
                    }
                }
            }
        }

        Rectangle {
            id: emptyDropZone
            x: bodyContainer.leftPadding
            width: parent.width - bodyContainer.leftPadding
            height: 56
            radius: Theme.cornerRadius
            visible: section.dragActive && section.instances.length === 0
            color: section.isDropTarget ? Theme.primaryContainer : "transparent"
            border.width: 1
            border.color: section.isDropTarget ? Theme.primary : Theme.outline

            StyledText {
                anchors.centerIn: parent
                text: I18n.tr("Drop here")
                font.pixelSize: Theme.fontSizeSmall
                color: section.isDropTarget ? Theme.primary : Theme.surfaceVariantText
            }
        }

        Rectangle {
            width: cardsColumn.width
            x: bodyContainer.leftPadding
            height: 3
            radius: 2
            color: Theme.primary
            visible: section.isDropTarget && section.instances.length > 0
            y: section.indicatorY() - 1.5
        }
    }
}
