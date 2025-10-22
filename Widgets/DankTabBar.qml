import QtQuick
import qs.Common
import qs.Widgets

FocusScope {
    id: tabBar

    property alias model: tabRepeater.model
    property int currentIndex: 0
    property int spacing: Theme.spacingL
    property int tabHeight: 56
    property bool showIcons: true
    property bool equalWidthTabs: true
    property bool enableArrowNavigation: true
    property Item nextFocusTarget: null
    property Item previousFocusTarget: null

    signal tabClicked(int index)
    signal actionTriggered(int index)

    focus: false
    activeFocusOnTab: true
    height: tabHeight

    KeyNavigation.tab: nextFocusTarget
    KeyNavigation.down: nextFocusTarget
    KeyNavigation.backtab: previousFocusTarget
    KeyNavigation.up: previousFocusTarget

    Keys.onPressed: (event) => {
        if (!tabBar.activeFocus || tabRepeater.count === 0)
            return

        function findSelectableIndex(startIndex, step) {
            let idx = startIndex
            for (let i = 0; i < tabRepeater.count; i++) {
                idx = (idx + step + tabRepeater.count) % tabRepeater.count
                const item = tabRepeater.itemAt(idx)
                if (item && !item.isAction)
                    return idx
            }
            return -1
        }

        const goToIndex = (nextIndex) => {
            if (nextIndex >= 0 && nextIndex !== tabBar.currentIndex) {
                tabBar.currentIndex = nextIndex
                tabBar.tabClicked(nextIndex)
            }
        }

        const resolveTarget = (item) => {
            if (!item)
                return null

            if (item.focusTarget)
                return resolveTarget(item.focusTarget)

            return item
        }

        const focusItem = (item) => {
            const target = resolveTarget(item)
            if (!target)
                return false

            if (target.requestFocus) {
                Qt.callLater(() => target.requestFocus())
                return true
            }

            if (target.forceActiveFocus) {
                Qt.callLater(() => target.forceActiveFocus())
                return true
            }

            return false
        }

        if (event.key === Qt.Key_Right && tabBar.enableArrowNavigation) {
            const baseIndex = (tabBar.currentIndex >= 0 && tabBar.currentIndex < tabRepeater.count) ? tabBar.currentIndex : -1
            const nextIndex = findSelectableIndex(baseIndex, 1)
            if (nextIndex >= 0) {
                goToIndex(nextIndex)
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Left && tabBar.enableArrowNavigation) {
            const baseIndex = (tabBar.currentIndex >= 0 && tabBar.currentIndex < tabRepeater.count) ? tabBar.currentIndex : 0
            const nextIndex = findSelectableIndex(baseIndex, -1)
            if (nextIndex >= 0) {
                goToIndex(nextIndex)
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
            if (focusItem(tabBar.previousFocusTarget)) {
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
            if (focusItem(tabBar.nextFocusTarget)) {
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Up) {
            if (focusItem(tabBar.previousFocusTarget)) {
                event.accepted = true
            }
        }
    }

    Row {
        id: tabRow
        anchors.fill: parent
        spacing: tabBar.spacing

        Repeater {
            id: tabRepeater

            Item {
                id: tabItem
                property bool isAction: modelData && modelData.isAction === true
                property bool isActive: !isAction && tabBar.currentIndex === index
                property bool hasIcon: tabBar.showIcons && modelData && modelData.icon && modelData.icon.length > 0
                property bool hasText: modelData && modelData.text && modelData.text.length > 0

                width: tabBar.equalWidthTabs ? (tabBar.width - tabBar.spacing * Math.max(0, tabRepeater.count - 1)) / Math.max(1, tabRepeater.count) : Math.max(contentCol.implicitWidth + Theme.spacingXL, 64)
                height: tabBar.tabHeight

                Column {
                    id: contentCol
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: modelData.icon || ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: Theme.iconSize
                        color: tabItem.isActive ? Theme.primary : Theme.surfaceText
                        visible: hasIcon
                    }

                    StyledText {
                        text: modelData.text || ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Theme.fontSizeMedium
                        color: tabItem.isActive ? Theme.primary : Theme.surfaceText
                        font.weight: tabItem.isActive ? Font.Medium : Font.Normal
                        visible: hasText
                    }
                }

                Rectangle {
                    id: stateLayer
                    anchors.fill: parent
                    color: Theme.surfaceTint
                    opacity: tabArea.pressed ? 0.12 : (tabArea.containsMouse ? 0.08 : 0)
                    visible: opacity > 0
                    radius: Theme.cornerRadius
                    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tabItem.isAction) {
                            tabBar.actionTriggered(index)
                        } else {
                            tabBar.tabClicked(index)
                        }
                    }
                }

            }
        }
    }

    Rectangle {
        id: indicator
        y: parent.height + 7
        height: 3
        width: 60
        topLeftRadius: Theme.cornerRadius
        topRightRadius: Theme.cornerRadius
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: Theme.primary
        visible: false

        property bool animationEnabled: false
        property bool initialSetupComplete: false

        Behavior on x {
            enabled: indicator.animationEnabled
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on width {
            enabled: indicator.animationEnabled
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        y: parent.height + 10
        color: Theme.outlineStrong
    }

    function updateIndicator(enableAnimation = true) {
        if (tabRepeater.count === 0 || currentIndex < 0 || currentIndex >= tabRepeater.count) {
            return
        }

        const item = tabRepeater.itemAt(currentIndex)
        if (!item || item.isAction) {
            return
        }

        const tabPos = item.mapToItem(tabBar, 0, 0)
        const tabCenterX = tabPos.x + item.width / 2
        const indicatorWidth = 60

        if (tabPos.x < 10 && currentIndex > 0) {
            Qt.callLater(() => updateIndicator(enableAnimation))
            return
        }

        indicator.animationEnabled = enableAnimation
        indicator.width = indicatorWidth
        indicator.x = tabCenterX - indicatorWidth / 2
        indicator.visible = true
    }

    onCurrentIndexChanged: {
        if (indicator.initialSetupComplete) {
            Qt.callLater(() => updateIndicator(true))
        } else {
            Qt.callLater(() => {
                updateIndicator(false)
                indicator.initialSetupComplete = true
            })
        }
    }
    onWidthChanged: Qt.callLater(() => updateIndicator(indicator.initialSetupComplete))
}