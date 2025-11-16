import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:confirm-modal"

    property string confirmTitle: ""
    property string confirmMessage: ""
    property string confirmButtonText: "Confirm"
    property string cancelButtonText: "Cancel"
    property color confirmButtonColor: Theme.primary
    property var onConfirm: function () {}
    property var onCancel: function () {}
    property int selectedButton: -1
    property bool keyboardNavigation: false

    function show(title, message, onConfirmCallback, onCancelCallback) {
        confirmTitle = title || ""
        confirmMessage = message || ""
        confirmButtonText = "Confirm"
        cancelButtonText = "Cancel"
        confirmButtonColor = Theme.primary
        onConfirm = onConfirmCallback || (() => {})
        onCancel = onCancelCallback || (() => {})
        selectedButton = -1
        keyboardNavigation = false
        open()
    }

    function showWithOptions(options) {
        confirmTitle = options.title || ""
        confirmMessage = options.message || ""
        confirmButtonText = options.confirmText || "Confirm"
        cancelButtonText = options.cancelText || "Cancel"
        confirmButtonColor = options.confirmColor || Theme.primary
        onConfirm = options.onConfirm || (() => {})
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
                onConfirm()
            }
        }
    }

    shouldBeVisible: false
    allowStacking: true
    width: 350
    height: contentLoader.item ? contentLoader.item.implicitHeight + Theme.spacingM * 2 : 160
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
            modalFocusScope.forceActiveFocus()
            modalFocusScope.focus = true
            shouldHaveFocus = true
        })
    }
    modalFocusScope.Keys.onPressed: function (event) {
        switch (event.key) {
        case Qt.Key_Escape:
            close()
            if (onCancel) {
                onCancel()
            }
            event.accepted = true
            break
        case Qt.Key_Left:
        case Qt.Key_Up:
            keyboardNavigation = true
            selectedButton = 0
            event.accepted = true
            break
        case Qt.Key_Right:
        case Qt.Key_Down:
            keyboardNavigation = true
            selectedButton = 1
            event.accepted = true
            break
        case Qt.Key_N:
            if (event.modifiers & Qt.ControlModifier) {
                keyboardNavigation = true
                selectedButton = (selectedButton + 1) % 2
                event.accepted = true
            }
            break
        case Qt.Key_P:
            if (event.modifiers & Qt.ControlModifier) {
                keyboardNavigation = true
                selectedButton = selectedButton === -1 ? 1 : (selectedButton - 1 + 2) % 2
                event.accepted = true
            }
            break
        case Qt.Key_J:
            if (event.modifiers & Qt.ControlModifier) {
                keyboardNavigation = true
                selectedButton = 1
                event.accepted = true
            }
            break
        case Qt.Key_K:
            if (event.modifiers & Qt.ControlModifier) {
                keyboardNavigation = true
                selectedButton = 0
                event.accepted = true
            }
            break
        case Qt.Key_H:
            if (event.modifiers & Qt.ControlModifier) {
                keyboardNavigation = true
                selectedButton = 0
                event.accepted = true
            }
            break
        case Qt.Key_L:
            if (event.modifiers & Qt.ControlModifier) {
                keyboardNavigation = true
                selectedButton = 1
                event.accepted = true
            }
            break
        case Qt.Key_Tab:
            keyboardNavigation = true
            selectedButton = selectedButton === -1 ? 0 : (selectedButton + 1) % 2
            event.accepted = true
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (selectedButton !== -1) {
                selectButton()
            } else {
                selectedButton = 1
                selectButton()
            }
            event.accepted = true
            break
        }
    }

    content: Component {
        Item {
            anchors.fill: parent
            implicitHeight: mainColumn.implicitHeight

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
                    text: confirmTitle
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
                    text: confirmMessage
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
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
}
