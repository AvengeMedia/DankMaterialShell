import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    property string passwordInput: ""
    property var currentFlow: PolkitService.agent?.flow
    property bool isLoading: false
    readonly property int inputFieldHeight: Theme.fontSizeMedium + Theme.spacingL * 2
    property int calculatedHeight: Math.max(240, headerRow.implicitHeight + mainColumn.implicitHeight + Theme.spacingM * 3)

    function focusPasswordField() {
        passwordField.forceActiveFocus();
    }

    function show() {
        passwordInput = "";
        isLoading = false;
        visible = true;
        Qt.callLater(focusPasswordField);
    }

    function hide() {
        visible = false;
    }

    function submitAuth() {
        if (passwordInput.length === 0 || !currentFlow || isLoading)
            return;
        isLoading = true;
        currentFlow.submit(passwordInput);
        passwordInput = "";
    }

    function cancelAuth() {
        if (!currentFlow || isLoading)
            return;
        currentFlow.cancelAuthenticationRequest();
    }

    objectName: "polkitAuthModal"
    title: I18n.tr("Authentication")
    minimumSize: Qt.size(420, calculatedHeight)
    maximumSize: Qt.size(420, calculatedHeight)
    color: Theme.surfaceContainer
    visible: false

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(focusPasswordField);
            return;
        }
        passwordInput = "";
        isLoading = false;
    }

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable

        function onAuthenticationRequestStarted() {
            show();
        }

        function onIsActiveChanged() {
            if (!(PolkitService.agent?.isActive ?? false))
                hide();
        }
    }

    Connections {
        target: currentFlow
        enabled: currentFlow !== null

        function onIsResponseRequiredChanged() {
            if (!currentFlow.isResponseRequired)
                return;
            isLoading = false;
            passwordInput = "";
            passwordField.forceActiveFocus();
        }

        function onAuthenticationSucceeded() {
            hide();
        }

        function onAuthenticationFailed() {
            isLoading = false;
        }

        function onAuthenticationRequestCancelled() {
            hide();
        }
    }

    FocusScope {
        id: contentFocusScope

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            cancelAuth();
            event.accepted = true;
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: headerRow.height + Theme.spacingM
            onPressed: windowControls.tryStartMove()
            onDoubleClicked: windowControls.tryToggleMaximize()
        }

        Row {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            anchors.topMargin: Theme.spacingM

            Column {
                width: parent.width - 60
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Authentication Required")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: currentFlow?.message ?? ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        width: parent.width
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        visible: (currentFlow?.supplementaryMessage ?? "") !== ""
                        text: currentFlow?.supplementaryMessage ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: (currentFlow?.supplementaryIsError ?? false) ? Theme.error : Theme.surfaceTextMedium
                        width: parent.width
                        wrapMode: Text.Wrap
                        opacity: (currentFlow?.supplementaryIsError ?? false) ? 1 : 0.8
                    }
                }
            }

            Row {
                spacing: Theme.spacingXS

                DankActionButton {
                    visible: windowControls.supported
                    iconName: root.maximized ? "fullscreen_exit" : "fullscreen"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: windowControls.tryToggleMaximize()
                }

                DankActionButton {
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    enabled: !isLoading
                    opacity: enabled ? 1 : 0.5
                    onClicked: cancelAuth()
                }
            }
        }

        Column {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            anchors.bottomMargin: Theme.spacingM
            spacing: Theme.spacingM

            StyledText {
                text: currentFlow?.inputPrompt ?? ""
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                width: parent.width
                visible: (currentFlow?.inputPrompt ?? "") !== ""
            }

            Rectangle {
                width: parent.width
                height: inputFieldHeight
                radius: Theme.cornerRadius
                color: Theme.surfaceHover
                border.color: passwordField.activeFocus ? Theme.primary : Theme.outlineStrong
                border.width: passwordField.activeFocus ? 2 : 1
                opacity: isLoading ? 0.5 : 1

                MouseArea {
                    anchors.fill: parent
                    enabled: !isLoading
                    onClicked: passwordField.forceActiveFocus()
                }

                DankTextField {
                    id: passwordField

                    anchors.fill: parent
                    font.pixelSize: Theme.fontSizeMedium
                    textColor: Theme.surfaceText
                    text: passwordInput
                    echoMode: (currentFlow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                    placeholderText: ""
                    backgroundColor: "transparent"
                    enabled: !isLoading
                    onTextEdited: passwordInput = text
                    onAccepted: submitAuth()
                }
            }

            Item {
                width: parent.width
                height: (currentFlow?.failed ?? false) ? failedText.implicitHeight : 0
                visible: height > 0

                StyledText {
                    id: failedText
                    text: I18n.tr("Authentication failed, please try again")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.error
                    width: parent.width
                    opacity: (currentFlow?.failed ?? false) ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
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
                        enabled: !isLoading
                        opacity: enabled ? 1 : 0.5

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
                            enabled: parent.enabled
                            onClicked: cancelAuth()
                        }
                    }

                    Rectangle {
                        width: Math.max(80, authText.contentWidth + Theme.spacingM * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: authArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                        enabled: !isLoading && (passwordInput.length > 0 || !(currentFlow?.isResponseRequired ?? true))
                        opacity: enabled ? 1 : 0.5

                        StyledText {
                            id: authText
                            anchors.centerIn: parent
                            text: I18n.tr("Authenticate")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.background
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: authArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: parent.enabled
                            onClicked: submitAuth()
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
}
