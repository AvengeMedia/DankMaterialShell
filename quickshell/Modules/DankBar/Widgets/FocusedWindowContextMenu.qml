import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    property var currentWindow: null
    property int processId: 0

    readonly property string appId: currentWindow?.appId || ""
    readonly property string windowTitle: currentWindow?.title || ""
    readonly property string appName: appId ? Paths.getAppName(appId, DesktopEntries.heuristicLookup(appId)) : I18n.tr("Unknown")
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
            implicitHeight: contentColumn.implicitHeight + Theme.spacingS * 2
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
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Row {
                    width: parent.width
                    height: 28
                    spacing: Theme.spacingS

                    IconImage {
                        width: 20
                        height: 20
                        source: Paths.getAppIcon(root.appId, DesktopEntries.heuristicLookup(root.appId))
                        asynchronous: true
                        mipmap: true
                        smooth: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        width: parent.width - 20 - Theme.spacingS
                        text: root.appName
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: [
                        { label: I18n.tr("App ID"), value: root.appId, copyable: !!root.appId },
                        { label: I18n.tr("Title"), value: root.windowTitle || I18n.tr("Untitled"), copyable: !!root.windowTitle },
                        { label: I18n.tr("PID"), value: root.pid > 0 ? root.pid.toString() : I18n.tr("Unavailable"), copyable: root.pid > 0 }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: contentColumn.width
                        height: 40
                        radius: Theme.cornerRadius
                        color: copyArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingXS
                            spacing: Theme.spacingS

                            StyledText {
                                width: 72
                                text: modelData.label
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                width: parent.width - 72 - Theme.spacingS
                                text: modelData.value
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideMiddle
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankRipple {
                            id: copyRipple
                            rippleColor: Theme.surfaceText
                            cornerRadius: parent.radius
                        }

                        MouseArea {
                            id: copyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: modelData.copyable
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: mouse => copyRipple.trigger(mouse.x, mouse.y)
                            onClicked: root.copyValue(modelData.value)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outlineVariant
                }

                Item {
                    visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
                    width: parent.width
                    height: visible ? 32 : 0

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: ruleArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "rule"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Add Window Rule")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankRipple {
                        id: ruleRipple
                        anchors.fill: parent
                        rippleColor: Theme.surfaceText
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: ruleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => ruleRipple.trigger(mouse.x, mouse.y)
                        onClicked: root.addWindowRule()
                    }
                }

                Item {
                    width: parent.width
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: killArea.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "close"
                            size: 16
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

                    DankRipple {
                        id: killRipple
                        anchors.fill: parent
                        rippleColor: Theme.error
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: killArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.pid > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: mouse => killRipple.trigger(mouse.x, mouse.y)
                        onClicked: root.killWindow()
                    }
                }
            }
        }
    }
}
