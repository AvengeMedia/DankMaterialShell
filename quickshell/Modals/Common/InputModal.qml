import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:input-modal"
    keepPopoutsOpen: true

    property string inputTitle: ""
    property string inputMessage: ""
    property string inputPlaceholder: ""
    property string inputText: ""
    property string confirmButtonText: "Confirm"
    property string cancelButtonText: "Cancel"
    property color confirmButtonColor: Theme.primary
    property var onConfirm: function (text) {}
    property var onCancel: function () {}
    property int selectedButton: -1
    property bool keyboardNavigation: false

    function show(title, message, onConfirmCallback, onCancelCallback) {
        inputTitle = title || "";
        inputMessage = message || "";
        inputPlaceholder = "";
        inputText = "";
        confirmButtonText = "Confirm";
        cancelButtonText = "Cancel";
        confirmButtonColor = Theme.primary;
        onConfirm = onConfirmCallback || ((text) => {});
        onCancel = onCancelCallback || (() => {});
        selectedButton = -1;
        keyboardNavigation = false;
        open();
    }

    function showWithOptions(options) {
        inputTitle = options.title || "";
        inputMessage = options.message || "";
        inputPlaceholder = options.placeholder || "";
        inputText = options.initialText || "";
        confirmButtonText = options.confirmText || "Confirm";
        cancelButtonText = options.cancelText || "Cancel";
        confirmButtonColor = options.confirmColor || Theme.primary;
        onConfirm = options.onConfirm || ((text) => {});
        onCancel = options.onCancel || (() => {});
        selectedButton = -1;
        keyboardNavigation = false;
        open();
    }

    function confirmAndClose() {
        const text = inputText;
        close();
        if (onConfirm) {
            onConfirm(text);
        }
    }

    function cancelAndClose() {
        close();
        if (onCancel) {
            onCancel();
        }
    }

    function selectButton() {
        if (selectedButton === 0) {
            cancelAndClose();
        } else {
            confirmAndClose();
        }
    }

    shouldBeVisible: false
    allowStacking: true
    modalWidth: 350
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight + Theme.spacingM * 2 : 200
    enableShadow: true
    shouldHaveFocus: true
    onBackgroundClicked: cancelAndClose()
    onOpened: {
        Qt.callLater(function () {
            if (contentLoader.item && contentLoader.item.textInputRef) {
                contentLoader.item.textInputRef.forceActiveFocus();
            }
        });
    }

    content: Component {
        FocusScope {
            anchors.fill: parent
            implicitHeight: mainColumn.implicitHeight
            focus: true

            property alias textInputRef: textInput

            Keys.onPressed: function (event) {
                const textFieldFocused = textInput.activeFocus;

                switch (event.key) {
                case Qt.Key_Escape:
                    root.cancelAndClose();
                    event.accepted = true;
                    break;
                case Qt.Key_Tab:
                    if (textFieldFocused) {
                        root.keyboardNavigation = true;
                        root.selectedButton = 0;
                        textInput.focus = false;
                    } else {
                        root.keyboardNavigation = true;
                        if (root.selectedButton === -1) {
                            root.selectedButton = 0;
                        } else if (root.selectedButton === 0) {
                            root.selectedButton = 1;
                        } else {
                            root.selectedButton = -1;
                            textInput.forceActiveFocus();
                        }
                    }
                    event.accepted = true;
                    break;
                case Qt.Key_Left:
                    if (!textFieldFocused) {
                        root.keyboardNavigation = true;
                        root.selectedButton = 0;
                        event.accepted = true;
                    }
                    break;
                case Qt.Key_Right:
                    if (!textFieldFocused) {
                        root.keyboardNavigation = true;
                        root.selectedButton = 1;
                        event.accepted = true;
                    }
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (root.selectedButton !== -1) {
                        root.selectButton();
                    } else {
                        root.confirmAndClose();
                    }
                    event.accepted = true;
                    break;
                }
            }

            Column {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.topMargin: Theme.spacingL
                spacing: 0

                StyledText {
                    text: root.inputTitle
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                Item {
                    width: 1
                    height: Theme.spacingL
                }

                StyledText {
                    text: root.inputMessage
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: root.inputMessage !== ""
                }

                Item {
                    width: 1
                    height: root.inputMessage !== "" ? Theme.spacingL : 0
                    visible: root.inputMessage !== ""
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    radius: Theme.cornerRadius
                    color: Theme.surfaceVariantAlpha
                    border.color: textInput.activeFocus ? Theme.primary : "transparent"
                    border.width: textInput.activeFocus ? 1 : 0

                    TextInput {
                        id: textInput

                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.primaryText
                        clip: true
                        text: root.inputText
                        onTextChanged: root.inputText = text

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Theme.fontSizeMedium
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                            text: root.inputPlaceholder
                            visible: textInput.text === "" && !textInput.activeFocus
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.spacingL * 1.5
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 120
                        height: 40
                        radius: Theme.cornerRadius
                        color: {
                            if (root.keyboardNavigation && root.selectedButton === 0) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                            } else if (cancelButton.containsMouse) {
                                return Theme.surfacePressed;
                            } else {
                                return Theme.surfaceVariantAlpha;
                            }
                        }
                        border.color: (root.keyboardNavigation && root.selectedButton === 0) ? Theme.primary : "transparent"
                        border.width: (root.keyboardNavigation && root.selectedButton === 0) ? 1 : 0

                        StyledText {
                            text: root.cancelButtonText
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: cancelButton

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelAndClose()
                        }
                    }

                    Rectangle {
                        width: 120
                        height: 40
                        radius: Theme.cornerRadius
                        color: {
                            const baseColor = root.confirmButtonColor;
                            if (root.keyboardNavigation && root.selectedButton === 1) {
                                return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 1);
                            } else if (confirmButton.containsMouse) {
                                return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.9);
                            } else {
                                return baseColor;
                            }
                        }
                        border.color: (root.keyboardNavigation && root.selectedButton === 1) ? "white" : "transparent"
                        border.width: (root.keyboardNavigation && root.selectedButton === 1) ? 1 : 0

                        StyledText {
                            text: root.confirmButtonText
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primaryText
                            font.weight: Font.Medium
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: confirmButton

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.confirmAndClose()
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.spacingL
                }
            }
        }
    }
}
