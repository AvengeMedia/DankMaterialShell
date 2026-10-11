pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
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

    component FormField: DTextField {
        width: parent.width
        expressive: root.expressive
        outlined: !root.expressive
    }

    // DDropdown assigns currentValue on pick, which drops a plain binding; the Binding re-applies it on reset.
    component ChoiceDropdown: DDropdown {
        id: choiceDropdown

        property var choices: []
        property var selected

        signal picked(var value)

        width: parent.width
        addHorizontalPadding: true
        options: choices.map(c => c.label)
        Binding {
            target: choiceDropdown
            property: "currentValue"
            value: choiceDropdown.choices.some(c => c.value === choiceDropdown.selected) ? CE.choiceLabel(choiceDropdown.choices, choiceDropdown.selected) : ""
        }
        onValueChanged: value => choiceDropdown.picked(CE.choiceValue(choiceDropdown.choices, value))
    }

    component PathField: Row {
        id: pathField

        property alias text: pathInput.text
        property alias labelText: pathInput.labelText
        property alias leftIconName: pathInput.leftIconName
        property string target

        width: parent.width
        spacing: Theme.spacingS

        FormField {
            id: pathInput
            width: parent.width - browseButton.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            readOnly: true
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

    ChoiceDropdown {
        text: I18n.tr("Authentication")
        choices: root.methodChoices
        selected: draft.eap
        onPicked: eap => {
            if (eap === draft.eap)
                return;
            draft.eap = eap;
            draft.phase2 = root.defaultInner(eap);
        }
    }

    ChoiceDropdown {
        visible: root.usesInner
        text: I18n.tr("Inner authentication", "802.1X phase 2 authentication method")
        choices: root.innerChoices[draft.eap] || []
        selected: draft.phase2
        onPicked: value => draft.phase2 = value
    }

    FormField {
        id: identityField
        leftIconName: "person"
        labelText: I18n.tr("Username", "text field label for network, vpn and account forms")
        supportingText: root.usernameSuffix ? "@" + root.usernameSuffix : ""
        isError: root.usernameSuffixRequired && !CE.identityMatchesSuffix(text.trim(), root.usernameSuffix)
        text: draft.identity
        onTextEdited: draft.identity = text
        onAccepted: passwordField.visible ? passwordField.forceActiveFocus() : root.submitRequested()
    }

    FormField {
        id: passwordField
        visible: draft.savePassword
        leftIconName: "lock"
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

    FormField {
        id: anonField
        visible: root.usesInner
        leftIconName: "person_off"
        labelText: I18n.tr("Anonymous Identity (optional)")
        text: draft.anonymousIdentity
        onTextEdited: draft.anonymousIdentity = text
        onAccepted: root.submitRequested()
    }

    ChoiceDropdown {
        visible: root.usesCa
        text: I18n.tr("CA certificate", "network authentication certificate file field")
        choices: root.caChoices
        selected: draft.ca
        onPicked: value => draft.ca = value
    }

    PathField {
        visible: root.usesCa && draft.ca === "file"
        target: "ca"
        leftIconName: "verified_user"
        labelText: I18n.tr("File")
        text: draft.caCertPem ? root.caDisplayName : root.storedLabel("ca", draft.caCertPath)
    }

    StyledText {
        visible: root.usesCa && draft.ca === "none"
        width: parent.width
        leftPadding: Theme.spacingM
        rightPadding: Theme.spacingM
        text: I18n.tr("Without a CA certificate the server is not verified, and a fake network can capture the password.", "802.1X warning when no CA certificate is set")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    FormField {
        visible: root.usesCa
        leftIconName: "domain"
        labelText: I18n.tr("Server")
        isError: draft.ca === "system" && !text.trim()
        text: draft.serverDomain
        onTextEdited: draft.serverDomain = text
    }

    ChoiceDropdown {
        visible: root.usesCa
        text: I18n.tr("Match type", "802.1X server name match, exact or suffix")
        choices: root.matchChoices
        selected: draft.serverDomainSuffix
        onPicked: value => draft.serverDomainSuffix = value
    }

    PathField {
        visible: root.isTls
        target: "clientCert"
        leftIconName: "badge"
        labelText: I18n.tr("Client certificate", "network authentication certificate file field")
        text: root.storedLabel("clientCert", draft.clientCertPath)
    }

    PathField {
        visible: root.isTls
        target: "privateKey"
        leftIconName: "key"
        labelText: I18n.tr("Private key", "network authentication key file field")
        text: root.storedLabel("privateKey", draft.privateKeyPath)
    }

    DCollapsibleSection {
        width: parent.width
        title: I18n.tr("Advanced")
        showBackground: true

        Column {
            Layout.fillWidth: true
            spacing: root.spacing

            ChoiceDropdown {
                visible: draft.eap === "peap"
                text: I18n.tr("PEAP version", "802.1X advanced option")
                choices: root.peapVersionChoices
                selected: draft.peapVersion
                onPicked: value => draft.peapVersion = value
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

            FormField {
                leftIconName: "tune"
                labelText: I18n.tr("OpenSSL ciphers", "802.1X advanced option")
                text: draft.opensslCiphers
                onTextEdited: draft.opensslCiphers = text
            }
        }
    }
}
