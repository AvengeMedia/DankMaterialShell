import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

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
    property var fieldsInfo: []
    property var secretValues: ({})

    readonly property bool showUsernameField: requiresEnterprise && !isVpnPrompt && fieldsInfo.length === 0
    readonly property bool showPasswordField: fieldsInfo.length === 0
    readonly property bool showAnonField: requiresEnterprise && !isVpnPrompt
    readonly property bool showDomainField: requiresEnterprise && !isVpnPrompt
    readonly property bool showShowPasswordCheckbox: fieldsInfo.length === 0
    readonly property bool showSavePasswordCheckbox: (isVpnPrompt || fieldsInfo.length > 0) && promptReason !== "pkcs11"

    readonly property int inputFieldHeight: Theme.fontSizeMedium + Theme.spacingL * 2
    readonly property int inputFieldWithSpacing: inputFieldHeight + Theme.spacingM
    readonly property int checkboxRowHeight: Theme.fontSizeMedium + Theme.spacingS
    readonly property int headerHeight: Theme.fontSizeLarge + Theme.fontSizeMedium + Theme.spacingM * 2
    readonly property int buttonRowHeight: 36 + Theme.spacingM

    property int calculatedHeight: {
        let h = headerHeight + buttonRowHeight + Theme.spacingL * 2;
        h += fieldsInfo.length * inputFieldWithSpacing;
        if (showUsernameField) h += inputFieldWithSpacing;
        if (showPasswordField) h += inputFieldWithSpacing;
        if (showAnonField) h += inputFieldWithSpacing;
        if (showDomainField) h += inputFieldWithSpacing;
        if (showShowPasswordCheckbox) h += checkboxRowHeight;
        if (showSavePasswordCheckbox) h += checkboxRowHeight;
        return h;
    }

    function focusFirstField() {
        if (fieldsInfo.length > 0) {
            if (dynamicFieldsRepeater.count > 0) {
                const firstItem = dynamicFieldsRepeater.itemAt(0);
                if (firstItem)
                    firstItem.children[0].forceActiveFocus();
            }
            return;
        }
        if (requiresEnterprise && !isVpnPrompt) {
            usernameInput.forceActiveFocus();
            return;
        }
        passwordInput.forceActiveFocus();
    }

    function show(ssid) {
        wifiPasswordSSID = ssid;
        wifiPasswordInput = "";
        wifiUsernameInput = "";
        wifiAnonymousIdentityInput = "";
        wifiDomainInput = "";
        isPromptMode = false;
        promptToken = "";
        promptReason = "";
        promptFields = [];
        promptSetting = "";
        isVpnPrompt = false;
        connectionName = "";
        vpnServiceType = "";
        connectionType = "";
        fieldsInfo = [];
        secretValues = {};

        const network = NetworkService.wifiNetworks.find(n => n.ssid === ssid);
        requiresEnterprise = network?.enterprise || false;

        visible = true;
        Qt.callLater(focusFirstField);
    }

    function showFromPrompt(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fInfo) {
        isPromptMode = true;
        promptToken = token;
        promptReason = reason;
        promptFields = fields || [];
        promptSetting = setting || "802-11-wireless-security";
        connectionType = connType || "802-11-wireless";
        connectionName = connName || ssid || "";
        vpnServiceType = vpnService || "";
        fieldsInfo = fInfo || [];
        secretValues = {};

        isVpnPrompt = (connectionType === "vpn" || connectionType === "wireguard");
        wifiPasswordSSID = isVpnPrompt ? connectionName : ssid;

        requiresEnterprise = setting === "802-1x";

        wifiPasswordInput = "";
        wifiUsernameInput = "";
        wifiAnonymousIdentityInput = "";
        wifiDomainInput = "";

        visible = true;
        Qt.callLater(() => {
            if (reason === "wrong-password" && fieldsInfo.length === 0) {
                passwordInput.text = "";
            }
            focusFirstField();
        });
    }

    function hide() {
        visible = false;
    }

    function getFieldLabel(fieldName) {
        switch (fieldName) {
        case "username":
        case "identity":
            return I18n.tr("Username");
        case "password":
            return I18n.tr("Password");
        case "cert-pass":
        case "certpass":
            return I18n.tr("Certificate Password");
        case "private-key-password":
            return I18n.tr("Private Key Password");
        case "pin":
        case "key_pass":
            return I18n.tr("PIN");
        case "psk":
            return I18n.tr("Password");
        case "anonymous-identity":
            return I18n.tr("Anonymous Identity");
        default:
            return fieldName.charAt(0).toUpperCase() + fieldName.slice(1).replace(/-/g, " ");
        }
    }

    function submitCredentialsAndClose() {
        if (fieldsInfo.length > 0) {
            NetworkService.submitCredentials(promptToken, secretValues, savePasswordCheckbox.checked);
            hide();
            secretValues = {};
            return;
        }

        if (isPromptMode) {
            const secrets = {};
            if (isVpnPrompt) {
                if (passwordInput.text)
                    secrets["password"] = passwordInput.text;
            } else if (promptSetting === "802-11-wireless-security") {
                secrets["psk"] = passwordInput.text;
            } else if (promptSetting === "802-1x") {
                if (usernameInput.text)
                    secrets["identity"] = usernameInput.text;
                if (passwordInput.text)
                    secrets["password"] = passwordInput.text;
                if (wifiAnonymousIdentityInput)
                    secrets["anonymous-identity"] = wifiAnonymousIdentityInput;
            }
            NetworkService.submitCredentials(promptToken, secrets, savePasswordCheckbox.checked);
        } else {
            const username = requiresEnterprise ? usernameInput.text : "";
            NetworkService.connectToWifi(wifiPasswordSSID, passwordInput.text, username, wifiAnonymousIdentityInput, wifiDomainInput);
        }

        hide();
        wifiPasswordInput = "";
        wifiUsernameInput = "";
        wifiAnonymousIdentityInput = "";
        wifiDomainInput = "";
        passwordInput.text = "";
        if (requiresEnterprise)
            usernameInput.text = "";
    }

    function clearAndClose() {
        if (isPromptMode)
            NetworkService.cancelCredentials(promptToken);
        hide();
        wifiPasswordInput = "";
        wifiUsernameInput = "";
        wifiAnonymousIdentityInput = "";
        wifiDomainInput = "";
        secretValues = {};
    }

    objectName: "wifiPasswordModal"
    title: {
        if (promptReason === "pkcs11")
            return I18n.tr("Smartcard PIN");
        if (isVpnPrompt)
            return I18n.tr("VPN Password");
        return I18n.tr("Wi-Fi Password");
    }
    minimumSize: Qt.size(420, calculatedHeight)
    maximumSize: Qt.size(420, calculatedHeight)
    color: Theme.surfaceContainer
    visible: false

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(focusFirstField);
            return;
        }
        wifiPasswordInput = "";
        wifiUsernameInput = "";
        wifiAnonymousIdentityInput = "";
        wifiDomainInput = "";
        secretValues = {};
        passwordInput.text = "";
        usernameInput.text = "";
        anonInput.text = "";
        domainMatchInput.text = "";
        for (var i = 0; i < dynamicFieldsRepeater.count; i++) {
            const item = dynamicFieldsRepeater.itemAt(i);
            if (item?.children[0])
                item.children[0].text = "";
        }
    }

    Connections {
        target: NetworkService

        function onPasswordDialogShouldReopenChanged() {
            if (!NetworkService.passwordDialogShouldReopen || NetworkService.connectingSSID === "")
                return;
            wifiPasswordSSID = NetworkService.connectingSSID;
            wifiPasswordInput = "";
            visible = true;
            NetworkService.passwordDialogShouldReopen = false;
        }
    }

    FocusScope {
        id: contentFocusScope

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            clearAndClose();
            event.accepted = true;
        }

        Column {
            id: contentCol
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingM

            Row {
                width: contentCol.width

                MouseArea {
                    width: parent.width - 60
                    height: headerCol.height
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()

                    Column {
                        id: headerCol
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: {
                                if (promptReason === "pkcs11")
                                    return I18n.tr("Smartcard Authentication");
                                if (isVpnPrompt)
                                    return I18n.tr("Connect to VPN");
                                return I18n.tr("Connect to Wi-Fi");
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
                                    if (promptReason === "pkcs11")
                                        return I18n.tr("Enter PIN for ") + wifiPasswordSSID;
                                    if (fieldsInfo.length > 0)
                                        return I18n.tr("Enter credentials for ") + wifiPasswordSSID;
                                    if (isVpnPrompt)
                                        return I18n.tr("Enter password for ") + wifiPasswordSSID;
                                    const prefix = requiresEnterprise ? I18n.tr("Enter credentials for ") : I18n.tr("Enter password for ");
                                    return prefix + wifiPasswordSSID;
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
                        onClicked: clearAndClose()
                    }
                }
            }

            Repeater {
                id: dynamicFieldsRepeater
                model: fieldsInfo

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: contentCol.width
                    height: inputFieldHeight
                    radius: Theme.cornerRadius
                    color: Theme.surfaceHover
                    border.color: fieldInput.activeFocus ? Theme.primary : Theme.outlineStrong
                    border.width: fieldInput.activeFocus ? 2 : 1

                    DankTextField {
                        id: fieldInput
                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: Theme.surfaceText
                        echoMode: modelData.isSecret ? TextInput.Password : TextInput.Normal
                        placeholderText: getFieldLabel(modelData.name)
                        backgroundColor: "transparent"
                        enabled: root.visible

                        Keys.onTabPressed: event => {
                            if (index < fieldsInfo.length - 1) {
                                const nextItem = dynamicFieldsRepeater.itemAt(index + 1);
                                if (nextItem)
                                    nextItem.children[0].forceActiveFocus();
                            } else {
                                const firstItem = dynamicFieldsRepeater.itemAt(0);
                                if (firstItem)
                                    firstItem.children[0].forceActiveFocus();
                            }
                            event.accepted = true;
                        }

                        Keys.onBacktabPressed: event => {
                            if (index > 0) {
                                const prevItem = dynamicFieldsRepeater.itemAt(index - 1);
                                if (prevItem)
                                    prevItem.children[0].forceActiveFocus();
                            } else {
                                const lastItem = dynamicFieldsRepeater.itemAt(fieldsInfo.length - 1);
                                if (lastItem)
                                    lastItem.children[0].forceActiveFocus();
                            }
                            event.accepted = true;
                        }

                        onTextEdited: {
                            let updated = Object.assign({}, root.secretValues);
                            updated[modelData.name] = text;
                            root.secretValues = updated;
                        }

                        onAccepted: {
                            if (index < fieldsInfo.length - 1) {
                                const nextItem = dynamicFieldsRepeater.itemAt(index + 1);
                                if (nextItem)
                                    nextItem.children[0].forceActiveFocus();
                                return;
                            }
                            submitCredentialsAndClose();
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: inputFieldHeight
                radius: Theme.cornerRadius
                color: Theme.surfaceHover
                border.color: usernameInput.activeFocus ? Theme.primary : Theme.outlineStrong
                border.width: usernameInput.activeFocus ? 2 : 1
                visible: showUsernameField

                MouseArea {
                    anchors.fill: parent
                    onClicked: usernameInput.forceActiveFocus()
                }

                DankTextField {
                    id: usernameInput

                    anchors.fill: parent
                    font.pixelSize: Theme.fontSizeMedium
                    textColor: Theme.surfaceText
                    text: wifiUsernameInput
                    placeholderText: I18n.tr("Username")
                    backgroundColor: "transparent"
                    enabled: root.visible
                    keyNavigationTab: passwordInput
                    keyNavigationBacktab: domainMatchInput
                    onTextEdited: wifiUsernameInput = text
                    onAccepted: passwordInput.forceActiveFocus()
                }
            }

            Rectangle {
                width: parent.width
                height: inputFieldHeight
                radius: Theme.cornerRadius
                color: Theme.surfaceHover
                border.color: passwordInput.activeFocus ? Theme.primary : Theme.outlineStrong
                border.width: passwordInput.activeFocus ? 2 : 1
                visible: showPasswordField

                MouseArea {
                    anchors.fill: parent
                    onClicked: passwordInput.forceActiveFocus()
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
                    enabled: root.visible
                    keyNavigationTab: (requiresEnterprise && !isVpnPrompt) ? anonInput : null
                    keyNavigationBacktab: (requiresEnterprise && !isVpnPrompt) ? usernameInput : null
                    onTextEdited: wifiPasswordInput = text
                    onAccepted: {
                        if (requiresEnterprise && !isVpnPrompt) {
                            anonInput.forceActiveFocus();
                            return;
                        }
                        submitCredentialsAndClose();
                    }
                }
            }

            Rectangle {
                visible: showAnonField
                width: parent.width
                height: inputFieldHeight
                radius: Theme.cornerRadius
                color: Theme.surfaceHover
                border.color: anonInput.activeFocus ? Theme.primary : Theme.outlineStrong
                border.width: anonInput.activeFocus ? 2 : 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: anonInput.forceActiveFocus()
                }

                DankTextField {
                    id: anonInput

                    anchors.fill: parent
                    font.pixelSize: Theme.fontSizeMedium
                    textColor: Theme.surfaceText
                    text: wifiAnonymousIdentityInput
                    placeholderText: I18n.tr("Anonymous Identity (optional)")
                    backgroundColor: "transparent"
                    enabled: root.visible
                    keyNavigationTab: domainMatchInput
                    keyNavigationBacktab: passwordInput
                    onTextEdited: wifiAnonymousIdentityInput = text
                    onAccepted: domainMatchInput.forceActiveFocus()
                }
            }

            Rectangle {
                visible: showDomainField
                width: parent.width
                height: inputFieldHeight
                radius: Theme.cornerRadius
                color: Theme.surfaceHover
                border.color: domainMatchInput.activeFocus ? Theme.primary : Theme.outlineStrong
                border.width: domainMatchInput.activeFocus ? 2 : 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: domainMatchInput.forceActiveFocus()
                }

                DankTextField {
                    id: domainMatchInput

                    anchors.fill: parent
                    font.pixelSize: Theme.fontSizeMedium
                    textColor: Theme.surfaceText
                    text: wifiDomainInput
                    placeholderText: I18n.tr("Domain (optional)")
                    backgroundColor: "transparent"
                    enabled: root.visible
                    keyNavigationTab: usernameInput
                    keyNavigationBacktab: anonInput
                    onTextEdited: wifiDomainInput = text
                    onAccepted: submitCredentialsAndClose()
                }
            }

            Column {
                spacing: Theme.spacingS
                width: parent.width

                Row {
                    spacing: Theme.spacingS
                    visible: showShowPasswordCheckbox

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
                            onClicked: showPasswordCheckbox.checked = !showPasswordCheckbox.checked
                        }
                    }

                    StyledText {
                        text: I18n.tr("Show password")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: Theme.spacingS
                    visible: showSavePasswordCheckbox

                    Rectangle {
                        id: savePasswordCheckbox

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
                            onClicked: savePasswordCheckbox.checked = !savePasswordCheckbox.checked
                        }
                    }

                    StyledText {
                        text: I18n.tr("Save password")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
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
                            onClicked: clearAndClose()
                        }
                    }

                    Rectangle {
                        width: Math.max(80, connectText.contentWidth + Theme.spacingM * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: connectArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                        enabled: {
                            if (fieldsInfo.length > 0) {
                                for (var i = 0; i < fieldsInfo.length; i++) {
                                    if (!fieldsInfo[i].isSecret)
                                        continue;
                                    const fieldName = fieldsInfo[i].name;
                                    if (!secretValues[fieldName] || secretValues[fieldName].length === 0)
                                        return false;
                                }
                                return true;
                            }
                            if (isVpnPrompt)
                                return passwordInput.text.length > 0;
                            return requiresEnterprise ? (usernameInput.text.length > 0 && passwordInput.text.length > 0) : passwordInput.text.length > 0;
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
                            onClicked: submitCredentialsAndClose()
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
