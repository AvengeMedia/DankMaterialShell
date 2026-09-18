import QtQuick

BarSection {
    id: root

    property alias widgetLayoutLoader: layoutLoader

    onXChanged: refreshBlur()
    onYChanged: refreshBlur()

    implicitHeight: layoutLoader.item ? layoutLoader.item.implicitHeight : 0
    implicitWidth: layoutLoader.item ? layoutLoader.item.implicitWidth : 0

    onSegmentedChanged: rolesTimer.restart()

    function updateRoles() {
        const repeater = layoutLoader.item?.repeater ?? null;
        if (!repeater)
            return;
        const entries = [];
        const participating = [];
        for (let index = 0; index < repeater.count; index++) {
            const wrapper = repeater.itemAt(index);
            entries.push(wrapper?.itemData ?? null);
            participating.push(participation(wrapper, wrapper?.visible ?? false, wrapper?.widgetItem ?? null));
        }
        applyRoles(entries, participating);
    }

    Timer {
        id: rolesTimer
        interval: 0
        repeat: false
        onTriggered: root.updateRoles()
    }

    Loader {
        id: layoutLoader
        anchors.fill: parent
        sourceComponent: root.isVertical ? columnComponent : rowComponent
        onLoaded: rolesTimer.restart()
    }

    Component {
        id: rowComponent

        Row {
            readonly property int widgetCount: rowRepeater.count
            readonly property alias repeater: rowRepeater
            spacing: root.widgetSpacing
            anchors.right: root.section === "right" && parent ? parent.right : undefined

            Repeater {
                id: rowRepeater
                model: root.widgetsModel
                delegate: widgetComponent
                onCountChanged: rolesTimer.restart()
            }
        }
    }

    Component {
        id: columnComponent

        Column {
            readonly property int widgetCount: columnRepeater.count
            readonly property alias repeater: columnRepeater
            width: parent.width
            spacing: root.widgetSpacing

            Repeater {
                id: columnRepeater
                model: root.widgetsModel
                delegate: widgetComponent
                onCountChanged: rolesTimer.restart()
            }
        }
    }

    Component {
        id: widgetComponent

        Item {
            property var itemData: modelData
            readonly property var widgetItem: widgetLoader.item
            readonly property bool participates: visible && width > 0 && height > 0

            visible: widgetLoader.active && widgetLoader.widgetEnabled
            width: root.isVertical ? root.width : (widgetLoader.item ? widgetLoader.item.width : 0)
            height: widgetLoader.item ? widgetLoader.item.height : 0
            onXChanged: {
                if (!root.isVertical)
                    root.refreshBlur();
            }
            onYChanged: {
                if (root.isVertical)
                    root.refreshBlur();
            }
            onParticipatesChanged: rolesTimer.restart()
            onWidgetItemChanged: rolesTimer.restart()

            SectionWidget {
                id: widgetLoader

                anchors.verticalCenter: !root.isVertical ? parent.verticalCenter : undefined
                anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
                occurrenceOrder: index
                sectionContext: root
                widgetData: itemData
                isFirst: index === 0
                isLast: index === (parent?.parent?.widgetCount ?? 0) - 1
            }
        }
    }
}
