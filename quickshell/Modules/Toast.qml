import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WlrLayershell.namespace: "dms:toast"

    property var modelData
    property bool shouldBeVisible: false
    property real frozenWidth: 0
    readonly property string copiedText: I18n.tr("Copied!")

    readonly property real dpr: modelData ? CompositorService.getScreenScale(modelData) : 1
    readonly property real shadowBuffer: 5
    readonly property real toastY: Theme.barHeight - 4 + (SettingsData.barConfigs[0]?.spacing ?? 4) + 2

    Connections {
        target: ToastService
        function onToastVisibleChanged() {
            if (ToastService.toastVisible) {
                shouldBeVisible = true;
                visible = true;
            } else {
                frozenWidth = toast.width;
                shouldBeVisible = false;
                closeTimer.restart();
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.mediumDuration + 50
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false;
            }
        }
    }

    screen: modelData
    visible: shouldBeVisible
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    readonly property real toastWidth: shouldBeVisible ? Math.min(900, messageText.implicitWidth + statusIcon.width + Theme.spacingM + (ToastService.hasDetails ? (expandButton.width + closeButton.width + 4) : (ToastService.currentLevel === ToastService.levelError ? closeButton.width + Theme.spacingS : 0)) + Theme.spacingL * 2 + Theme.spacingM * 2) : frozenWidth
    readonly property real toastHeight: toastContent.height + Theme.spacingL * 2

    anchors {
        top: true
        left: true
    }

    WlrLayershell.margins {
        left: Math.max(0, Theme.snap((modelData?.width ?? 1920) / 2 - toastWidth / 2 - shadowBuffer, dpr))
        top: Math.max(0, Theme.snap(toastY - shadowBuffer, dpr))
    }

    implicitWidth: toastWidth + (shadowBuffer * 2)
    implicitHeight: toastHeight + (shadowBuffer * 2)

    Rectangle {
        id: toast

        property bool expanded: false

        Connections {
            target: ToastService
            function onResetToastState() {
                toast.expanded = false;
            }
        }

        x: shadowBuffer
        y: shadowBuffer
        width: root.toastWidth
        height: root.toastHeight
        color: {
            switch (ToastService.currentLevel) {
            case ToastService.levelError:
                return Theme.error;
            case ToastService.levelWarn:
                return Theme.warning;
            case ToastService.levelInfo:
                return Theme.surfaceContainer;
            default:
                return Theme.surfaceContainer;
            }
        }
        radius: Theme.cornerRadius
        opacity: shouldBeVisible ? 1 : 0

        Column {
            id: toastContent

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Theme.spacingL
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: Math.max(Theme.iconSize + 8, messageText.implicitHeight)

                DankIcon {
                    id: statusIcon
                    name: {
                        switch (ToastService.currentLevel) {
                        case ToastService.levelError:
                            return "error";
                        case ToastService.levelWarn:
                            return "warning";
                        case ToastService.levelInfo:
                            return "info";
                        default:
                            return "info";
                        }
                    }
                    size: Theme.iconSize
                    color: {
                        switch (ToastService.currentLevel) {
                        case ToastService.levelError:
                        case ToastService.levelWarn:
                            return SessionData.isLightMode ? Theme.surfaceText : Theme.background;
                        default:
                            return Theme.surfaceText;
                        }
                    }
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: messageText
                    text: ToastService.currentMessage
                    font.pixelSize: Theme.fontSizeMedium
                    color: {
                        switch (ToastService.currentLevel) {
                        case ToastService.levelError:
                        case ToastService.levelWarn:
                            return SessionData.isLightMode ? Theme.surfaceText : Theme.background;
                        default:
                            return Theme.surfaceText;
                        }
                    }
                    font.weight: Font.Medium
                    anchors.left: statusIcon.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: ToastService.hasDetails ? expandButton.left : parent.right
                    anchors.rightMargin: ToastService.hasDetails ? Theme.spacingS : 0
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                DankActionButton {
                    id: expandButton
                    iconName: toast.expanded ? "expand_less" : "expand_more"
                    iconSize: Theme.iconSize
                    iconColor: {
                        switch (ToastService.currentLevel) {
                        case ToastService.levelError:
                        case ToastService.levelWarn:
                            return SessionData.isLightMode ? Theme.surfaceText : Theme.background;
                        default:
                            return Theme.surfaceText;
                        }
                    }
                    buttonSize: Theme.iconSize + 8
                    anchors.right: closeButton.left
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ToastService.hasDetails

                    onClicked: {
                        toast.expanded = !toast.expanded;
                        if (toast.expanded) {
                            ToastService.stopTimer();
                        } else {
                            ToastService.restartTimer();
                        }
                    }
                }

                DankActionButton {
                    id: closeButton
                    iconName: "close"
                    iconSize: Theme.iconSize
                    iconColor: {
                        switch (ToastService.currentLevel) {
                        case ToastService.levelError:
                        case ToastService.levelWarn:
                            return SessionData.isLightMode ? Theme.surfaceText : Theme.background;
                        default:
                            return Theme.surfaceText;
                        }
                    }
                    buttonSize: Theme.iconSize + 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ToastService.hasDetails || ToastService.currentLevel === ToastService.levelError

                    onClicked: {
                        ToastService.hideToast();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: detailsColumn.height + Theme.spacingS * 2
                color: ToastService.currentDetails.length > 0 ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
                radius: Theme.cornerRadius / 2
                visible: toast.expanded && ToastService.hasDetails
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    id: detailsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    Item {
                        width: parent.width - Theme.spacingS * 2
                        height: detailsText.implicitHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: ToastService.currentDetails.length > 0

                        StyledText {
                            id: detailsText
                            text: ToastService.currentDetails
                            font.pixelSize: Theme.fontSizeSmall
                            color: {
                                switch (ToastService.currentLevel) {
                                case ToastService.levelError:
                                case ToastService.levelWarn:
                                    return SessionData.isLightMode ? Theme.surfaceText : Theme.background;
                                default:
                                    return Theme.surfaceText;
                                }
                            }
                            anchors.left: parent.left
                            anchors.right: copyDetailsButton.left
                            anchors.rightMargin: Theme.spacingS
                            wrapMode: Text.Wrap
                        }

                        DankActionButton {
                            id: copyDetailsButton
                            iconName: "content_copy"
                            iconSize: Theme.iconSizeSmall
                            iconColor: {
                                switch (ToastService.currentLevel) {
                                case ToastService.levelError:
                                case ToastService.levelWarn:
                                    return SessionData.isLightMode ? Theme.surfaceText : Theme.background;
                                default:
                                    return Theme.surfaceText;
                                }
                            }
                            buttonSize: Theme.iconSizeSmall + 8
                            anchors.right: parent.right
                            anchors.top: parent.top

                            property bool showTooltip: false

                            onClicked: {
                                Quickshell.execDetached(["dms", "cl", "copy", ToastService.currentDetails]);
                                showTooltip = true;
                                detailsTooltipTimer.start();
                            }

                            Timer {
                                id: detailsTooltipTimer
                                interval: 1500
                                onTriggered: copyDetailsButton.showTooltip = false
                            }

                            Rectangle {
                                visible: copyDetailsButton.showTooltip
                                width: detailsTooltipLabel.implicitWidth + 16
                                height: detailsTooltipLabel.implicitHeight + 8
                                color: Theme.surfaceContainer
                                radius: Theme.cornerRadius
                                border.width: 1
                                border.color: Theme.outlineMedium
                                y: -height - 4
                                x: -width / 2 + copyDetailsButton.width / 2

                                StyledText {
                                    id: detailsTooltipLabel
                                    anchors.centerIn: parent
                                    text: root.copiedText
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - Theme.spacingS * 2
                        height: commandText.height + Theme.spacingS
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: Theme.cornerRadius / 2
                        visible: ToastService.currentCommand.length > 0

                        StyledText {
                            id: commandText
                            text: ToastService.currentCommand
                            font.pixelSize: Theme.fontSizeSmall
                            color: {
                                switch (ToastService.currentLevel) {
                                case ToastService.levelError:
                                case ToastService.levelWarn:
                                    return SessionData.isLightMode ? Theme.surfaceText : Theme.background;
                                default:
                                    return Theme.surfaceText;
                                }
                            }
                            isMonospace: true
                            anchors.left: parent.left
                            anchors.right: copyButton.visible ? copyButton.left : parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingS / 2
                            anchors.rightMargin: Theme.spacingS / 2
                            wrapMode: Text.Wrap
                        }

                        DankActionButton {
                            id: copyButton
                            iconName: "content_copy"
                            iconSize: Theme.iconSizeSmall
                            iconColor: {
                                switch (ToastService.currentLevel) {
                                case ToastService.levelError:
                                case ToastService.levelWarn:
                                    return SessionData.isLightMode ? Theme.surfaceText : Theme.background;
                                default:
                                    return Theme.surfaceText;
                                }
                            }
                            buttonSize: Theme.iconSizeSmall + 8
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: Theme.spacingS / 2
                            visible: ToastService.currentCommand.length > 0

                            property bool showTooltip: false

                            onClicked: {
                                Quickshell.execDetached(["dms", "cl", "copy", ToastService.currentCommand]);
                                showTooltip = true;
                                tooltipTimer.start();
                            }

                            Timer {
                                id: tooltipTimer
                                interval: 1500
                                onTriggered: copyButton.showTooltip = false
                            }

                            Rectangle {
                                visible: copyButton.showTooltip
                                width: tooltipLabel.implicitWidth + 16
                                height: tooltipLabel.implicitHeight + 8
                                color: Theme.surfaceContainer
                                radius: Theme.cornerRadius
                                border.width: 1
                                border.color: Theme.outlineMedium
                                y: -height - 4
                                x: -width / 2 + copyButton.width / 2

                                StyledText {
                                    id: tooltipLabel
                                    anchors.centerIn: parent
                                    text: root.copiedText
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: !ToastService.hasDetails
            onClicked: ToastService.hideToast()
        }

        ElevationShadow {
            anchors.fill: parent
            z: -1
            level: Theme.elevationLevel3
            fallbackOffset: 6
            targetRadius: toast.radius
            targetColor: toast.color
            shadowOpacity: Theme.elevationLevel3 && Theme.elevationLevel3.alpha !== undefined ? Theme.elevationLevel3.alpha : 0.3
            shadowEnabled: Theme.elevationEnabled
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on height {
            enabled: false
        }

        Behavior on width {
            enabled: false
        }
    }

    mask: Region {
        item: toast
    }
}
