import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Modules.Network
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

DModal {
    id: root

    layerNamespace: "dms:wifi-password"
    keepPopoutsOpen: true
    allowStacking: true
    shouldBeVisible: false
    modalWidth: Math.min(Theme.dialogMaxWidth, screenWidth - Theme.spacingXL * 2)
    modalHeight: Math.min(contentFocusScope.implicitHeight, screenHeight - Theme.spacingXL * 2)
    enableShadow: true
    onBackgroundClicked: clearAndClose()
    directContent: contentFocusScope

    property bool disablePopupTransparency: true
    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property string wifiUsernameInput: ""
    property bool requiresEnterprise: false
    property bool isHiddenNetwork: false
    property string hiddenSecurity: "wpa-psk"
    property var importProfile: null
    property string browseTarget: ""

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
    readonly property bool isWiredPrompt: isPromptMode && !isVpnPrompt && connectionType !== "802-11-wireless"
    readonly property string serverCertificateFingerprint: promptHints.length > 0 ? promptHints[0] : ""
    readonly property bool showEnterpriseForm: requiresEnterprise && !isVpnPrompt && !isPromptMode
    readonly property bool hiddenNeedsPassword: hiddenSecurity === "wpa-psk" || hiddenSecurity === "sae"
    readonly property bool showUsernameField: requiresEnterprise && !isVpnPrompt && isPromptMode && fieldsInfo.length === 0
    readonly property bool showPasswordField: fieldsInfo.length === 0 && !isCertificatePrompt && !showEnterpriseForm && (!isHiddenNetwork || hiddenNeedsPassword)
    readonly property bool showSavePasswordCheckbox: isVpnPrompt && promptReason !== "pkcs11" && !isCertificatePrompt
    readonly property var hiddenSecurityChoices: {
        const choices = [[I18n.tr("Open", "network security type", true), "none"], ["WPA/WPA2", "wpa-psk"], ["WPA3", "sae"], ["OWE", "owe"]];
        if (NetworkService.enterpriseSupported)
            choices.push([I18n.tr("Enterprise", "wifi security type value, 802.1x enterprise network"), "wpa-eap"]);
        return choices;
    }

    readonly property int certificateWarningHeight: certificateWarningColumn.implicitHeight + Theme.spacingM * 2

    function focusFirstField() {
        if (isCertificatePrompt) {
            connectButton.forceActiveFocus();
            return;
        }
        if (fieldsInfo.length > 0) {
            if (dynamicFieldsRepeater.count > 0) {
                const firstItem = dynamicFieldsRepeater.itemAt(0);
                if (firstItem)
                    firstItem.forceActiveFocus();
            }
            return;
        }
        if (isHiddenNetwork) {
            ssidInput.forceActiveFocus();
            return;
        }
        if (showUsernameField) {
            usernameInput.forceActiveFocus();
            return;
        }
        if (showEnterpriseForm) {
            enterpriseForm.focusIdentity();
            return;
        }
        if (showPasswordField)
            passwordInput.forceActiveFocus();
    }

    function resetState() {
        wifiPasswordSSID = "";
        wifiPasswordInput = "";
        wifiUsernameInput = "";
        requiresEnterprise = false;
        isHiddenNetwork = false;
        hiddenSecurity = "wpa-psk";
        importProfile = null;
        isPromptMode = false;
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
        enterpriseForm.usernameSuffix = "";
        enterpriseForm.usernameSuffixRequired = false;
        enterpriseForm.caDisplayName = "";
        enterpriseForm.reset();
    }

    function show(ssid) {
        resetState();
        wifiPasswordSSID = ssid;
        const network = NetworkService.wifiNetworks.find(n => n.ssid === ssid);
        requiresEnterprise = network?.enterprise || false;

        open();
        Qt.callLater(focusFirstField);
    }

    function showHidden() {
        resetState();
        isHiddenNetwork = true;

        open();
        Qt.callLater(focusFirstField);
    }

    function showImport(profile, fileName) {
        resetState();
        importProfile = profile;
        wifiPasswordSSID = profile.ssids?.[0] ?? "";
        requiresEnterprise = true;
        enterpriseForm.usernameSuffix = profile.usernameSuffix || "";
        enterpriseForm.usernameSuffixRequired = !!profile.usernameSuffix && !!profile.usernameHint;
        enterpriseForm.caDisplayName = fileName || "";
        enterpriseForm.reset(profile.enterprise);

        open();
        Qt.callLater(focusFirstField);
    }

    function showFromPrompt(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fInfo) {
        resetState();
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

        isVpnPrompt = (connectionType === "vpn" || connectionType === "wireguard");
        wifiPasswordSSID = connectionType === "802-11-wireless" ? ssid : connectionName;
        savePasswordCheckbox.checked = !isVpnPrompt;

        requiresEnterprise = setting === "802-1x";

        open();
        Qt.callLater(() => {
            if (reason === "wrong-password")
                shakeSecretFields();
            focusFirstField();
        });
    }

    function hide() {
        close();
    }

    function shakeSecretFields() {
        if (fieldsInfo.length === 0) {
            passwordInput.text = "";
            passwordInput.shake();
            return;
        }
        for (var i = 0; i < dynamicFieldsRepeater.count; i++) {
            const item = dynamicFieldsRepeater.itemAt(i);
            if (item?.morph)
                item.shake();
        }
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
            return I18n.tr("PIN", "noun, numeric personal identification number for a smart card");
        case "psk":
            return I18n.tr("Password");
        case "anonymous-identity":
            return I18n.tr("Anonymous Identity");
        default:
            return fieldName.charAt(0).toUpperCase() + fieldName.slice(1).replace(/-/g, " ");
        }
    }

    function submitImport() {
        const options = {
            "security": "wpa-eap",
            "enterprise": enterpriseForm.toConfig()
        };
        const ssids = importProfile?.ssids ?? [];
        const visible = ssids.find(s => NetworkService.wifiNetworks.some(n => n.ssid === s));
        if (visible)
            NetworkService.connectToWifi(visible, "", options);
        for (const ssid of ssids) {
            if (ssid !== visible)
                NetworkService.saveWifiProfile(ssid, options, null);
        }
    }

    function submitCredentialsAndClose() {
        if (!connectButton.enabled)
            return;
        if (fieldsInfo.length > 0) {
            NetworkService.submitCredentials(promptToken, secretValues, savePasswordCheckbox.checked);
            hide();
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
            }
            NetworkService.submitCredentials(promptToken, secrets, savePasswordCheckbox.checked);
        } else if (importProfile) {
            submitImport();
        } else if (isHiddenNetwork) {
            const options = {
                "hidden": true,
                "security": hiddenSecurity
            };
            if (showEnterpriseForm)
                options.enterprise = enterpriseForm.toConfig();
            NetworkService.connectToWifi(ssidInput.text, hiddenNeedsPassword ? passwordInput.text : "", options);
        } else if (showEnterpriseForm) {
            NetworkService.connectToWifi(wifiPasswordSSID, "", {
                "security": "wpa-eap",
                "enterprise": enterpriseForm.toConfig()
            });
        } else {
            NetworkService.connectToWifi(wifiPasswordSSID, passwordInput.text);
        }

        hide();
    }

    function clearAndClose() {
        if (isPromptMode)
            NetworkService.cancelCredentials(promptToken);
        hide();
    }

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            Qt.callLater(focusFirstField);
            return;
        }
        wifiPasswordInput = "";
        wifiUsernameInput = "";
        secretValues = {};
        enterpriseForm.reset();
        passwordInput.text = "";
        usernameInput.text = "";
        ssidInput.text = "";
        for (var i = 0; i < dynamicFieldsRepeater.count; i++) {
            const item = dynamicFieldsRepeater.itemAt(i);
            if (item)
                item.text = "";
        }
    }

    Connections {
        target: NetworkService

        function onPasswordDialogShouldReopenChanged() {
            if (!NetworkService.passwordDialogShouldReopen || NetworkService.connectingSSID === "")
                return;
            show(NetworkService.connectingSSID);
            NetworkService.passwordDialogShouldReopen = false;
        }
    }

    LazyLoader {
        id: certBrowserLoader
        active: false

        FileBrowserSurfaceModal {
            bucket: "certificate"
            filters: ["*.pem", "*.crt", "*.cer", "*.der", "*.p12", "*.pfx", "*.key", "*"]
            onAccepted: paths => enterpriseForm.setPath(root.browseTarget, paths[0])
        }
    }

    DDialog {
        id: contentFocusScope

        anchors.fill: parent
        focus: root.shouldBeVisible
        acceptEnabled: connectButton.enabled
        onAccepted: submitCredentialsAndClose()
        onRejected: clearAndClose()
        title: {
            if (promptReason === "pkcs11")
                return I18n.tr("Smartcard Authentication");
            if (isCertificatePrompt)
                return I18n.tr("Untrusted VPN certificate", "Title for VPN server certificate trust confirmation");
            if (isVpnPrompt)
                return I18n.tr("Connect to VPN");
            if (isWiredPrompt)
                return I18n.tr("Ethernet");
            if (importProfile)
                return importProfile.providerName || I18n.tr("Connect to Wi-Fi");
            if (isHiddenNetwork)
                return I18n.tr("Connect to Hidden Network");
            return I18n.tr("Connect to Wi-Fi");
        }
        supportingText: {
            if (promptReason === "pkcs11")
                return I18n.tr("Enter PIN for ") + wifiPasswordSSID;
            if (isCertificatePrompt)
                return wifiPasswordSSID;
            if (fieldsInfo.length > 0)
                return I18n.tr("Enter credentials for ") + wifiPasswordSSID;
            if (isVpnPrompt)
                return I18n.tr("Enter password for ") + wifiPasswordSSID;
            if (isHiddenNetwork)
                return hiddenNeedsPassword ? I18n.tr("Enter network name and password") : I18n.tr("Enter network name", "hidden Wi-Fi prompt subtitle when the chosen security needs no password");
            return (requiresEnterprise ? I18n.tr("Enter credentials for ") : I18n.tr("Enter password for ")) + wifiPasswordSSID;
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

        DTextField {
            id: ssidInput
            visible: isHiddenNetwork
            expressive: true
            leftIconName: "wifi"

            width: parent.width
            labelText: I18n.tr("Network Name (SSID)")
            enabled: root.shouldBeVisible

            onAccepted: {
                if (showPasswordField)
                    passwordInput.forceActiveFocus();
            }
        }

        DDropdown {
            id: hiddenSecurityDropdown
            visible: isHiddenNetwork
            width: parent.width
            text: I18n.tr("Security", "noun, settings page name and wifi security type label")
            options: hiddenSecurityChoices.map(c => c[0])
            // DDropdown assigns currentValue on pick, which drops a plain binding; this re-applies it on reset.
            Binding {
                target: hiddenSecurityDropdown
                property: "currentValue"
                value: hiddenSecurityChoices.find(c => c[1] === hiddenSecurity)?.[0] ?? ""
            }
            onValueChanged: value => {
                hiddenSecurity = hiddenSecurityChoices.find(c => c[0] === value)?.[1] ?? "wpa-psk";
                requiresEnterprise = hiddenSecurity === "wpa-eap";
            }
        }

        Repeater {
            id: dynamicFieldsRepeater
            model: fieldsInfo

            delegate: DTextField {
                id: fieldInput
                required property var modelData
                required property int index
                expressive: true
                morph: modelData.isSecret
                leftIconName: modelData.isSecret ? "lock" : "person"
                width: contentFocusScope.contentItem.width
                showPasswordToggle: modelData.isSecret
                isError: modelData.isSecret && isPromptMode && promptReason === "wrong-password" && text.length === 0
                supportingText: isError ? I18n.tr("Incorrect password") : ""
                echoMode: modelData.isSecret && !passwordVisible ? TextInput.Password : TextInput.Normal
                labelText: getFieldLabel(modelData.name)
                enabled: root.shouldBeVisible

                onTextEdited: {
                    let updated = Object.assign({}, root.secretValues);
                    updated[modelData.name] = text;
                    root.secretValues = updated;
                }

                onAccepted: {
                    if (index < fieldsInfo.length - 1) {
                        const nextItem = dynamicFieldsRepeater.itemAt(index + 1);
                        if (nextItem)
                            nextItem.forceActiveFocus();
                        return;
                    }
                    submitCredentialsAndClose();
                }
            }
        }

        DTextField {
            id: usernameInput
            visible: showUsernameField
            expressive: true
            leftIconName: "person"

            width: parent.width
            text: wifiUsernameInput
            labelText: I18n.tr("Username", "text field label for network, vpn and account forms")
            enabled: root.shouldBeVisible

            onTextEdited: wifiUsernameInput = text
            onAccepted: passwordInput.forceActiveFocus()
        }

        DTextField {
            id: passwordInput
            visible: showPasswordField
            expressive: true
            morph: true
            leftIconName: "lock"

            width: parent.width
            text: wifiPasswordInput
            showPasswordToggle: true
            isError: isPromptMode && promptReason === "wrong-password" && text.length === 0
            supportingText: isError ? I18n.tr("Incorrect password") : ""
            echoMode: passwordVisible ? TextInput.Normal : TextInput.Password
            labelText: promptReason === "pkcs11" ? I18n.tr("PIN", "noun, numeric personal identification number for a smart card") : I18n.tr("Password")
            enabled: root.shouldBeVisible

            onTextEdited: wifiPasswordInput = text
            onAccepted: submitCredentialsAndClose()
        }

        EnterpriseAuthForm {
            id: enterpriseForm
            expressive: true
            // System CA needs a server domain, which most users don't know when connecting.
            defaultCa: "none"
            visible: showEnterpriseForm
            width: parent.width
            onSubmitRequested: submitCredentialsAndClose()
            onBrowseRequested: target => {
                root.browseTarget = target;
                certBrowserLoader.active = true;
                const browser = certBrowserLoader.item;
                if (browser)
                    browser.open();
            }
        }

        DToggle {
            id: savePasswordCheckbox

            width: parent.width
            text: I18n.tr("Save password")
            visible: showSavePasswordCheckbox
            checked: !isVpnPrompt
            onToggled: checked => savePasswordCheckbox.checked = checked
        }

        actions: [
            DButton {
                maximumWidth: contentFocusScope.actionWidth
                wrapText: true
                text: I18n.tr("Cancel")
                backgroundColor: "transparent"
                textColor: Theme.primary
                onClicked: clearAndClose()
            },
            DButton {
                id: connectButton
                maximumWidth: contentFocusScope.actionWidth
                wrapText: true

                text: isCertificatePrompt ? I18n.tr("Trust", "Button that approves a VPN server certificate fingerprint") : I18n.tr("Connect", "verb, connect to a network or device")
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
                    if (isHiddenNetwork && ssidInput.text.length === 0)
                        return false;
                    if (showEnterpriseForm)
                        return enterpriseForm.valid;
                    if (isHiddenNetwork)
                        return !hiddenNeedsPassword || passwordInput.text.length >= (hiddenSecurity === "wpa-psk" ? 8 : 1);
                    return showUsernameField ? (usernameInput.text.length > 0 && passwordInput.text.length > 0) : passwordInput.text.length > 0;
                }
                onClicked: submitCredentialsAndClose()
            }
        ]
    }
}
