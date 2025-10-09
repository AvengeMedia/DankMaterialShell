import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property string wifiUsernameInput: ""
    property bool requiresEnterprise: false

    function show(ssid) {
        wifiPasswordSSID = ssid
        wifiPasswordInput = ""
        wifiUsernameInput = ""

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

    shouldBeVisible: false
    width: 420
    height: requiresEnterprise ? 310 : 230
    onShouldBeVisibleChanged: () => {
                                  if (!shouldBeVisible) {
                                      wifiPasswordInput = ""
                                      wifiUsernameInput = ""
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
                             close()
                             wifiPasswordInput = ""
                             wifiUsernameInput = ""
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
                                      close()
                                      wifiPasswordInput = ""
                                      wifiUsernameInput = ""
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
                            text: I18n.tr("Connect to Wi-Fi")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: requiresEnterprise ? `Enter credentials for "${wifiPasswordSSID}"` : `Enter password for "${wifiPasswordSSID}"`
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceTextMedium
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: () => {
                                       close()
                                       wifiPasswordInput = ""
                                       wifiUsernameInput = ""
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
                    visible: requiresEnterprise

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
                        placeholderText: "Username"
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
                        placeholderText: requiresEnterprise ? "Password" : ""
                        backgroundColor: "transparent"
                        focus: !requiresEnterprise
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                                          wifiPasswordInput = text
                                      }
                        onAccepted: () => {
                                        const username = requiresEnterprise ? usernameInput.text : ""
                                        NetworkService.connectToWifi(wifiPasswordSSID, passwordInput.text, username)
                                        close()
                                        wifiPasswordInput = ""
                                        wifiUsernameInput = ""
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
                                               close()
                                               wifiPasswordInput = ""
                                               wifiUsernameInput = ""
                                           }
                            }
                        }

                        Rectangle {
                            width: Math.max(80, connectText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: connectArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                            enabled: requiresEnterprise ? (usernameInput.text.length > 0 && passwordInput.text.length > 0) : passwordInput.text.length > 0
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
                                               const username = requiresEnterprise ? usernameInput.text : ""
                                               NetworkService.connectToWifi(wifiPasswordSSID, passwordInput.text, username)
                                               close()
                                               wifiPasswordInput = ""
                                               wifiUsernameInput = ""
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
