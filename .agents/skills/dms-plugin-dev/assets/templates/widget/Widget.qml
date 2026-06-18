import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var popoutService: null

    // TODO: Read settings reactively
    property string displayText: pluginData?.text || "Hello"

    Connections {
        target: pluginService
        function onPluginDataChanged(changedId) {
            if (changedId !== pluginId) return
            displayText = pluginService.loadPluginData(pluginId, "text", "Hello")
        }
    }

    horizontalBarPill: Component {
        StyledRect {
            width: label.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: label
                anchors.centerIn: parent
                text: root.displayText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: parent.widgetThickness
            height: label.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: label
                anchors.centerIn: parent
                text: root.displayText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                rotation: 90
            }
        }
    }

    // TODO: Uncomment and customize popout content
    // popoutWidth: 350
    // popoutHeight: 300
    // popoutContent: Component {
    //     PopoutComponent {
    //         headerText: "My Widget"
    //         showCloseButton: true
    //
    //         Column {
    //             width: parent.width
    //             spacing: Theme.spacingM
    //
    //             StyledText {
    //                 text: "Popout content here"
    //                 color: Theme.surfaceText
    //             }
    //         }
    //     }
    // }
}
