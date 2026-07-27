import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root
    visible: false
    layerNamespace: "dms:qr-generator"

    property bool disablePopupTransparency: true
    property bool generating: false
    property string themedQrCodePath: ""
    property string normalQrCodePath: ""
    modalWidth: 420
    modalHeight: 440
    onBackgroundClicked: hide()
    onOpened: {
        Qt.callLater(() => {
            modalFocusScope.forceActiveFocus();
            if (contentLoader.item?.textInput) {
                contentLoader.item.textInput.forceActiveFocus();
            }
            contentLoader.item.saveBrowserLoader = saveBrowserLoader;
        });
    }

    function show() {
        generating = false;
        open();
    }

    function hide() {
        if (themedQrCodePath.length > 0)
            DMSService.sendRequest("network.delete-qrcode", {path: themedQrCodePath});
        if (normalQrCodePath.length > 0)
            DMSService.sendRequest("network.delete-qrcode", {path: normalQrCodePath});
        close();
    }

    Timer {
        id: genTimer
        interval: 200
        repeat: false
        onTriggered: root.generateQR(root._pendingPayload)
    }

    property string _pendingPayload: ""
    property string _generatingPayload: ""
    property string _pendingThemed: ""
    property string _pendingNormal: ""

    function generateQR(text) {
        if (!text || text.trim().length === 0 || generating)
            return;

        var trimmed = text.trim();
        if (!contentLoader.item)
            return;

        _generatingPayload = trimmed;
        generating = true;

        DMSService.sendRequest("network.qrcode.generate", {text: trimmed}, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to generate QR code: %1").arg(JSON.stringify(response.error)));
                root.generating = false;
            } else if (response.result && contentLoader.item) {
                if (root._generatingPayload !== root._pendingPayload) {
                    root.generating = false;
                    return;
                }
                _pendingThemed = response.result[0];
                _pendingNormal = response.result[1];
                if (contentLoader.item?.qrContainer)
                    contentLoader.item.qrContainer.opacity = 0;
            }
        });
    }

    function onTextChanged(text) {
        _pendingPayload = text;
        if (!text || text.trim().length === 0) {
            genTimer.stop();
            return;
        }
        genTimer.restart();
    }

    LazyLoader {
        id: saveBrowserLoader
        active: false

        FileBrowserSurfaceModal {
            id: saveBrowser

            browserTitle: I18n.tr("Save QR Code")
            browserIcon: "qr_code"
            browserType: "default"
            fileExtensions: ["*.png"]
            allowStacking: true
            saveMode: true
            defaultFileName: "qrcode.png"
            onFileSelected: path => {
                const cleanPath = decodeURI(path.toString().replace(/^file:\/\//, ''));
                copyQrCodeProcess.exec(["cp", root.normalQrCodePath, cleanPath, "-f"]);
            }

            Process {
                id: copyQrCodeProcess

                stdout: StdioCollector {
                    onStreamFinished: {
                        saveBrowser.close();
                    }
                }
            }
        }
    }

    content: Component {
            Item {
                id: theItem
                property alias themedQrCodePath: qrCodeImg.source
                property alias textInput: textInput
                property alias qrContainer: qrContainer
                property var saveBrowserLoader: null
                anchors.fill: parent


            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL

                RowLayout {
                    id: modalTitle
                    width: parent.width

                    StyledText {
                        text: I18n.tr("QR Generator")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignLeft
                        Layout.fillWidth: true
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hide()
                        Layout.alignment: Qt.AlignRight
                    }
                }

                DankTextField {
                    id: textInput
                    width: parent.width
                    placeholderText: I18n.tr("Enter text to encode")
                    showClearButton: true
                    focus: true
                    onTextEdited: root.onTextChanged(text)
                    Keys.onEscapePressed: event => {
                        event.accepted = true;
                        root.hide();
                    }
                }

                Item {
                    id: qrContainer
                    height: Math.min(parent.height - parent.spacing - modalTitle.height - textInput.height - parent.spacing * 4, 260)
                    width: height
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 1

                    Behavior on opacity { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                    onOpacityChanged: {
                        if (opacity <= 0 && root._pendingThemed.length > 0) {
                            var oldThemed = root.themedQrCodePath;
                            var oldNormal = root.normalQrCodePath;
                            root.themedQrCodePath = root._pendingThemed;
                            root.normalQrCodePath = root._pendingNormal;
                            themedQrCodePath = root._pendingThemed;
                            root._pendingThemed = "";
                            root._pendingNormal = "";
                            root.generating = false;
                            if (oldThemed.length > 0)
                                DMSService.sendRequest("network.delete-qrcode", {path: oldThemed});
                            if (oldNormal.length > 0)
                                DMSService.sendRequest("network.delete-qrcode", {path: oldNormal});
                        }
                    }

                    Image {
                        id: qrCodeImg
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true

                        onStatusChanged: {
                            if (status === Image.Ready)
                                qrContainer.opacity = 1;
                        }

                        MultiEffect {
                            source: qrCodeImg
                            anchors.fill: source
                            colorization: 1.0
                            colorizationColor: Theme.primary
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    visible: root.themedQrCodePath.length > 0
                    Layout.alignment: Qt.AlignHCenter

                    Item {
                        Layout.fillWidth: true
                    }

                    DankButton {
                        text: I18n.tr("Save")
                        iconName: "save"
                        backgroundColor: Theme.surfaceContainer
                        textColor: Theme.surfaceText
                        onClicked: {
                            saveBrowserLoader.active = true;
                            if (saveBrowserLoader.item) {
                                saveBrowserLoader.item.open();
                            }
                        }
                    }

                    DankButton {
                        text: I18n.tr("Copy")
                        iconName: "content_copy"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        onClicked: {
                            if (root.normalQrCodePath.length > 0)
                                DMSService.sendRequest("clipboard.copyFile", {filePath: root.normalQrCodePath});
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
