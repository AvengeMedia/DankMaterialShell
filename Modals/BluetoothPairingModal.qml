import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:bluetooth-pairing"

    property string deviceName: ""
    property string deviceAddress: ""
    property string requestType: ""
    property string token: ""
    property int passkey: 0
    property string pinInput: ""
    property string passkeyInput: ""

    function show(pairingData) {
        token = pairingData.token || ""
        deviceName = pairingData.deviceName || ""
        deviceAddress = pairingData.deviceAddr || ""
        requestType = pairingData.requestType || ""
        passkey = pairingData.passkey || 0
        pinInput = ""
        passkeyInput = ""

        open()
        Qt.callLater(() => {
            if (contentLoader.item) {
                if (requestType === "pin" && contentLoader.item.pinInputField) {
                    contentLoader.item.pinInputField.forceActiveFocus()
                } else if (requestType === "passkey" && contentLoader.item.passkeyInputField) {
                    contentLoader.item.passkeyInputField.forceActiveFocus()
                }
            }
        })
    }

    shouldBeVisible: false
    width: 420
    height: contentLoader.item ? contentLoader.item.implicitHeight + Theme.spacingM * 2 : 240

    onShouldBeVisibleChanged: () => {
        if (!shouldBeVisible) {
            pinInput = ""
            passkeyInput = ""
        }
    }

    onOpened: {
        Qt.callLater(() => {
            if (contentLoader.item) {
                if (requestType === "pin" && contentLoader.item.pinInputField) {
                    contentLoader.item.pinInputField.forceActiveFocus()
                } else if (requestType === "passkey" && contentLoader.item.passkeyInputField) {
                    contentLoader.item.passkeyInputField.forceActiveFocus()
                }
            }
        })
    }

    onBackgroundClicked: () => {
        DMSService.bluetoothCancelPairing(token)
        close()
        pinInput = ""
        passkeyInput = ""
    }

    content: Component {
        FocusScope {
            id: pairingContent

            property alias pinInputField: pinInputField
            property alias passkeyInputField: passkeyInputField

            anchors.fill: parent
            focus: true
            implicitHeight: mainColumn.implicitHeight

            Keys.onEscapePressed: event => {
                DMSService.bluetoothCancelPairing(token)
                close()
                pinInput = ""
                passkeyInput = ""
                event.accepted = true
            }

            Column {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                anchors.topMargin: Theme.spacingM
                spacing: requestType === "pin" || requestType === "passkey" ? Theme.spacingM : Theme.spacingS

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Pair Bluetooth Device")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: {
                            if (requestType === "confirm")
                                return I18n.tr("Confirm passkey for ") + deviceName
                            if (requestType === "authorize")
                                return I18n.tr("Authorize pairing with ") + deviceName
                            if (requestType.startsWith("authorize-service"))
                                return I18n.tr("Authorize service for ") + deviceName
                            if (requestType === "pin")
                                return I18n.tr("Enter PIN for ") + deviceName
                            if (requestType === "passkey")
                                return I18n.tr("Enter passkey for ") + deviceName
                            return deviceName
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        width: parent.width - 40
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: Theme.surfaceHover
                    border.color: pinInputField.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: pinInputField.activeFocus ? 2 : 1
                    visible: requestType === "pin"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: () => {
                            pinInputField.forceActiveFocus()
                        }
                    }

                    DankTextField {
                        id: pinInputField

                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        text: pinInput
                        placeholderText: I18n.tr("Enter PIN")
                        backgroundColor: "transparent"
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                            pinInput = text
                        }
                        onAccepted: () => {
                            submitPairing()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: Theme.surfaceHover
                    border.color: passkeyInputField.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: passkeyInputField.activeFocus ? 2 : 1
                    visible: requestType === "passkey"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: () => {
                            passkeyInputField.forceActiveFocus()
                        }
                    }

                    DankTextField {
                        id: passkeyInputField

                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        text: passkeyInput
                        placeholderText: I18n.tr("Enter 6-digit passkey")
                        backgroundColor: "transparent"
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                            passkeyInput = text
                        }
                        onAccepted: () => {
                            submitPairing()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    visible: requestType === "confirm"

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            text: I18n.tr("Passkey:")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: String(passkey).padStart(6, "0")
                            font.pixelSize: Theme.fontSizeXLarge
                            color: Theme.surfaceText
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 36

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

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
                                onClicked: () => {
                                    DMSService.bluetoothCancelPairing(token)
                                    close()
                                    pinInput = ""
                                    passkeyInput = ""
                                }
                            }
                        }

                        Rectangle {
                            width: Math.max(80, pairText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: pairArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                            enabled: {
                                if (requestType === "pin")
                                    return pinInput.length > 0
                                if (requestType === "passkey")
                                    return passkeyInput.length === 6
                                return true
                            }
                            opacity: enabled ? 1 : 0.5

                            StyledText {
                                id: pairText

                                anchors.centerIn: parent
                                text: {
                                    if (requestType === "confirm")
                                        return I18n.tr("Confirm")
                                    if (requestType === "authorize" || requestType.startsWith("authorize-service"))
                                        return I18n.tr("Authorize")
                                    return I18n.tr("Pair")
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.background
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: pairArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: parent.enabled
                                onClicked: () => {
                                    submitPairing()
                                }
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

            DankActionButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                iconName: "close"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                onClicked: () => {
                    DMSService.bluetoothCancelPairing(token)
                    close()
                    pinInput = ""
                    passkeyInput = ""
                }
            }
        }
    }

    function submitPairing() {
        const secrets = {}

        if (requestType === "pin") {
            secrets["pin"] = pinInput
        } else if (requestType === "passkey") {
            secrets["passkey"] = passkeyInput
        } else if (requestType === "confirm" || requestType === "authorize" || requestType.startsWith("authorize-service")) {
            secrets["decision"] = "yes"
        }

        DMSService.bluetoothSubmitPairing(token, secrets, true, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Pairing failed"), response.error)
            }
        })

        close()
        pinInput = ""
        passkeyInput = ""
    }
}
