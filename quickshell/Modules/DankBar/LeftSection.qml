import QtQuick
import qs.Common

Item {
    id: root

    property var widgetsModel: null
    property var components: null
    property bool noBackground: false
    required property var axis
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property real barSpacing: 4
    property var barConfig: null
    property bool overrideAxisLayout: false
    property bool forceVerticalLayout: false

    readonly property bool isVertical: overrideAxisLayout ? forceVerticalLayout : (axis?.isVertical ?? false)

    implicitHeight: layoutLoader.item ? layoutLoader.item.implicitHeight : 0
    implicitWidth: layoutLoader.item ? layoutLoader.item.implicitWidth : 0

    Loader {
        id: layoutLoader
        anchors.fill: parent
        sourceComponent: root.isVertical ? columnComp : rowComp
    }

    Component {
        id: rowComp
        Row {
            readonly property real widgetSpacing: {
                const baseSpacing = noBackground ? 2 : Theme.spacingXS;
                const outlineThickness = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
                return baseSpacing + (outlineThickness * 2);
            }
            spacing: widgetSpacing
            Repeater {
                id: rowRepeater
                model: root.widgetsModel
                Item {
                    readonly property real rowSpacing: parent.widgetSpacing
                    property var itemData: modelData
                    width: widgetLoader.item ? widgetLoader.item.width : 0
                    height: widgetLoader.item ? widgetLoader.item.height : 0
                    WidgetHost {
                        id: widgetLoader
                        anchors.verticalCenter: parent.verticalCenter
                        widgetId: itemData.widgetId
                        widgetData: itemData
                        spacerSize: itemData.size || 20
                        components: root.components
                        isInColumn: false
                        axis: root.axis
                        section: "left"
                        parentScreen: root.parentScreen
                        widgetThickness: root.widgetThickness
                        barThickness: root.barThickness
                        barSpacing: root.barSpacing
                        barConfig: root.barConfig
                        isFirst: index === 0
                        isLast: index === rowRepeater.count - 1
                        sectionSpacing: parent.rowSpacing
                        isLeftBarEdge: true
                        isRightBarEdge: false
                    }
                }
            }
        }
    }

    Component {
        id: columnComp
        Column {
            width: parent.width
            readonly property real widgetSpacing: {
                const baseSpacing = noBackground ? 2 : Theme.spacingXS;
                const outlineThickness = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
                return baseSpacing + (outlineThickness * 2);
            }
            spacing: widgetSpacing
            Repeater {
                id: columnRepeater
                model: root.widgetsModel
                Item {
                    width: parent.width
                    readonly property real columnSpacing: parent.widgetSpacing
                    property var itemData: modelData
                    height: widgetLoader.item ? widgetLoader.item.height : 0
                    WidgetHost {
                        id: widgetLoader
                        anchors.horizontalCenter: parent.horizontalCenter
                        widgetId: itemData.widgetId
                        widgetData: itemData
                        spacerSize: itemData.size || 20
                        components: root.components
                        isInColumn: true
                        axis: root.axis
                        section: "left"
                        parentScreen: root.parentScreen
                        widgetThickness: root.widgetThickness
                        barThickness: root.barThickness
                        barSpacing: root.barSpacing
                        barConfig: root.barConfig
                        isFirst: index === 0
                        isLast: index === columnRepeater.count - 1
                        sectionSpacing: parent.columnSpacing
                        isTopBarEdge: true
                        isBottomBarEdge: false
                    }
                }
            }
        }
    }
}
