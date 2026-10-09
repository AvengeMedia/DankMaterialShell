pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Common as DCommon
import qs.DCommon.Widgets
import "../../Common/ConnectionEditor.js" as CE

Column {
    id: root

    property bool expressive: false
    property string usernameSuffix: ""
    property bool usernameSuffixRequired: false
    property string caDisplayName: ""
    property string defaultCa: "system"
    // Files NM already holds as blobs (keys ca, clientCert, privateKey): they count as present while their path is empty.
    property var storedFiles: ({})
    readonly property bool valid: CE.enterpriseConfigValid(toConfig(), {
        usernameSuffix: usernameSuffix,
        usernameSuffixRequired: usernameSuffixRequired,
        storedFiles: storedFiles
    })

    signal browseRequested(string target)
    signal submitRequested

    readonly property var methodChoices: [{"label": "PEAP", "value": "peap"}, {"label": "TTLS", "value": "ttls"}, {"label": "TLS", "value": "tls"}, {"label": "PWD", "value": "pwd"}]
    readonly property var innerChoices: ({
            "peap": [{"label": "MSCHAPv2", "value": "mschapv2"}, {"label": "GTC", "value": "gtc"}, {"label": "MD5", "value": "md5"}],
            "ttls": [{"label": "PAP", "value": "pap"}, {"label": "MSCHAP", "value": "mschap"}, {"label": "MSCHAPv2", "value": "mschapv2"}, {"label": "CHAP", "value": "chap"}, {"label": "EAP-MSCHAPv2", "value": "eap-mschapv2"}]
        })
    readonly property var caChoices: [{"label": I18n.tr("File"), "value": "file"}, {"label": I18n.tr("Use system certificates", "802.1X CA certificate source option"), "value": "system"}, {"label": I18n.tr("None"), "value": "none"}]
    readonly property var matchChoices: [{"label": I18n.tr("Exact"), "value": false}, {"label": I18n.tr("Suffix", "server name match type"), "value": true}]
    readonly property var peapVersionChoices: [{"label": I18n.tr("Auto"), "value": ""}, {"label": "0", "value": "0"}, {"label": "1", "value": "1"}]

    readonly property bool usesInner: draft.eap === "peap" || draft.eap === "ttls"
    readonly property bool usesCa: draft.eap !== "pwd"
    readonly property bool isTls: draft.eap === "tls"

    function defaultInner(eap) {
        return eap === "ttls" ? "pap" : "mschapv2";
    }

    function reset(cfg) {
        const c = cfg || {};
        const eap = methodChoices.some(m => m.value === c.eap) ? c.eap : "peap";
        const inner = innerChoices[eap] || [];
        draft.eap = eap;
        draft.phase2 = inner.some(i => i.value === c.phase2) ? c.phase2 : defaultInner(eap);
        draft.identity = c.identity || "";
        draft.password = c.password || "";
        draft.savePassword = !c.askPassword;
        draft.anonymousIdentity = c.anonymousIdentity || "";
        draft.ca = caChoices.some(a => a.value === c.ca) ? c.ca : defaultCa;
        draft.caCertPath = c.caCertPath || "";
        draft.caCertPem = c.caCertPem || "";
        draft.serverDomain = c.serverDomain || "";
        draft.serverDomainSuffix = !!c.serverDomainSuffix;
        draft.clientCertPath = c.clientCertPath || "";
        draft.privateKeyPath = c.privateKeyPath || "";
        draft.privateKeyPassword = c.privateKeyPassword || "";
        draft.peapVersion = c.peapVersion === "0" || c.peapVersion === "1" ? c.peapVersion : "";
        draft.authFlags = c.authFlags || 0;
        draft.opensslCiphers = c.opensslCiphers || "";
    }

    function focusIdentity() {
        identityField.forceActiveFocus();
    }

    function storedLabel(target, path) {
        return path || (storedFiles[target] ? I18n.tr("Saved") : "");
    }

    function setPath(target, path) {
        if (storedFiles[target])
            storedFiles = Object.assign({}, storedFiles, {
                [target]: false
            });
        switch (target) {
        case "ca":
            draft.caCertPath = path;
            draft.caCertPem = "";
            break;
        case "clientCert":
            draft.clientCertPath = path;
            break;
        case "privateKey":
            draft.privateKeyPath = path;
            break;
        }
    }

    function toConfig() {
        return CE.enterpriseConfig({
            "eap": draft.eap,
            "phase2": draft.phase2,
            "identity": draft.identity,
            "password": draft.password,
            "savePassword": draft.savePassword,
            "anonymousIdentity": draft.anonymousIdentity,
            "ca": draft.ca,
            "caCertPath": draft.caCertPath,
            "caCertPem": draft.caCertPem,
            "serverDomain": draft.serverDomain,
            "serverDomainSuffix": draft.serverDomainSuffix,
            "clientCertPath": draft.clientCertPath,
            "privateKeyPath": draft.privateKeyPath,
            "privateKeyPassword": draft.privateKeyPassword,
            "peapVersion": draft.peapVersion,
            "authFlags": draft.authFlags,
            "opensslCiphers": draft.opensslCiphers,
            "usernameSuffix": root.usernameSuffix
        });
    }

    spacing: Theme.spacingM
    Component.onCompleted: reset()

    QtObject {
        id: draft

        property string eap
        property string phase2
        property string identity
        property string password
        property bool savePassword
        property string anonymousIdentity
        property string ca
        property string caCertPath
        property string caCertPem
        property string serverDomain
        property bool serverDomainSuffix
        property string clientCertPath
        property string privateKeyPath
        property string privateKeyPassword
        property string peapVersion
        property int authFlags
        property string opensslCiphers
    }

    component PathField: Row {
        id: pathField

        property alias text: pathInput.text
        property alias labelText: pathInput.labelText
        property string target

        width: parent.width
        spacing: Theme.spacingS

        DTextField {
            id: pathInput
            width: parent.width - browseButton.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            expressive: root.expressive
            outlined: !root.expressive
            readOnly: true
            controlHeight: root.expressive ? DCommon.Style.buttonHeightM : Theme.fieldHeightLarge
            font.pixelSize: Theme.fontSizeMedium
            textColor: Theme.surfaceText
        }

        DActionButton {
            id: browseButton
            anchors.verticalCenter: parent.verticalCenter
            iconName: "folder_open"
            tooltipText: I18n.tr("Select File")
            Accessible.name: pathInput.labelText + ": " + tooltipText
            onClicked: root.browseRequested(pathField.target)
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM

        Column {
            width: root.usesInner ? (parent.width - Theme.spacingM) / 2 : parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: I18n.tr("Authentication")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DDropdown {
                id: methodDropdown
                width: parent.width
                dropdownWidth: parent.width
                compactMode: true
                options: root.methodChoices.map(m => m.label)
                // DDropdown assigns currentValue on pick, which drops a plain binding; this re-applies it on reset.
                Binding {
                    target: methodDropdown
                    property: "currentValue"
                    value: CE.choiceLabel(root.methodChoices, draft.eap)
                }
                onValueChanged: value => {
                    const eap = CE.choiceValue(root.methodChoices, value);
                    if (eap === draft.eap)
                        return;
                    draft.eap = eap;
                    draft.phase2 = root.defaultInner(eap);
                }
            }
        }

        Column {
            visible: root.usesInner
            width: (parent.width - Theme.spacingM) / 2
            spacing: Theme.spacingXS

            StyledText {
                text: I18n.tr("Inner authentication", "802.1X phase 2 authentication method")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DDropdown {
                id: innerDropdown
                readonly property var choices: root.innerChoices[draft.eap] || []
                width: parent.width
                dropdownWidth: parent.width
                compactMode: true
                options: choices.map(i => i.label)
                Binding {
                    target: innerDropdown
                    property: "currentValue"
                    value: innerDropdown.choices.some(c => c.value === draft.phase2) ? CE.choiceLabel(innerDropdown.choices, draft.phase2) : ""
                }
                onValueChanged: value => draft.phase2 = CE.choiceValue(choices, value)
            }
        }
    }

    DTextField {
        id: identityField
        width: parent.width
        expressive: root.expressive
        outlined: !root.expressive
        controlHeight: root.expressive ? DCommon.Style.buttonHeightM : Theme.fieldHeightLarge
        leftIconName: "person"
        font.pixelSize: Theme.fontSizeMedium
        textColor: Theme.surfaceText
        labelText: I18n.tr("Username", "text field label for network, vpn and account forms")
        supportingText: root.usernameSuffix ? "@" + root.usernameSuffix : ""
        isError: root.usernameSuffixRequired && !CE.identityMatchesSuffix(text.trim(), root.usernameSuffix)
        text: draft.identity
        onTextEdited: draft.identity = text
        onAccepted: passwordField.visible ? passwordField.forceActiveFocus() : root.submitRequested()
    }

    DTextField {
        id: passwordField
        visible: draft.savePassword
        width: parent.width
        expressive: root.expressive
        outlined: !root.expressive
        controlHeight: root.expressive ? DCommon.Style.buttonHeightM : Theme.fieldHeightLarge
        leftIconName: "lock"
        font.pixelSize: Theme.fontSizeMedium
        textColor: Theme.surfaceText
        showPasswordToggle: true
        morph: root.expressive
        echoMode: passwordVisible ? TextInput.Normal : TextInput.Password
        labelText: root.isTls ? I18n.tr("Private Key Password") : I18n.tr("Password")
        text: root.isTls ? draft.privateKeyPassword : draft.password
        onTextEdited: {
            if (root.isTls)
                draft.privateKeyPassword = text;
            else
                draft.password = text;
        }
        onAccepted: anonField.visible ? anonField.forceActiveFocus() : root.submitRequested()
    }

    DToggle {
        width: parent.width
        text: I18n.tr("Save password")
        checked: draft.savePassword
        onToggled: checked => draft.savePassword = checked
    }

    DTextField {
        id: anonField
        visible: root.usesInner
        width: parent.width
        expressive: root.expressive
        outlined: !root.expressive
        controlHeight: root.expressive ? DCommon.Style.buttonHeightM : Theme.fieldHeightLarge
        leftIconName: "person_off"
        font.pixelSize: Theme.fontSizeMedium
        textColor: Theme.surfaceText
        labelText: I18n.tr("Anonymous Identity (optional)")
        text: draft.anonymousIdentity
        onTextEdited: draft.anonymousIdentity = text
        onAccepted: root.submitRequested()
    }

    DDropdown {
        id: caDropdown
        visible: root.usesCa
        width: parent.width
        text: I18n.tr("CA certificate", "network authentication certificate file field")
        options: root.caChoices.map(a => a.label)
        Binding {
            target: caDropdown
            property: "currentValue"
            value: CE.choiceLabel(root.caChoices, draft.ca)
        }
        onValueChanged: value => draft.ca = CE.choiceValue(root.caChoices, value)
    }

    PathField {
        visible: root.usesCa && draft.ca === "file"
        target: "ca"
        labelText: I18n.tr("File")
        text: draft.caCertPem ? root.caDisplayName : root.storedLabel("ca", draft.caCertPath)
    }

    StyledText {
        visible: root.usesCa && draft.ca === "none"
        width: parent.width
        text: I18n.tr("Without a CA certificate the server is not verified, and a fake network can capture the password.", "802.1X warning when no CA certificate is set")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    Row {
        visible: root.usesCa
        width: parent.width
        spacing: Theme.spacingS

        DTextField {
            width: parent.width - matchDropdown.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            expressive: root.expressive
            outlined: !root.expressive
            controlHeight: root.expressive ? DCommon.Style.buttonHeightM : Theme.fieldHeightLarge
            leftIconName: "domain"
            font.pixelSize: Theme.fontSizeMedium
            textColor: Theme.surfaceText
            labelText: I18n.tr("Server")
            isError: draft.ca === "system" && !text.trim()
            text: draft.serverDomain
            onTextEdited: draft.serverDomain = text
        }

        DDropdown {
            id: matchDropdown
            width: Math.round(parent.width / 3)
            dropdownWidth: width
            anchors.verticalCenter: parent.verticalCenter
            compactMode: true
            options: root.matchChoices.map(m => m.label)
            Binding {
                target: matchDropdown
                property: "currentValue"
                value: CE.choiceLabel(root.matchChoices, draft.serverDomainSuffix)
            }
            onValueChanged: value => draft.serverDomainSuffix = CE.choiceValue(root.matchChoices, value)
        }
    }

    PathField {
        visible: root.isTls
        target: "clientCert"
        labelText: I18n.tr("Client certificate", "network authentication certificate file field")
        text: root.storedLabel("clientCert", draft.clientCertPath)
    }

    PathField {
        visible: root.isTls
        target: "privateKey"
        labelText: I18n.tr("Private key", "network authentication key file field")
        text: root.storedLabel("privateKey", draft.privateKeyPath)
    }

    DCollapsibleSection {
        width: parent.width
        title: I18n.tr("Advanced")

        Column {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DDropdown {
                id: peapVersionDropdown
                visible: draft.eap === "peap"
                width: parent.width
                text: I18n.tr("PEAP version", "802.1X advanced option")
                options: root.peapVersionChoices.map(v => v.label)
                Binding {
                    target: peapVersionDropdown
                    property: "currentValue"
                    value: CE.choiceLabel(root.peapVersionChoices, draft.peapVersion)
                }
                onValueChanged: value => draft.peapVersion = CE.choiceValue(root.peapVersionChoices, value)
            }

            // phase1-auth-flags: tls-1-0-enable 0x20, tls-1-1-enable 0x40, tls-1-3-disable 0x10
            DToggle {
                width: parent.width
                text: I18n.tr("Allow TLS 1.0 and 1.1", "802.1X advanced option")
                checked: (draft.authFlags & 0x60) === 0x60
                onToggled: checked => draft.authFlags = CE.withFlags(draft.authFlags, 0x60, checked)
            }

            DToggle {
                width: parent.width
                text: I18n.tr("Disable TLS 1.3", "802.1X advanced option")
                checked: (draft.authFlags & 0x10) !== 0
                onToggled: checked => draft.authFlags = CE.withFlags(draft.authFlags, 0x10, checked)
            }

            DTextField {
                width: parent.width
                expressive: root.expressive
                outlined: !root.expressive
                controlHeight: root.expressive ? DCommon.Style.buttonHeightM : Theme.fieldHeightLarge
                font.pixelSize: Theme.fontSizeMedium
                textColor: Theme.surfaceText
                labelText: I18n.tr("OpenSSL ciphers", "802.1X advanced option")
                text: draft.opensslCiphers
                onTextEdited: draft.opensslCiphers = text
            }
        }
    }
}
