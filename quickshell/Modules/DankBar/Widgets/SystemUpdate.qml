import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false
    readonly property bool hasUpdates: SystemUpdateService.updateCount > 0
    readonly property bool isChecking: SystemUpdateService.isChecking
    readonly property bool shouldHide: SettingsData.updaterHideWidget && !hasUpdates && !isChecking && !SystemUpdateService.hasError

    opacity: shouldHide ? 0 : 1

    states: [
        State {
            name: "hidden_horizontal"
            when: root.shouldHide && !isVerticalOrientation
            PropertyChanges {
                target: root
                width: 0
            }
        },
        State {
            name: "hidden_vertical"
            when: root.shouldHide && isVerticalOrientation
            PropertyChanges {
                target: root
                height: 0
            }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation {
                properties: "width,height"
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    ]

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Ref {
        service: SystemUpdateService
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? root.widgetThickness : updaterIcon.implicitWidth
            implicitHeight: root.widgetThickness

            DankIcon {
                id: statusIcon
                anchors.centerIn: parent
                visible: root.isVerticalOrientation
                name: {
                    if (root.isChecking)
                        return "refresh";
                    if (SystemUpdateService.hasError)
                        return "error";
                    if (root.hasUpdates)
                        return "system_update_alt";
                    return "check_circle";
                }
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                color: {
                    if (SystemUpdateService.hasError)
                        return Theme.error;
                    if (root.hasUpdates)
                        return Theme.primary;
                    return root.isActive ? Theme.primary : Theme.surfaceText;
                }

                RotationAnimation {
                    id: rotationAnimation
                    target: statusIcon
                    property: "rotation"
                    from: 0
                    to: 360
                    duration: 1000
                    running: root.isChecking
                    loops: Animation.Infinite

                    onRunningChanged: {
                        if (!running) {
                            statusIcon.rotation = 0;
                        }
                    }
                }
            }

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Theme.error
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: (barConfig?.noBackground ?? false) ? 0 : 6
                anchors.topMargin: (barConfig?.noBackground ?? false) ? 0 : 6
                visible: root.isVerticalOrientation && root.hasUpdates && !root.isChecking
            }

            Row {
                id: updaterIcon
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                visible: !root.isVerticalOrientation

                DankIcon {
                    id: statusIconHorizontal
                    anchors.verticalCenter: parent.verticalCenter
                    name: {
                        if (root.isChecking)
                            return "refresh";
                        if (SystemUpdateService.hasError)
                            return "error";
                        if (root.hasUpdates)
                            return "system_update_alt";
                        return "check_circle";
                    }
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.noBackground)
                    color: {
                        if (SystemUpdateService.hasError)
                            return Theme.error;
                        if (root.hasUpdates)
                            return Theme.primary;
                        return root.isActive ? Theme.primary : Theme.surfaceText;
                    }

                    RotationAnimation {
                        id: rotationAnimationHorizontal
                        target: statusIconHorizontal
                        property: "rotation"
                        from: 0
                        to: 360
                        duration: 1000
                        running: root.isChecking
                        loops: Animation.Infinite

                        onRunningChanged: {
                            if (!running) {
                                statusIconHorizontal.rotation = 0;
                            }
                        }
                    }
                }

                StyledText {
                    id: countText
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemUpdateService.updateCount.toString()
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    visible: root.hasUpdates && !root.isChecking
                }
            }
        }
    }

    MouseArea {
        z: 1
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
            if (popoutTarget && popoutTarget.setTriggerPosition) {
                const globalPos = root.visualContent.mapToItem(null, 0, 0);
                const currentScreen = parentScreen || Screen;
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, root.visualWidth);
                popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen);
            }
            root.clicked();
        }
    }
}
