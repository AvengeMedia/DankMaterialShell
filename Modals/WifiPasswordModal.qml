import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:wifi-password"

    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property string wifiUsernameInput: ""
    property bool requiresEnterprise: false

    property string wifiAnonymousIdentityInput: ""
    property string wifiDomainInput: ""

    property bool isPromptMode: false
    property string promptToken: ""
    property string promptReason: ""
    property var promptFields: []
    property string promptSetting: ""

    property bool isVpnPrompt: false
    property string connectionName: ""
    property string vpnServiceType: ""
    property string connectionType: ""

    function show(ssid) {
        wifiPasswordSSID = ssid
        wifiPasswordInput = ""
        wifiUsernameInput = ""
        wifiAnonymousIdentityInput = ""
        wifiDomainInput = ""
        isPromptMode = false
        promptToken = ""
        promptReason = ""
        promptFields = []
        promptSetting = ""
        isVpnPrompt = false
        connectionName = ""
        vpnServiceType = ""
        connectionType = ""

        const network = NetworkService.wifiNetworks.find(n => n.ssid === ssid)
        requiresEnterprise = network?.enterprise || false

        open()
        Qt.callLater(() => {
                         if (contentLoader.item) {
                             if (requiresEnterprise && contentLoader.item.usernameInput) {
                                 contentLoader.item.usernameInput.forceActiveFocus()
                             } else if (contentLoader.item.passwordInput) {
                                 contentLoader.item.passwordInput.forceActiveFocus()
                             }
                         }
                     })
    }

    function showFromPrompt(token, ssid, setting, fields, hints, reason, connType, connName, vpnService) {
        isPromptMode = true
        promptToken = token
        promptReason = reason
        promptFields = fields || []
        promptSetting = setting || "802-11-wireless-security"
        connectionType = connType || "802-11-wireless"
        connectionName = connName || ssid || ""
        vpnServiceType = vpnService || ""

        isVpnPrompt = (connectionType === "vpn" || connectionType === "wireguard")
        wifiPasswordSSID = isVpnPrompt ? connectionName : ssid

        requiresEnterprise = setting === "802-1x"

        if (reason === "wrong-password") {
            wifiPasswordInput = ""
            wifiUsernameInput = ""
        } else {
            wifiPasswordInput = ""
            wifiUsernameInput = ""
            wifiAnonymousIdentityInput = ""
            wifiDomainInput = ""
        }

        open()
        Qt.callLater(() => {
                         if (contentLoader.item) {
                             if (reason === "wrong-password" && contentLoader.item.passwordInput) {
                                 contentLoader.item.passwordInput.text = ""
                                 contentLoader.item.passwordInput.forceActiveFocus()
                             } else if (requiresEnterprise && contentLoader.item.usernameInput) {
                                 contentLoader.item.usernameInput.forceActiveFocus()
                             } else if (contentLoader.item.passwordInput) {
                                 contentLoader.item.passwordInput.forceActiveFocus()
                             }
                         }
                     })
    }

    shouldBeVisible: false
    width: 420
    height: requiresEnterprise ? 430 : 230
    onShouldBeVisibleChanged: () => {
                                  if (!shouldBeVisible) {
                                      wifiPasswordInput = ""
                                      wifiUsernameInput = ""
                                      wifiAnonymousIdentityInput = ""
                                      wifiDomainInput = ""
                                  }
                              }
    onOpened: {
        Qt.callLater(() => {
                         if (contentLoader.item) {
                             if (requiresEnterprise && contentLoader.item.usernameInput) {
                                 contentLoader.item.usernameInput.forceActiveFocus()
                             } else if (contentLoader.item.passwordInput) {
                                 contentLoader.item.passwordInput.forceActiveFocus()
                             }
                         }
                     })
    }
    onBackgroundClicked: () => {
                             if (isPromptMode) {
                                 NetworkService.cancelCredentials(promptToken)
                             }
                             close()
                             wifiPasswordInput = ""
                             wifiUsernameInput = ""
                             wifiAnonymousIdentityInput = ""
                             wifiDomainInput = ""
                         }

    Connections {
        target: NetworkService

        function onPasswordDialogShouldReopenChanged() {
            if (NetworkService.passwordDialogShouldReopen && NetworkService.connectingSSID !== "") {
                wifiPasswordSSID = NetworkService.connectingSSID
                wifiPasswordInput = ""
                open()
                NetworkService.passwordDialogShouldReopen = false
            }
        }
    }

    content: Component {
        FocusScope {
            id: wifiContent

            property alias usernameInput: usernameInput
            property alias passwordInput: passwordInput

            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: event => {
                                      if (isPromptMode) {
                                          NetworkService.cancelCredentials(promptToken)
                                      }
                                      close()
                                      wifiPasswordInput = ""
                                      wifiUsernameInput = ""
                                      wifiAnonymousIdentityInput = ""
                                      wifiDomainInput = ""
                                      event.accepted = true
                                  }

            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingM * 2
                spacing: Theme.spacingM

                Row {
                    width: parent.width

                    Column {
                        width: parent.width - 40
                        spacing: Theme.spacingXS

                        StyledText {
                            text: {
                                if (isVpnPrompt) {
                                    return I18n.tr("Connect to VPN")
                                }
                                return I18n.tr("Connect to Wi-Fi")
                            }
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: {
                                    if (isVpnPrompt) {
                                        return I18n.tr("Enter password for ") + wifiPasswordSSID
                                    }
                                    const prefix = requiresEnterprise ? I18n.tr("Enter credentials for ") : I18n.tr("Enter password for ")
                                    return prefix + wifiPasswordSSID
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceTextMedium
                                width: parent.width
                                elide: Text.ElideRight
                            }

                            StyledText {
                                visible: isPromptMode && promptReason === "wrong-password"
                                text: I18n.tr("Incorrect password")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.error
                                width: parent.width
                            }
                        }
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: () => {
                                       if (isPromptMode) {
                                           NetworkService.cancelCredentials(promptToken)
                                       }
                                       close()
                                       wifiPasswordInput = ""
                                       wifiUsernameInput = ""
                                       wifiAnonymousIdentityInput = ""
                                       wifiDomainInput = ""
                                   }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: Theme.surfaceHover
                    border.color: usernameInput.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: usernameInput.activeFocus ? 2 : 1
                    visible: requiresEnterprise && !isVpnPrompt

                    MouseArea {
                        anchors.fill: parent
                        onClicked: () => {
                                       usernameInput.forceActiveFocus()
                                   }
                    }

                    DankTextField {
                        id: usernameInput

                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        text: wifiUsernameInput
                        placeholderText: I18n.tr("Username")
                        backgroundColor: "transparent"
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                                          wifiUsernameInput = text
                                      }
                        onAccepted: () => {
                                        if (passwordInput) {
                                            passwordInput.forceActiveFocus()
                                        }
                                    }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: Theme.surfaceHover
                    border.color: passwordInput.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: passwordInput.activeFocus ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: () => {
                                       passwordInput.forceActiveFocus()
                                   }
                    }

                    DankTextField {
                        id: passwordInput

                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        text: wifiPasswordInput
                        echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                        placeholderText: (requiresEnterprise && !isVpnPrompt) ? I18n.tr("Password") : ""
                        backgroundColor: "transparent"
                        focus: !requiresEnterprise
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                                          wifiPasswordInput = text
                                      }
                        onAccepted: () => {
                                        if (isPromptMode) {
                                            const secrets = {}
                                            if (isVpnPrompt) {
                                                if (passwordInput.text) secrets["password"] = passwordInput.text
                                            } else if (promptSetting === "802-11-wireless-security") {
                                                secrets["psk"] = passwordInput.text
                                            } else if (promptSetting === "802-1x") {
                                                if (usernameInput.text) secrets["identity"] = usernameInput.text
                                                if (passwordInput.text) secrets["password"] = passwordInput.text
                                                if (wifiAnonymousIdentityInput) secrets["anonymous-identity"] = wifiAnonymousIdentityInput
                                            }
                                            NetworkService.submitCredentials(promptToken, secrets, true)
                                        } else {
                                            const username = requiresEnterprise ? usernameInput.text : ""
                                            NetworkService.connectToWifi(
                                                wifiPasswordSSID,
                                                passwordInput.text,
                                                username,
                                                wifiAnonymousIdentityInput,
                                                wifiDomainInput
                                            )
                                        }
                                        close()
                                        wifiPasswordInput = ""
                                        wifiUsernameInput = ""
                                        wifiAnonymousIdentityInput = ""
                                        wifiDomainInput = ""
                                        passwordInput.text = ""
                                        if (requiresEnterprise) usernameInput.text = ""
                                    }
                        Component.onCompleted: () => {
                                                   if (root.shouldBeVisible && !requiresEnterprise)
                                                   focusDelayTimer.start()
                                               }

                        Timer {
                            id: focusDelayTimer

                            interval: 100
                            repeat: false
                            onTriggered: () => {
                                             if (root.shouldBeVisible) {
                                                 if (requiresEnterprise && usernameInput) {
                                                     usernameInput.forceActiveFocus()
                                                 } else {
                                                     passwordInput.forceActiveFocus()
                                                 }
                                             }
                                         }
                        }

                        Connections {
                            target: root

                            function onShouldBeVisibleChanged() {
                                if (root.shouldBeVisible)
                                    focusDelayTimer.start()
                            }
                        }
                    }
                }

                Rectangle {
                    visible: requiresEnterprise && !isVpnPrompt
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: Theme.surfaceHover
                    border.color: anonInput.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: anonInput.activeFocus ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: () => {
                                       anonInput.forceActiveFocus()
                                   }
                    }

                    DankTextField {
                        id: anonInput

                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        text: wifiAnonymousIdentityInput
                        placeholderText: I18n.tr("Anonymous Identity (optional)")
                        backgroundColor: "transparent"
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                                          wifiAnonymousIdentityInput = text
                                      }
                    }
                }

                Rectangle {
                    visible: requiresEnterprise && !isVpnPrompt
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: Theme.surfaceHover
                    border.color: domainMatchInput.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: domainMatchInput.activeFocus ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: () => {
                                       domainMatchInput.forceActiveFocus()
                                   }
                    }

                    DankTextField {
                        id: domainMatchInput

                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        text: wifiDomainInput
                        placeholderText: I18n.tr("Domain (optional)")
                        backgroundColor: "transparent"
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                                          wifiDomainInput = text
                                      }
                    }
                }

                Row {
                    spacing: Theme.spacingS

                    Rectangle {
                        id: showPasswordCheckbox

                        property bool checked: false

                        width: 20
                        height: 20
                        radius: 4
                        color: checked ? Theme.primary : "transparent"
                        border.color: checked ? Theme.primary : Theme.outlineButton
                        border.width: 2

                        DankIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: 12
                            color: Theme.background
                            visible: parent.checked
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: () => {
                                           showPasswordCheckbox.checked = !showPasswordCheckbox.checked
                                       }
                        }
                    }

                    StyledText {
                        text: I18n.tr("Show password")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
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
                                onClicked: () => {
                                               if (isPromptMode) {
                                                   NetworkService.cancelCredentials(promptToken)
                                               }
                                               close()
                                               wifiPasswordInput = ""
                                               wifiUsernameInput = ""
                                               wifiAnonymousIdentityInput = ""
                                               wifiDomainInput = ""
                                           }
                            }
                        }

                        Rectangle {
                            width: Math.max(80, connectText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: connectArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                            enabled: {
                                if (isVpnPrompt) {
                                    return passwordInput.text.length > 0
                                }
                                return requiresEnterprise ? (usernameInput.text.length > 0 && passwordInput.text.length > 0) : passwordInput.text.length > 0
                            }
                            opacity: enabled ? 1 : 0.5

                            StyledText {
                                id: connectText

                                anchors.centerIn: parent
                                text: I18n.tr("Connect")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.background
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: connectArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: parent.enabled
                                onClicked: () => {
                                               if (isPromptMode) {
                                                   const secrets = {}
                                                   if (isVpnPrompt) {
                                                       if (passwordInput.text) secrets["password"] = passwordInput.text
                                                   } else if (promptSetting === "802-11-wireless-security") {
                                                       secrets["psk"] = passwordInput.text
                                                   } else if (promptSetting === "802-1x") {
                                                       if (usernameInput.text) secrets["identity"] = usernameInput.text
                                                       if (passwordInput.text) secrets["password"] = passwordInput.text
                                                       if (wifiAnonymousIdentityInput) secrets["anonymous-identity"] = wifiAnonymousIdentityInput
                                                   }
                                                   NetworkService.submitCredentials(promptToken, secrets, true)
                                               } else {
                                                   const username = requiresEnterprise ? usernameInput.text : ""
                                                   NetworkService.connectToWifi(
                                                       wifiPasswordSSID,
                                                       passwordInput.text,
                                                       username,
                                                       wifiAnonymousIdentityInput,
                                                       wifiDomainInput
                                                   )
                                               }
                                               close()
                                               wifiPasswordInput = ""
                                               wifiUsernameInput = ""
                                               wifiAnonymousIdentityInput = ""
                                               wifiDomainInput = ""
                                               passwordInput.text = ""
                                               if (requiresEnterprise) usernameInput.text = ""
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
        }
    }
}
