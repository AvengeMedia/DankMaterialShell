import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:wifi-password"
    keepPopoutsOpen: true
    allowStacking: true
    shouldBeVisible: false
    modalWidth: 420
    modalHeight: calculatedHeight
    enableShadow: true
    onBackgroundClicked: clearAndClose()
    directContent: contentFocusScope

    property bool disablePopupTransparency: true
    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property string wifiUsernameInput: ""
    property bool requiresEnterprise: false
    property bool isHiddenNetwork: false

    property string wifiAnonymousIdentityInput: ""
    property string wifiDomainInput: ""
    property string eapMethodValue: "peap"
    property string phase2AuthValue: "mschapv2"

    property bool isPromptMode: false
    property string promptToken: ""
    property string promptReason: ""
    property var promptFields: []
    property var promptHints: []
    property string promptSetting: ""

    property bool isVpnPrompt: false
    property string connectionName: ""
    property string vpnServiceType: ""
    property string connectionType: ""
    property var fieldsInfo: []
    property var secretValues: ({})

    readonly property bool isCertificateChangedPrompt: promptReason === "server-certificate-changed"
    readonly property bool isCertificatePrompt: promptReason === "server-certificate" || isCertificateChangedPrompt
    readonly property string serverCertificateFingerprint: promptHints.length > 0 ? promptHints[0] : ""
    readonly property bool showUsernameField: requiresEnterprise && !isVpnPrompt && fieldsInfo.length === 0
    readonly property bool showPasswordField: fieldsInfo.length === 0 && !isCertificatePrompt
    readonly property bool showEapFields: requiresEnterprise && !isVpnPrompt && !isPromptMode
    readonly property bool showPhase2Dropdown: eapMethodValue === "peap" || eapMethodValue === "ttls"
    readonly property bool showAnonField: requiresEnterprise && !isVpnPrompt && !isPromptMode && eapMethodValue !== "pwd"
    readonly property bool showDomainField: showAnonField
    readonly property bool showSavePasswordCheckbox: (isVpnPrompt || fieldsInfo.length > 0) && promptReason !== "pkcs11" && !isCertificatePrompt

    readonly property int inputFieldHeight: Theme.fontSizeMedium + Theme.spacingL * 2
    readonly property int inputFieldWithSpacing: inputFieldHeight + Theme.spacingM
    readonly property int checkboxRowHeight: Theme.fontSizeMedium + Theme.spacingS
    readonly property int headerHeight: Theme.fontSizeLarge + Theme.fontSizeMedium + Theme.spacingM * 2
    readonly property int buttonRowHeight: 36 + Theme.spacingM
    readonly property int certificateWarningHeight: certificateWarningColumn.implicitHeight + Theme.spacingM * 2

    property int calculatedHeight: {
        let h = headerHeight + buttonRowHeight + Theme.spacingL * 2;
        h += fieldsInfo.length * inputFieldWithSpacing;
        if (isHiddenNetwork)
            h += inputFieldWithSpacing;
        if (showEapFields)
            h += eapSelectorRow.implicitHeight + Theme.spacingM;
        if (showUsernameField)
            h += inputFieldWithSpacing;
        if (showPasswordField)
            h += inputFieldWithSpacing;
        if (showAnonField)
            h += inputFieldWithSpacing;
        if (showDomainField)
            h += inputFieldWithSpacing;
        if (showSavePasswordCheckbox)
            h += checkboxRowHeight;
        if (isCertificatePrompt)
            h += certificateWarningHeight + Theme.spacingM;
        return h;
    }

    function focusFirstField() {
        if (isCertificatePrompt) {
            connectButton.forceActiveFocus();
            return;
        }
        if (fieldsInfo.length > 0) {
            if (dynamicFieldsRepeater.count > 0) {
                const firstItem = dynamicFieldsRepeater.itemAt(0);
                if (firstItem)
                    firstItem.children[0].forceActiveFocus();
            }
            return;
        }
        if (isHiddenNetwork) {
            ssidInput.forceActiveFocus();
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
        eapMethodValue = "peap";
        phase2AuthValue = "mschapv2";
        isPromptMode = false;
        isHiddenNetwork = false;
        promptToken = "";
        promptReason = "";
        promptFields = [];
        promptHints = [];
        promptSetting = "";
        isVpnPrompt = false;
        connectionName = "";
        vpnServiceType = "";
        connectionType = "";
        fieldsInfo = [];
        secretValues = {};

        const network = NetworkService.wifiNetworks.find(n => n.ssid === ssid);
        requiresEnterprise = network?.enterprise || false;

        open();
        Qt.callLater(focusFirstField);
    }

    function showHidden() {
        wifiPasswordSSID = "";
        wifiPasswordInput = "";
        wifiUsernameInput = "";
        wifiAnonymousIdentityInput = "";
        wifiDomainInput = "";
        eapMethodValue = "peap";
        phase2AuthValue = "mschapv2";
        isPromptMode = false;
        isHiddenNetwork = true;
        promptToken = "";
        promptReason = "";
        promptFields = [];
        promptHints = [];
        promptSetting = "";
        isVpnPrompt = false;
        connectionName = "";
        vpnServiceType = "";
        connectionType = "";
        fieldsInfo = [];
        secretValues = {};
        requiresEnterprise = false;

        open();
        Qt.callLater(focusFirstField);
    }

    function showFromPrompt(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fInfo) {
        isPromptMode = true;
        promptToken = token;
        promptReason = reason;
        promptFields = fields || [];
        promptHints = hints || [];
        promptSetting = setting || "802-11-wireless-security";
        connectionType = connType || "802-11-wireless";
        connectionName = connName || ssid || "";
        vpnServiceType = vpnService || "";
        fieldsInfo = fInfo || [];
        secretValues = {};

        isVpnPrompt = (connectionType === "vpn" || connectionType === "wireguard");
        wifiPasswordSSID = isVpnPrompt ? connectionName : ssid;
        savePasswordCheckbox.checked = !isVpnPrompt;

        requiresEnterprise = setting === "802-1x";

        wifiPasswordInput = "";
        wifiUsernameInput = "";
        wifiAnonymousIdentityInput = "";
        wifiDomainInput = "";
        eapMethodValue = "peap";
        phase2AuthValue = "mschapv2";

        open();
        Qt.callLater(() => {
            if (reason === "wrong-password" && fieldsInfo.length === 0) {
                passwordInput.text = "";
            }
            focusFirstField();
        });
    }

    function hide() {
        close();
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
            const ssid = isHiddenNetwork ? ssidInput.text : wifiPasswordSSID;
            const username = requiresEnterprise ? usernameInput.text : "";
            const anonIdentity = showAnonField ? wifiAnonymousIdentityInput : "";
            const domainMatch = showDomainField ? wifiDomainInput : "";
            const eap = requiresEnterprise ? eapMethodValue : "";
            const phase2 = requiresEnterprise && showPhase2Dropdown ? phase2AuthValue : "";
            NetworkService.connectToWifi(ssid, passwordInput.text, username, anonIdentity, domainMatch, isHiddenNetwork, eap, phase2);
        }

        hide();
        wifiPasswordInput = "";
        wifiUsernameInput = "";
        wifiAnonymousIdentityInput = "";
        wifiDomainInput = "";
        passwordInput.text = "";
        if (requiresEnterprise)
            usernameInput.text = "";
        if (isHiddenNetwork)
            ssidInput.text = "";
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

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
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
        ssidInput.text = "";
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
            open();
            NetworkService.passwordDialogShouldReopen = false;
        }
    }

    FocusScope {
        id: contentFocusScope

        anchors.fill: parent
        focus: root.shouldBeVisible

        Keys.onEscapePressed: event => {
            clearAndClose();
            event.accepted = true;
        }

        Column {
            id: contentCol
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingM

            Item {
                width: contentCol.width
                height: Math.max(headerCol.height, buttonRow.height)

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: buttonRow.left
                    anchors.rightMargin: Theme.spacingM
                    height: headerCol.height

                    Column {
                        id: headerCol
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: {
                                if (promptReason === "pkcs11")
                                    return I18n.tr("Smartcard Authentication");
                                if (isCertificatePrompt)
                                    return I18n.tr("Untrusted VPN certificate", "Title for VPN server certificate trust confirmation");
                                if (isVpnPrompt)
                                    return I18n.tr("Connect to VPN");
                                if (isHiddenNetwork)
                                    return I18n.tr("Connect to Hidden Network");
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
                                    if (isCertificatePrompt)
                                        return wifiPasswordSSID;
                                    if (fieldsInfo.length > 0)
                                        return I18n.tr("Enter credentials for ") + wifiPasswordSSID;
                                    if (isVpnPrompt)
                                        return I18n.tr("Enter password for ") + wifiPasswordSSID;
                                    if (isHiddenNetwork)
                                        return I18n.tr("Enter network name and password");
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
                    id: buttonRow
                    anchors.right: parent.right
                    spacing: Theme.spacingXS

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: clearAndClose()
                    }
                }
            }

            Rectangle {
                id: certificateWarningBox

                readonly property color warningTone: isCertificateChangedPrompt ? Theme.error : Theme.warning

                width: parent.width
                height: certificateWarningHeight
                radius: Theme.cornerRadius
                color: Theme.withAlpha(warningTone, 0.12)
                border.color: Theme.withAlpha(warningTone, 0.5)
                border.width: 1
                visible: isCertificatePrompt

                Column {
                    id: certificateWarningColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: isCertificateChangedPrompt ? I18n.tr("The server certificate has changed since it was last trusted. Only continue if you recognize the new fingerprint.", "Warning shown when a trusted VPN server certificate no longer matches") : I18n.tr("Only continue if you recognize this server certificate fingerprint.", "Warning shown before trusting an unverified VPN server certificate")
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: parent.width
                        text: serverCertificateFingerprint
                        wrapMode: Text.WrapAnywhere
                        font.family: SettingsData.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: certificateWarningBox.warningTone
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: inputFieldHeight
                radius: Theme.cornerRadius
                color: Theme.surfaceHover
                border.color: ssidInput.activeFocus ? Theme.primary : Theme.outlineStrong
                border.width: ssidInput.activeFocus ? 2 : 1
                visible: isHiddenNetwork

                MouseArea {
                    anchors.fill: parent
                    onClicked: ssidInput.forceActiveFocus()
                }

                DankTextField {
                    id: ssidInput

                    anchors.fill: parent
                    font.pixelSize: Theme.fontSizeMedium
                    textColor: Theme.surfaceText
                    placeholderText: I18n.tr("Network Name (SSID)")
                    backgroundColor: "transparent"
                    enabled: root.shouldBeVisible
                    keyNavigationTab: passwordInput
                    onAccepted: passwordInput.forceActiveFocus()
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
                        showPasswordToggle: modelData.isSecret
                        echoMode: modelData.isSecret && !passwordVisible ? TextInput.Password : TextInput.Normal
                        placeholderText: getFieldLabel(modelData.name)
                        backgroundColor: "transparent"
                        enabled: root.shouldBeVisible

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

            Row {
                id: eapSelectorRow

                visible: showEapFields
                width: parent.width
                spacing: Theme.spacingM

                Column {
                    width: showPhase2Dropdown ? (parent.width - Theme.spacingM) / 2 : parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Authentication")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankDropdown {
                        width: parent.width
                        dropdownWidth: parent.width
                        compactMode: true
                        options: ["PEAP", "TTLS", "PWD"]
                        currentValue: eapMethodValue.toUpperCase()
                        onValueChanged: value => {
                            eapMethodValue = value.toLowerCase();
                            phase2AuthValue = eapMethodValue === "ttls" ? "pap" : "mschapv2";
                        }
                    }
                }

                Column {
                    visible: showPhase2Dropdown
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Inner authentication", "802.1X phase 2 authentication method")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankDropdown {
                        width: parent.width
                        dropdownWidth: parent.width
                        compactMode: true
                        options: eapMethodValue === "ttls" ? ["PAP", "MSCHAPv2", "MSCHAP", "CHAP", "GTC", "MD5"] : ["MSCHAPv2", "GTC", "MD5"]
                        currentValue: phase2AuthValue === "mschapv2" ? "MSCHAPv2" : phase2AuthValue.toUpperCase()
                        onValueChanged: value => phase2AuthValue = value.toLowerCase()
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
                    enabled: root.shouldBeVisible
                    keyNavigationTab: passwordInput
                    keyNavigationBacktab: showDomainField ? domainMatchInput : passwordInput
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
                    showPasswordToggle: true
                    echoMode: passwordVisible ? TextInput.Normal : TextInput.Password
                    placeholderText: (requiresEnterprise && !isVpnPrompt) ? I18n.tr("Password") : ""
                    backgroundColor: "transparent"
                    enabled: root.shouldBeVisible
                    keyNavigationTab: showAnonField ? anonInput : (showUsernameField ? usernameInput : null)
                    keyNavigationBacktab: showUsernameField ? usernameInput : null
                    onTextEdited: wifiPasswordInput = text
                    onAccepted: {
                        if (showAnonField) {
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
                    enabled: root.shouldBeVisible
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
                    enabled: root.shouldBeVisible
                    keyNavigationTab: usernameInput
                    keyNavigationBacktab: anonInput
                    onTextEdited: wifiDomainInput = text
                    onAccepted: submitCredentialsAndClose()
                }
            }

            Row {
                spacing: Theme.spacingS
                visible: showSavePasswordCheckbox

                Rectangle {
                    id: savePasswordCheckbox

                    property bool checked: !isVpnPrompt

                    width: 20
                    height: 20
                    radius: 4
                    color: checked ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
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
                        color: cancelArea.containsMouse ? Theme.surfaceTextHover : Theme.withAlpha(Theme.surfaceTextHover, 0)
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
                        id: connectButton

                        width: Math.max(80, connectText.contentWidth + Theme.spacingM * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: connectArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                        border.color: activeFocus ? Theme.surfaceText : "transparent"
                        border.width: activeFocus ? 2 : 0
                        activeFocusOnTab: true
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
                            if (isCertificatePrompt)
                                return serverCertificateFingerprint.length > 0;
                            if (isVpnPrompt)
                                return passwordInput.text.length > 0;
                            if (isHiddenNetwork)
                                return ssidInput.text.length > 0;
                            return requiresEnterprise ? (usernameInput.text.length > 0 && passwordInput.text.length > 0) : passwordInput.text.length > 0;
                        }
                        opacity: enabled ? 1 : 0.5

                        StyledText {
                            id: connectText
                            anchors.centerIn: parent
                            text: isCertificatePrompt ? I18n.tr("Trust", "Button that approves a VPN server certificate fingerprint") : I18n.tr("Connect")
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

                        Keys.onReturnPressed: event => {
                            if (enabled)
                                submitCredentialsAndClose();
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: event => {
                            if (enabled)
                                submitCredentialsAndClose();
                            event.accepted = true;
                        }
                        Keys.onSpacePressed: event => {
                            if (enabled)
                                submitCredentialsAndClose();
                            event.accepted = true;
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

    onOpened: Qt.callLater(() => contentFocusScope.forceActiveFocus())
}
