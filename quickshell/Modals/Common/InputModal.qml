import QtQuick
import Quickshell.Hyprland
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:input-modal"

    property string inputTitle: ""
    property string inputMessage: ""
    property string confirmButtonText: "Confirm"
    property string cancelButtonText: "Cancel"
    property string placeholderText: ""
    property color confirmButtonColor: Theme.primary
    property color inputFieldColor: Theme.primary
    property var onConfirm: function (input: string) {}
    property var onCancel: function () {}
    property int selectedButton: -1
    property bool keyboardNavigation: false

    function show(title, message, onConfirmCallback, onCancelCallback) {
        inputTitle = title || ""
        inputMessage = message || ""
        confirmButtonText = "Confirm"
        cancelButtonText = "Cancel"
        confirmButtonColor = Theme.primary
        onConfirm = onConfirmCallback || ((_) => {})
        onCancel = onCancelCallback || (() => {})
        selectedButton = -1
        keyboardNavigation = false
        open()
    }

    function showWithOptions(options) {
        inputTitle = options.title || ""
        inputMessage = options.message || ""
        confirmButtonText = options.confirmText || "Confirm"
        cancelButtonText = options.cancelText || "Cancel"
        confirmButtonColor = options.confirmColor || Theme.primary
        onConfirm = options.onConfirm || ((_) => {})
        onCancel = options.onCancel || (() => {})
        selectedButton = -1
        keyboardNavigation = false
        open()
    }

    function selectButton() {
        close()
        if (selectedButton === 0) {
            if (onCancel) {
                onCancel()
            }
        } else {
            if (onConfirm) {
                onConfirm(inputField.text)
            }
        }
    }

    HyprlandFocusGrab {
        windows: [root.contentWindow]
        active: CompositorService.isHyprland && root.shouldHaveFocus
    }

    shouldBeVisible: false
    allowStacking: true
    modalWidth: 350
    modalHeight: inputPanel ? inputPanel.implicitHeight + Theme.spacingM * 2 : 160
    enableShadow: true
    shouldHaveFocus: true
    onBackgroundClicked: {
        close()
        if (onCancel) {
            onCancel()
        }
    }
    onOpened: {
        Qt.callLater(function () {
            shouldHaveFocus = true
            Qt.callLater(() => {
                if (inputPanel && inputPanel.inputField) {
                    inputPanel.inputField.forceActiveFocus();
                }
            })
        })
    }

    directContent: Item {
        id: inputPanel

        anchors.fill: parent
        implicitHeight: mainColumn.implicitHeight

        property alias inputField: inputField

        Keys.onPressed: {
            if ((event.key === Qt.Key_Left) || (event.key === Qt.Key_Up)) {
                keyboardNavigation = true
                selectedButton = 0
                event.accepted = true
            } else if ((event.key === Qt.Key_Right) || (event.key === Qt.Key_Down)) {
                keyboardNavigation = true
                selectedButton = 1
                event.accepted = true
            } else if ((event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier))) {
                keyboardNavigation = true
                selectedButton = 0
                event.accepted = true
            } else if ((event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) ||
                    (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                keyboardNavigation = true
                selectedButton = 1
                event.accepted = true
            } else if ((event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                keyboardNavigation = true
                selectedButton = 0
                event.accepted = true
            } else if ((event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
                keyboardNavigation = true
                selectedButton = (selectedButton + 1) % 2
                event.accepted = true
            } else if ((event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
                keyboardNavigation = true
                selectedButton = selectedButton === -1 ? 1 : (selectedButton - 1 + 2) % 2
                event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
                keyboardNavigation = true
                selectedButton = selectedButton === -1 ? 0 : (selectedButton + 1) % 2
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                close()
                if (onCancel) onCancel()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                selectButton()
                event.accepted = true
            }
        }

        Column {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            anchors.topMargin: Theme.spacingL
            spacing: 0

            StyledText {
                text: inputTitle
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                width: 1
                height: Theme.spacingL
            }

            StyledText {
                text: inputMessage
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            DankTextField {
                id: inputField
                
                width: parent.width
                height: 48
                cornerRadius: Theme.cornerRadius
                backgroundColor: Theme.surfaceContainerHigh
                normalBorderColor: Theme.outlineMedium
                focusedBorderColor: inputFieldColor
                showClearButton: true
                focus: true
                font.pixelSize: Theme.fontSizeMedium
                placeholderText: placeholderText
                keyForwardTargets: [inputPanel]
            }

            Item {
                width: 1
                height: Theme.spacingL * 1.5
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM

                Rectangle {
                    width: 120
                    height: 40
                    radius: Theme.cornerRadius
                    color: {
                        if (keyboardNavigation && selectedButton === 0) {
                            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                        } else if (cancelButton.containsMouse) {
                            return Theme.surfacePressed
                        } else {
                            return Theme.surfaceVariantAlpha
                        }
                    }
                    border.color: (keyboardNavigation && selectedButton === 0) ? Theme.primary : "transparent"
                    border.width: (keyboardNavigation && selectedButton === 0) ? 1 : 0

                    StyledText {
                        text: cancelButtonText
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: cancelButton

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selectedButton = 0
                            selectButton()
                        }
                    }
                }

                Rectangle {
                    width: 120
                    height: 40
                    radius: Theme.cornerRadius
                    color: {
                        const baseColor = confirmButtonColor
                        if (keyboardNavigation && selectedButton === 1) {
                            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 1)
                        } else if (confirmButton.containsMouse) {
                            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.9)
                        } else {
                            return baseColor
                        }
                    }
                    border.color: (keyboardNavigation && selectedButton === 1) ? "white" : "transparent"
                    border.width: (keyboardNavigation && selectedButton === 1) ? 1 : 0

                    StyledText {
                        text: confirmButtonText
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.primaryText
                        font.weight: Font.Medium
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: confirmButton

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selectedButton = 1
                            selectButton()
                        }
                    }
                }
            }

            Item {
                width: 1
                height: Theme.spacingL
            }
        }
    }
}
