import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""

    function show(ssid) {
        wifiPasswordSSID = ssid
        wifiPasswordInput = ""
        open()
        Qt.callLater(() => {
                         if (contentLoader.item && contentLoader.item.passwordInput)
                         contentLoader.item.passwordInput.forceActiveFocus()
                     })
    }

    shouldBeVisible: false
    width: 420
    height: 230
    onShouldBeVisibleChanged: () => {
                                  if (!shouldBeVisible)
                                  wifiPasswordInput = ""
                              }
    onOpened: {
        Qt.callLater(() => {
                         if (contentLoader.item && contentLoader.item.passwordInput)
                         contentLoader.item.passwordInput.forceActiveFocus()
                     })
    }
    onBackgroundClicked: () => {
                             close()
                             wifiPasswordInput = ""
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

            property alias passwordInput: passwordInput

            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: event => {
                                      close()
                                      wifiPasswordInput = ""
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
                            text: "Connect to Wi-Fi"
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: `Enter password for "${wifiPasswordSSID}"`
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
                        hoverColor: Theme.errorHover
                        onClicked: () => {
                                       close()
                                       wifiPasswordInput = ""
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
                        placeholderText: ""
                        backgroundColor: "transparent"
                        focus: true
                        enabled: root.shouldBeVisible
                        onTextEdited: () => {
                                          wifiPasswordInput = text
                                      }
                        onAccepted: () => {
                                        NetworkService.connectToWifi(wifiPasswordSSID, passwordInput.text)
                                        close()
                                        wifiPasswordInput = ""
                                        passwordInput.text = ""
                                    }
                        Component.onCompleted: () => {
                                                   if (root.shouldBeVisible)
                                                   focusDelayTimer.start()
                                               }

                        Timer {
                            id: focusDelayTimer

                            interval: 100
                            repeat: false
                            onTriggered: () => {
                                             if (root.shouldBeVisible)
                                             passwordInput.forceActiveFocus()
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
                        text: "Show password"
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
                                text: "Cancel"
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
                                           }
                            }
                        }

                        Rectangle {
                            width: Math.max(80, connectText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: connectArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                            enabled: passwordInput.text.length > 0
                            opacity: enabled ? 1 : 0.5

                            StyledText {
                                id: connectText

                                anchors.centerIn: parent
                                text: "Connect"
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
                                               NetworkService.connectToWifi(wifiPasswordSSID, passwordInput.text)
                                               close()
                                               wifiPasswordInput = ""
                                               passwordInput.text = ""
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
