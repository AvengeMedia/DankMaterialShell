import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// Sign-in for a provider that is waiting to be linked.
//
// Which of the three forms is shown follows what the bridge asked for: a QR to
// scan, a code to type elsewhere, or a URL to open. Rendering the QR is done by
// the backend so no bridge author has to produce an image.
Item {
    id: root

    property var provider: null

    readonly property string providerId: provider?.id ?? ""
    readonly property string providerName: provider?.name || providerId
    readonly property string method: provider?.authMethod ?? ""
    readonly property string payload: provider?.authPayload ?? ""

    property string qrImagePath: ""
    property bool requesting: false

    // Re-render whenever the challenge changes. These rotate on a timer for
    // most services, so a stale image is a sign-in that silently will not work.
    onPayloadChanged: refreshChallenge()
    onVisibleChanged: {
        // Only render if there is nothing to show yet: payloadChanged already
        // covers rotation, and rendering on every visibility flip meant two
        // concurrent requests racing over the same output file.
        if (visible && root.qrImagePath === "")
            refreshChallenge();
    }

    function refreshChallenge() {
        root.qrImagePath = "";
        if (!visible || root.providerId === "" || root.payload === "")
            return;
        if (root.method !== "qr")
            return;

        root.requesting = true;
        DMSService.sendRequest("chat.authQrCode", {
            "provider": root.providerId
        }, response => {
            root.requesting = false;
            if (response.error) {
                ChatService.log.warn("could not render sign-in code:", response.error);
                return;
            }
            root.qrImagePath = response.result?.path || "";
        });
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(360, parent.width - Theme.spacingXL * 2)
        spacing: Theme.spacingM

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("Sign in to %1").arg(root.providerName)
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            text: {
                switch (root.method) {
                case "qr":
                    return I18n.tr("Scan this code with the app on your phone.");
                case "code":
                    return I18n.tr("Enter this code in the app on your other device.");
                case "url":
                    return I18n.tr("Open this link to finish signing in.");
                default:
                    return I18n.tr("Start sign-in to link this device.");
                }
            }
        }

        // ------------------------------------------------------------ QR

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.method === "qr"
            width: 220
            height: 220

            // White plate behind the code: scanners need the contrast, and a
            // transparent code on a dark surface often will not read.
            StyledRect {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: "white"
                visible: qrImage.status === Image.Ready
            }

            Image {
                id: qrImage
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                smooth: false
                mipmap: false
                // No cache: the payload rotates, and a cached pixmap would keep
                // showing a code that has already expired.
                cache: false
                source: root.qrImagePath !== "" ? "file://" + root.qrImagePath : ""
            }

            DankSpinner {
                anchors.centerIn: parent
                width: 32
                height: 32
                visible: root.requesting || (root.qrImagePath !== "" && qrImage.status === Image.Loading)
            }
        }

        // ---------------------------------------------------------- code

        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.method === "code" && root.payload !== ""
            width: codeText.implicitWidth + Theme.spacingXL * 2
            height: codeText.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: codeText
                anchors.centerIn: parent
                text: root.payload
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.monoFontFamily
                font.letterSpacing: 2
                color: Theme.surfaceText
            }
        }

        // ----------------------------------------------------------- url

        DankButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.method === "url" && root.payload !== ""
            text: I18n.tr("Open sign-in page")
            iconName: "open_in_new"
            backgroundColor: Theme.primary
            textColor: Theme.onPrimary
            onClicked: Quickshell.execDetached(["xdg-open", root.payload])
        }

        // Always offered: a challenge may have expired, and asking again is the
        // only way forward.
        DankButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.payload === "" ? I18n.tr("Start sign-in") : I18n.tr("Get a new code")
            iconName: "refresh"
            backgroundColor: root.payload === "" ? Theme.primary : "transparent"
            textColor: root.payload === "" ? Theme.onPrimary : Theme.surfaceText
            onClicked: ChatService.login(root.providerId)
        }
    }
}
