pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property var currentTab: NotepadStorageService.tabs.length > NotepadStorageService.currentTabIndex ? NotepadStorageService.tabs[NotepadStorageService.currentTabIndex] : null
    property bool contentLoaded: false
    property int draggedIndex: -1
    property int dropTargetIndex: -1
    property bool suppressShiftAnimation: false
    readonly property real tabItemSize: 128 + Theme.spacingXS

    signal tabSwitched(int tabIndex)
    signal tabClosed(int tabIndex)
    signal newTabRequested

    function hasUnsavedChangesForTab(tab) {
        if (!tab)
            return false;

        if (tab.id === currentTab?.id) {
            return root.parent?.hasUnsavedChanges ? root.parent.hasUnsavedChanges() : false;
        }
        return false;
    }

    spacing: Theme.spacingXS

    Row {
        width: parent.width
        height: 36
        spacing: Theme.spacingXS

        ScrollView {
            width: parent.width - newTabButton.width - Theme.spacingXS
            height: parent.height
            clip: true

            ScrollBar.horizontal.visible: false
            ScrollBar.vertical.visible: false

            Row {
                spacing: Theme.spacingXS

                Repeater {
                    model: NotepadStorageService.tabs

                    delegate: Item {
                        id: delegateItem
                        required property int index
                        required property var modelData

                        readonly property bool isActive: NotepadStorageService.currentTabIndex === index
                        readonly property bool isHovered: tabMouseArea.containsMouse && !closeMouseArea.containsMouse
                        readonly property real tabWidth: 128
                        property bool longPressing: false
                        property bool dragging: false
                        property point dragStartPos: Qt.point(0, 0)
                        property int targetIndex: -1
                        property int originalIndex: -1
                        property real dragAxisOffset: 0

                        Timer {
                            id: longPressTimer
                            interval: 200
                            repeat: false
                            onTriggered: {
                                if (NotepadStorageService.tabs.length > 1) {
                                    delegateItem.longPressing = true
                                }
                            }
                        }

                        readonly property real shiftOffset: {
                            if (root.draggedIndex < 0)
                                return 0
                            if (index === root.draggedIndex)
                                return 0
                            var dragIdx = root.draggedIndex
                            var dropIdx = root.dropTargetIndex
                            var myIdx = index
                            var shiftAmount = root.tabItemSize
                            if (dropIdx < 0)
                                return 0
                            if (dragIdx < dropIdx && myIdx > dragIdx && myIdx <= dropIdx)
                                return -shiftAmount
                            if (dragIdx > dropIdx && myIdx >= dropIdx && myIdx < dragIdx)
                                return shiftAmount
                            return 0
                        }

                        width: tabWidth
                        height: 32
                        z: dragging ? 100 : 0

                        transform: Translate {
                            x: shiftOffset
                            Behavior on x {
                                enabled: !root.suppressShiftAnimation
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Item {
                            id: tabVisual
                            anchors.fill: parent
                            z: 1
                            layer.enabled: dragging
                            layer.smooth: true

                            transform: Translate {
                                x: dragging ? dragAxisOffset : 0
                            }

                            Rectangle {
                                id: tabRect
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: isActive ? Theme.primaryPressed : isHovered ? Theme.primaryHoverLight : Theme.withAlpha(Theme.primaryPressed, 0)
                                border.width: isActive || dragging ? 0 : 1
                                border.color: dragging ? Theme.primary : Theme.outlineMedium
                                clip: true

                                Row {
                                    id: tabContent
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        id: tabText
                                        width: parent.width - (tabCloseButton.visible ? tabCloseButton.width + Theme.spacingXS : 0)
                                        text: {
                                            var prefix = ""
                                            if (hasUnsavedChangesForTab(modelData)) {
                                                prefix = "● "
                                            }
                                            return prefix + (modelData.title || "Untitled")
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: isActive ? Theme.primary : Theme.surfaceText
                                        font.weight: isActive ? Font.Medium : Font.Normal
                                        elide: Text.ElideMiddle
                                        maximumLineCount: 1
                                        wrapMode: Text.NoWrap
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        id: tabCloseButton
                                        width: 20
                                        height: 20
                                        radius: Theme.cornerRadius
                                        color: closeMouseArea.containsMouse ? Theme.surfaceTextHover : Theme.withAlpha(Theme.surfaceTextHover, 0)
                                        visible: NotepadStorageService.tabs.length > 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        DankIcon {
                                            name: "close"
                                            size: 14
                                            color: Theme.surfaceTextMedium
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: closeMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            z: 100

                                            onClicked: root.tabClosed(index)
                                        }
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: dragging || longPressing
                            cursorShape: dragging || longPressing ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton

                            onPressed: mouse => {
                                if (mouse.button === Qt.LeftButton && NotepadStorageService.tabs.length > 1) {
                                    delegateItem.dragStartPos = Qt.point(mouse.x, mouse.y)
                                    longPressTimer.start()
                                }
                            }

                            onReleased: mouse => {
                                longPressTimer.stop()
                                var wasDragging = delegateItem.dragging
                                var didReorder = wasDragging && delegateItem.targetIndex >= 0 && delegateItem.targetIndex !== delegateItem.originalIndex

                                if (didReorder) {
                                    root.suppressShiftAnimation = true
                                    NotepadStorageService.reorderTab(delegateItem.originalIndex, delegateItem.targetIndex)
                                }

                                delegateItem.longPressing = false
                                delegateItem.dragging = false
                                delegateItem.dragAxisOffset = 0
                                delegateItem.targetIndex = -1
                                delegateItem.originalIndex = -1
                                root.draggedIndex = -1
                                root.dropTargetIndex = -1
                                if (didReorder) {
                                    Qt.callLater(() => {
                                        root.suppressShiftAnimation = false
                                    })
                                }

                                if (wasDragging || mouse.button !== Qt.LeftButton)
                                    return
                                root.tabSwitched(index)
                            }

                            onPositionChanged: mouse => {
                                if (delegateItem.longPressing && !delegateItem.dragging) {
                                    var distance = Math.sqrt(Math.pow(mouse.x - delegateItem.dragStartPos.x, 2) + Math.pow(mouse.y - delegateItem.dragStartPos.y, 2))
                                    if (distance > 5) {
                                        delegateItem.dragging = true
                                        delegateItem.targetIndex = index
                                        delegateItem.originalIndex = index
                                        root.draggedIndex = index
                                        root.dropTargetIndex = index
                                    }
                                }

                                if (!delegateItem.dragging)
                                    return

                                var axisOffset = mouse.x - delegateItem.dragStartPos.x
                                delegateItem.dragAxisOffset = axisOffset

                                var itemSize = root.tabItemSize
                                var rawSlot = axisOffset / itemSize
                                var slotOffset = rawSlot >= 0
                                    ? Math.floor(rawSlot + 0.4)
                                    : Math.ceil(rawSlot - 0.4)
                                var tabCount = NotepadStorageService.tabs.length
                                var newTargetIndex = Math.max(0, Math.min(tabCount - 1, delegateItem.originalIndex + slotOffset))

                                if (newTargetIndex !== delegateItem.targetIndex) {
                                    delegateItem.targetIndex = newTargetIndex
                                    root.dropTargetIndex = newTargetIndex
                                }
                            }
                        }
                    }
                }
            }
        }

        DankActionButton {
            id: newTabButton
            width: 32
            height: 32
            iconName: "add"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            onClicked: root.newTabRequested()
        }
    }
}
