pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property bool isSettingsRow: true

    property string tab: ""
    property var tags: []
    property string settingKey: ""

    property string title: ""
    property string description: ""
    property string iconName: ""
    property bool checked: false

    property alias resetStore: header.resetStore
    property alias resetKeys: header.resetKeys
    property alias modified: header.modified

    default property alias content: expandedContent.data
    readonly property bool hasContent: expandedContent.height > 0
    readonly property bool standalone: !(parent?.isSettingsGroupHost ?? false)

    signal toggled(bool checked)

    width: parent?.width ?? 0
    height: column.height

    Rectangle {
        anchors.fill: parent
        radius: Theme.groupedListOuterRadius
        color: SettingsMetrics.rowColor
        visible: root.standalone
    }

    Column {
        id: column
        width: parent.width
        spacing: 0

        SettingsToggleRow {
            id: header
            groupItem: root
            width: parent.width
            tab: root.tab
            tags: root.tags
            settingKey: root.settingKey
            text: root.title
            description: root.description
            iconName: root.iconName
            checked: root.checked
            enabled: root.enabled
            paintBackground: false
            onToggled: value => root.toggled(value)
        }

        Item {
            width: parent.width
            height: root.hasContent ? expandedContent.height + Theme.spacingM : 0

            Column {
                id: expandedContent
                enabled: root.checked
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: SettingsMetrics.rowPaddingH
                anchors.rightMargin: SettingsMetrics.rowPaddingH
                spacing: Theme.spacingM
            }
        }
    }
}
