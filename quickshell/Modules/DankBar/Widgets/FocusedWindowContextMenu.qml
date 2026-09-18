import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Modules.DankBar
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    property var currentWindow: null
    property int processId: 0

    readonly property string appId: currentWindow?.appId || ""
    readonly property string windowTitle: currentWindow?.title || ""
    readonly property string appName: appId ? Paths.getAppName(appId, DesktopEntries.heuristicLookup(Paths.moddedAppId(appId))) : I18n.tr("Unknown")
    readonly property int pid: processId

    layerNamespace: "dms:focused-window-popout"
    popupWidth: 340
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 260
    triggerWidth: 40
    positioning: ""
    shouldBeVisible: false

    function copyValue(value) {
        if (!value)
            return;
        Quickshell.execDetached(["dms", "cl", "copy", value.toString()]);
        ToastService.showInfo(I18n.tr("Copied to clipboard"));
        close();
    }

    function killWindow() {
        if (pid > 0)
            Quickshell.execDetached(["kill", pid.toString()]);
        close();
    }

    function addWindowRule() {
        if (!currentWindow || !PopoutService.windowRuleModalLoader)
            return;
        close();
        PopoutService.windowRuleModalLoader.active = true;
        Qt.callLater(() => {
            if (PopoutService.windowRuleModalLoader.item)
                PopoutService.windowRuleModalLoader.item.show(currentWindow);
        });
    }

    onBackgroundClicked: close()

    content: Component {
        Rectangle {
            id: contentRoot

            implicitWidth: 340
            implicitHeight: contentColumn.implicitHeight + PopoutMetrics.contentPadding * 2
            anchors.fill: parent
            color: "transparent"
            focus: true

            Keys.onEscapePressed: event => {
                root.close();
                event.accepted = true;
            }

            Column {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: PopoutMetrics.contentPadding
                spacing: Theme.spacingXXS

                Row {
                    width: parent.width
                    height: BarMetrics.menuRowHeight
                    spacing: Theme.spacingS

                    IconImage {
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium
                        source: Paths.getAppIcon(root.appId, DesktopEntries.heuristicLookup(root.appId))
                        asynchronous: true
                        mipmap: true
                        smooth: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        width: parent.width - Theme.iconSizeMedium - Theme.spacingS
                        text: root.appName
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Theme.fontWeightMedium
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: [
                        {
                            label: I18n.tr("App ID"),
                            value: root.appId,
                            copyable: !!root.appId
                        },
                        {
                            label: I18n.tr("Title"),
                            value: root.windowTitle || I18n.tr("Untitled"),
                            copyable: !!root.windowTitle
                        },
                        {
                            label: I18n.tr("PID", "Label for the process ID row in the focused window popout"),
                            value: root.pid > 0 ? root.pid.toString() : I18n.tr("Unavailable"),
                            copyable: root.pid > 0
                        }
                    ]

                    delegate: DankListRow {
                        id: copyRow
                        required property var modelData
                        required property int index
                        readonly property real labelWidth: Theme.iconButtonSize + Theme.iconSizeLarge

                        width: contentColumn.width
                        implicitHeight: Theme.listItemHeight
                        firstInGroup: index === 0
                        lastInGroup: index === 2

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingL
                            anchors.rightMargin: Theme.spacingL
                            spacing: Theme.spacingS

                            StyledText {
                                width: copyRow.labelWidth
                                text: copyRow.modelData.label
                                color: copyRow.supportingContentColor
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                width: parent.width - copyRow.labelWidth - Theme.spacingS
                                text: copyRow.modelData.value
                                color: copyRow.contentColor
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideMiddle
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StateLayer {
                            topLeftRadius: copyRow.firstInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
                            topRightRadius: topLeftRadius
                            bottomLeftRadius: copyRow.lastInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
                            bottomRightRadius: bottomLeftRadius
                            enabled: copyRow.modelData.copyable
                            disabled: !copyRow.modelData.copyable
                            onClicked: root.copyValue(copyRow.modelData.value)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Theme.dividerWidth
                    color: Theme.outlineVariant
                }

                Item {
                    visible: CompositorService.supportsWindowRules
                    width: parent.width
                    height: BarMetrics.menuRowHeight

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "rule"
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Add window rule")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StateLayer {
                        cornerRadius: BarMetrics.menuItemRadius
                        onClicked: root.addWindowRule()
                    }
                }

                Item {
                    width: parent.width
                    height: BarMetrics.menuRowHeight

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "close"
                            size: Theme.iconSizeSmall
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Kill Process")
                            color: Theme.error
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StateLayer {
                        cornerRadius: BarMetrics.menuItemRadius
                        stateColor: Theme.error
                        enabled: root.pid > 0
                        disabled: root.pid <= 0
                        onClicked: root.killWindow()
                    }
                }
            }
        }
    }
}
