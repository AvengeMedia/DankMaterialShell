import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    readonly property int inputFieldHeight: Theme.fontSizeMedium + Theme.spacingL * 2

    objectName: "workspaceRenameModal"
    title: I18n.tr("Rename Workspace")
    minimumSize: Qt.size(400, 180)
    maximumSize: Qt.size(400, 180)
    color: Theme.surfaceContainer
    visible: false

    function show(name) {
        nameInput.text = name;
        visible = true;
        Qt.callLater(() => nameInput.forceActiveFocus());
    }

    function hide() {
        visible = false;
    }

    function submitAndClose() {
        renameWorkspace(nameInput.text);
        hide();
    }

    function renameWorkspace(name) {
        if (CompositorService.isNiri) {
            NiriService.renameWorkspace(name);
        } else if (CompositorService.isHyprland) {
            HyprlandService.renameWorkspace(name);
        } else {
            console.warn("WorkspaceRenameModal: rename not supported for this compositor");
        }
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => nameInput.forceActiveFocus());
        }
    }

    FocusScope {
        id: contentFocusScope

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            hide();
            event.accepted = true;
        }

        Keys.onReturnPressed: {
            submitAndClose();
            event.accepted = true;
        }

        Column {
            id: contentCol
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingM

            Item {
                width: parent.width
                height: Math.max(headerCol.height, buttonRow.height)

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()

                    Column {
                        id: headerCol
                        width: parent.width

                        StyledText {
                            text: I18n.tr("Enter a new name for this workspace")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceTextMedium
                            width: parent.width
                        }
                    }
                }

                Row {
                    id: buttonRow
                    anchors.right: parent.right
                    spacing: Theme.spacingXS

                    DankActionButton {
                        visible: windowControls.supported && windowControls.canMaximize
                        iconName: root.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: hide()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: inputFieldHeight
                radius: Theme.cornerRadius
                color: Theme.surfaceHover
                border.color: nameInput.activeFocus ? Theme.primary : Theme.outlineStrong
                border.width: nameInput.activeFocus ? 2 : 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: nameInput.forceActiveFocus()
                }

                DankTextField {
                    id: nameInput

                    anchors.fill: parent
                    font.pixelSize: Theme.fontSizeMedium
                    textColor: Theme.surfaceText
                    placeholderText: I18n.tr("Workspace name")
                    backgroundColor: "transparent"
                    enabled: root.visible
                    onAccepted: submitAndClose()
                }
            }

            Item {
                width: parent.width
                height: 40

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    Rectangle {
                        width: Math.max(70, cancelText.contentWidth + Theme.spacingM * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: cancelArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                        border.color: Theme.surfaceVariantAlpha
                        border.width: 1

                        StyledText {
                            id: cancelText
                            anchors.centerIn: parent
                            text: I18n.tr("Cancel")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hide()
                        }
                    }

                    Rectangle {
                        width: Math.max(80, renameText.contentWidth + Theme.spacingM * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: renameArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                        StyledText {
                            id: renameText
                            anchors.centerIn: parent
                            text: I18n.tr("Rename")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.background
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: renameArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: submitAndClose()
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }

    IpcHandler {
        target: "workspace-rename"

        function open(): string {
            const ws = NiriService.workspaces[NiriService.focusedWorkspaceId];
            show(ws?.name || "");
            return "WORKSPACE_RENAME_MODAL_OPENED";
        }

        function close(): string {
            hide();
            return "WORKSPACE_RENAME_MODAL_CLOSED";
        }
    }
}
