import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: entry

    required property string filePath
    required property string fileName
    required property string fileExtension
    required property string fileType
    required property string dirPath
    required property bool isSelected
    required property int itemIndex

    signal clicked()

    readonly property int iconSize: 40

    radius: Theme.cornerRadius
    color: isSelected ? Theme.primaryPressed : mouseArea.containsMouse ? Theme.primaryHoverLight : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingL

        Item {
            width: iconSize
            height: iconSize
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: imagePreview
                anchors.fill: parent
                source: fileType === "image" ? `file://${filePath}` : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                cache: true
                asynchronous: true
                visible: fileType === "image" && status === Image.Ready
                sourceSize.width: 128
                sourceSize.height: 128
            }

            MultiEffect {
                anchors.fill: parent
                source: imagePreview
                maskEnabled: true
                maskSource: imageMask
                visible: fileType === "image" && imagePreview.status === Image.Ready
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Item {
                id: imageMask
                width: iconSize
                height: iconSize
                layer.enabled: true
                layer.smooth: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "black"
                    antialiasing: true
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: getFileTypeColor()
                visible: fileType !== "image" || imagePreview.status !== Image.Ready

                StyledText {
                    anchors.centerIn: parent
                    text: getFileIconText()
                    font.pixelSize: fileExtension.length > 0 ? (fileExtension.length > 3 ? Theme.fontSizeSmall - 2 : Theme.fontSizeSmall) : Theme.fontSizeMedium
                    color: Theme.surfaceText
                    font.weight: Font.Bold
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - iconSize - Theme.spacingL
            spacing: Theme.spacingXS

            StyledText {
                width: parent.width
                text: fileName
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
                maximumLineCount: 1
            }

            StyledText {
                width: parent.width
                text: dirPath
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: entry.clicked()
    }

    function getFileTypeColor() {
        switch (fileType) {
        case "code":
            return Theme.codeFileColor || Theme.primarySelected
        case "document":
            return Theme.docFileColor || Theme.secondarySelected
        case "video":
            return Theme.videoFileColor || Theme.tertiarySelected
        case "audio":
            return Theme.audioFileColor || Theme.errorSelected
        case "archive":
            return Theme.archiveFileColor || Theme.warningSelected
        case "binary":
            return Theme.binaryFileColor || Theme.surfaceDim
        default:
            return Theme.surfaceLight
        }
    }

    function getFileIconText() {
        if (fileType === "binary") {
            return "bin"
        }

        if (fileExtension.length > 0) {
            return fileExtension
        }

        return fileName.charAt(0).toUpperCase()
    }
}
