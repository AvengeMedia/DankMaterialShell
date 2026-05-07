import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property bool disablePopupTransparency: true
    property string passwordInput: ""
    property var currentFlow: PolkitService.agent?.flow
    property bool isLoading: false
    property bool awaitingFprintForPassword: false
    readonly property int inputFieldHeight: Theme.fontSizeMedium + Theme.spacingL * 2

    property string polkitEtcPamText: ""
    property string polkitLibPamText: ""
    property string systemAuthPamText: ""
    property string commonAuthPamText: ""
    property string passwordAuthPamText: ""
    readonly property bool polkitPamHasFprint: {
        const polkitText = polkitEtcPamText !== "" ? polkitEtcPamText : polkitLibPamText;
        if (!polkitText)
            return false;
        return pamModuleEnabled(polkitText, "pam_fprintd") || (polkitText.includes("system-auth") && pamModuleEnabled(systemAuthPamText, "pam_fprintd")) || (polkitText.includes("common-auth") && pamModuleEnabled(commonAuthPamText, "pam_fprintd")) || (polkitText.includes("password-auth") && pamModuleEnabled(passwordAuthPamText, "pam_fprintd"));
    }

    function stripPamComment(line) {
        if (!line)
            return "";
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#"))
            return "";
        const hashIdx = trimmed.indexOf("#");
        if (hashIdx >= 0)
            return trimmed.substring(0, hashIdx).trim();
        return trimmed;
    }

    function pamModuleEnabled(pamText, moduleName) {
        if (!pamText || !moduleName)
            return false;
        const lines = pamText.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = stripPamComment(lines[i]);
            if (line && line.includes(moduleName))
                return true;
        }
        return false;
    }

    function focusPasswordField() {
        passwordField.forceActiveFocus();
    }

    function show(targetScreen) {
        if (targetScreen)
            screen = targetScreen;
        passwordInput = "";
        isLoading = false;
        awaitingFprintForPassword = false;
        visible = true;
        Qt.callLater(focusPasswordField);
    }

    function hide() {
        visible = false;
    }

    function _commitSubmit() {
        isLoading = true;
        awaitingFprintForPassword = false;
        currentFlow.submit(passwordInput);
        passwordInput = "";
    }

    function submitAuth() {
        if (!currentFlow || isLoading)
            return;
        if (!currentFlow.isResponseRequired) {
            awaitingFprintForPassword = true;
            return;
        }
        _commitSubmit();
    }

    function cancelAuth() {
        if (isLoading)
            return;
        awaitingFprintForPassword = false;
        if (currentFlow) {
            currentFlow.cancelAuthenticationRequest();
            return;
        }
        hide();
    }

    objectName: "polkitAuthModal"

    screen: Quickshell.screens[0]
    color: "transparent"
    visible: false

    WlrLayershell.namespace: "dms:polkit-auth"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        left: true
        top: true
        right: true
        bottom: true
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(focusPasswordField);
            return;
        }
        passwordInput = "";
        isLoading = false;
        awaitingFprintForPassword = false;
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
            if (awaitingFprintForPassword && passwordInput !== "") {
                _commitSubmit();
                return;
            }
            awaitingFprintForPassword = false;
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

    FileView {
        path: "/etc/pam.d/polkit-1"
        printErrors: false
        onLoaded: root.polkitEtcPamText = text()
        onLoadFailed: root.polkitEtcPamText = ""
    }

    FileView {
        path: "/usr/lib/pam.d/polkit-1"
        printErrors: false
        onLoaded: root.polkitLibPamText = text()
        onLoadFailed: root.polkitLibPamText = ""
    }

    FileView {
        path: "/etc/pam.d/system-auth"
        printErrors: false
        onLoaded: root.systemAuthPamText = text()
        onLoadFailed: root.systemAuthPamText = ""
    }

    FileView {
        path: "/etc/pam.d/common-auth"
        printErrors: false
        onLoaded: root.commonAuthPamText = text()
        onLoadFailed: root.commonAuthPamText = ""
    }

    FileView {
        path: "/etc/pam.d/password-auth"
        printErrors: false
        onLoaded: root.passwordAuthPamText = text()
        onLoadFailed: root.passwordAuthPamText = ""
    }

    // Dim overlay — clicking outside cancels authentication
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: cancelAuth()
        }
    }

    // Centered dialog box
    Rectangle {
        id: dialogBox
        width: 460
        height: 220
        anchors.centerIn: parent
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius

        FocusScope {
            id: contentFocusScope
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: event => {
                cancelAuth();
                event.accepted = true;
            }

            Item {
                id: headerSection
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                height: Math.max(titleColumn.implicitHeight, windowButtonRow.implicitHeight)

                Column {
                    id: titleColumn
                    anchors.left: parent.left
                    anchors.right: windowButtonRow.left
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Authentication Required")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: currentFlow?.message ?? ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    StyledText {
                        text: currentFlow?.supplementaryMessage ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: (currentFlow?.supplementaryIsError ?? false) ? Theme.error : Theme.surfaceTextMedium
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        opacity: (currentFlow?.supplementaryIsError ?? false) ? 1 : 0.8
                        visible: text !== ""
                    }
                }

                Row {
                    id: windowButtonRow
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Theme.spacingXS

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
                id: bottomSection
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    text: currentFlow?.inputPrompt ?? ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    width: parent.width
                    visible: text !== ""
                }

                DankTextField {
                    id: passwordField

                    width: parent.width
                    height: inputFieldHeight
                    backgroundColor: Theme.surfaceHover
                    normalBorderColor: Theme.outlineStrong
                    focusedBorderColor: Theme.primary
                    borderWidth: 1
                    focusedBorderWidth: 2
                    leftIconName: polkitPamHasFprint ? "fingerprint" : ""
                    leftIconSize: 20
                    leftIconColor: Theme.primary
                    leftIconFocusedColor: Theme.primary
                    opacity: isLoading ? 0.5 : 1
                    font.pixelSize: Theme.fontSizeMedium
                    textColor: Theme.surfaceText
                    text: passwordInput
                    showPasswordToggle: !(currentFlow?.responseVisible ?? false)
                    echoMode: (currentFlow?.responseVisible ?? false) || passwordVisible ? TextInput.Normal : TextInput.Password
                    placeholderText: ""
                    enabled: !isLoading
                    onTextEdited: passwordInput = text
                    onAccepted: submitAuth()
                }

                StyledText {
                    text: I18n.tr("Authentication failed, please try again")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.error
                    width: parent.width
                    visible: currentFlow?.failed ?? false
                }

                Item {
                    width: parent.width
                    height: 36

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
                            enabled: !isLoading
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
    }
}
