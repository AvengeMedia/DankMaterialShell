import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: saveRow

    property bool saveMode: false
    property string defaultFileName: ""
    property string currentPath: ""

    signal saveRequested(string filePath)

    height: saveMode ? 40 : 0
    visible: saveMode
    spacing: Theme.spacingM

    DankTextField {
        id: fileNameInput

        width: parent.width - saveButton.width - Theme.spacingM
        height: 40
        text: defaultFileName
        placeholderText: I18n.tr("Enter filename...")
        ignoreLeftRightKeys: false
        focus: saveMode
        topPadding: Theme.spacingS
        bottomPadding: Theme.spacingS
        Component.onCompleted: {
            if (saveMode)
                Qt.callLater(() => {
                    forceActiveFocus();
                });
        }
        onAccepted: {
            if (text.trim() !== "") {
                var basePath = currentPath.replace(/^file:\/\//, '');
                var fullPath = basePath + "/" + text.trim();
                fullPath = fullPath.replace(/\/+/g, '/');
                saveRequested(fullPath);
            }
        }
    }

    StyledRect {
        id: saveButton

        width: 80
        height: 40
        color: fileNameInput.text.trim() !== "" ? Theme.primary : Theme.surfaceVariant
        radius: Theme.cornerRadius

        StyledText {
            anchors.centerIn: parent
            text: I18n.tr("Save")
            color: fileNameInput.text.trim() !== "" ? Theme.primaryText : Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
        }

        StateLayer {
            stateColor: Theme.primary
            cornerRadius: Theme.cornerRadius
            enabled: fileNameInput.text.trim() !== ""
            onClicked: {
                if (fileNameInput.text.trim() !== "") {
                    var basePath = currentPath.replace(/^file:\/\//, '');
                    var fullPath = basePath + "/" + fileNameInput.text.trim();
                    fullPath = fullPath.replace(/\/+/g, '/');
                    saveRequested(fullPath);
                }
            }
        }
    }
}
