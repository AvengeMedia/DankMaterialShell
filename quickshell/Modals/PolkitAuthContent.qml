import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    property var currentFlow: PolkitService.agent?.flow
    property string passwordInput: ""
    property bool isLoading: false
    property bool awaitingFprintForPassword: false
    property var windowControls: null
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

    signal closeRequested
    signal authenticationSucceeded

    focus: true

    Keys.onEscapePressed: event => {
        cancelAuth();
        event.accepted = true;
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

    function reset() {
        passwordInput = "";
        isLoading = false;
        awaitingFprintForPassword = false;
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
        closeRequested();
    }

    Connections {
        target: root.currentFlow
        enabled: root.currentFlow !== null

        function onIsResponseRequiredChanged() {
            if (!root.currentFlow.isResponseRequired)
                return;
            if (root.awaitingFprintForPassword && root.passwordInput !== "") {
                root._commitSubmit();
                return;
            }
            root.awaitingFprintForPassword = false;
            root.isLoading = false;
            root.passwordInput = "";
            passwordField.forceActiveFocus();
        }

        function onAuthenticationSucceeded() {
            root.authenticationSucceeded();
            root.closeRequested();
        }

        function onAuthenticationFailed() {
            root.isLoading = false;
        }

        function onAuthenticationRequestCancelled() {
            root.closeRequested();
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

    Item {
        id: headerSection
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        height: Math.max(titleColumn.implicitHeight, windowButtonRow.implicitHeight)

        MouseArea {
            anchors.fill: parent
            enabled: root.windowControls !== null
            onPressed: {
                if (root.windowControls)
                    root.windowControls.tryStartMove();
            }
            onDoubleClicked: {
                if (root.windowControls)
                    root.windowControls.tryToggleMaximize();
            }
        }

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
                text: root.currentFlow?.message ?? ""
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceTextMedium
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: text !== ""
            }

            StyledText {
                text: root.currentFlow?.supplementaryMessage ?? ""
                font.pixelSize: Theme.fontSizeSmall
                color: (root.currentFlow?.supplementaryIsError ?? false) ? Theme.error : Theme.surfaceTextMedium
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                opacity: (root.currentFlow?.supplementaryIsError ?? false) ? 1 : 0.8
                visible: text !== ""
            }
        }

        Row {
            id: windowButtonRow
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Theme.spacingXS

            DankActionButton {
                visible: root.windowControls?.supported === true && root.windowControls?.canMaximize === true
                iconName: (root.windowControls?.targetWindow?.maximized ?? false) ? "fullscreen_exit" : "fullscreen"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                onClicked: {
                    if (root.windowControls)
                        root.windowControls.tryToggleMaximize();
                }
            }

            DankActionButton {
                iconName: "close"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                enabled: !root.isLoading
                opacity: enabled ? 1 : 0.5
                onClicked: root.cancelAuth()
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
            text: root.currentFlow?.inputPrompt ?? ""
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            width: parent.width
            visible: text !== ""
        }

        DankTextField {
            id: passwordField

            width: parent.width
            height: root.inputFieldHeight
            backgroundColor: Theme.surfaceHover
            normalBorderColor: Theme.outlineStrong
            focusedBorderColor: Theme.primary
            borderWidth: 1
            focusedBorderWidth: 2
            leftIconName: root.polkitPamHasFprint ? "fingerprint" : ""
            leftIconSize: 20
            leftIconColor: Theme.primary
            leftIconFocusedColor: Theme.primary
            opacity: root.isLoading ? 0.5 : 1
            font.pixelSize: Theme.fontSizeMedium
            textColor: Theme.surfaceText
            text: root.passwordInput
            showPasswordToggle: !(root.currentFlow?.responseVisible ?? false)
            echoMode: (root.currentFlow?.responseVisible ?? false) || passwordVisible ? TextInput.Normal : TextInput.Password
            placeholderText: ""
            enabled: !root.isLoading
            onTextEdited: root.passwordInput = text
            onAccepted: root.submitAuth()
        }

        StyledText {
            text: I18n.tr("Authentication failed, please try again")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
            width: parent.width
            visible: root.currentFlow?.failed ?? false
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
                    enabled: !root.isLoading
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
                        onClicked: root.cancelAuth()
                    }
                }

                Rectangle {
                    width: Math.max(80, authText.contentWidth + Theme.spacingM * 2)
                    height: 36
                    radius: Theme.cornerRadius
                    color: authArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                    enabled: !root.isLoading
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
                        onClicked: root.submitAuth()
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
