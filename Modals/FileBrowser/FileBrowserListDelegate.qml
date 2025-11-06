import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

StyledRect {
    id: listDelegateRoot

    required property bool fileIsDir
    required property string filePath
    required property string fileName
    required property int index
    required property var fileModified
    required property int fileSize

    property int selectedIndex: -1
    property bool keyboardNavigationActive: false

    signal itemClicked(int index, string path, string name, bool isDir)
    signal itemSelected(int index, string path, string name, bool isDir)

    function getFileExtension(fileName) {
        const parts = fileName.split('.')
        if (parts.length > 1) {
            return parts[parts.length - 1].toLowerCase()
        }
        return ""
    }

    function determineFileType(fileName) {
        const ext = getFileExtension(fileName)

        const imageExts = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "svg", "ico"]
        if (imageExts.includes(ext)) {
            return "image"
        }

        const videoExts = ["mp4", "mkv", "avi", "mov", "webm", "flv", "wmv", "m4v"]
        if (videoExts.includes(ext)) {
            return "video"
        }

        const audioExts = ["mp3", "wav", "flac", "ogg", "m4a", "aac", "wma"]
        if (audioExts.includes(ext)) {
            return "audio"
        }

        const codeExts = ["js", "ts", "jsx", "tsx", "py", "go", "rs", "c", "cpp", "h", "java", "kt", "swift", "rb", "php", "html", "css", "scss", "json", "xml", "yaml", "yml", "toml", "sh", "bash", "zsh", "fish", "qml", "vue", "svelte"]
        if (codeExts.includes(ext)) {
            return "code"
        }

        const docExts = ["txt", "md", "pdf", "doc", "docx", "odt", "rtf"]
        if (docExts.includes(ext)) {
            return "document"
        }

        const archiveExts = ["zip", "tar", "gz", "bz2", "xz", "7z", "rar"]
        if (archiveExts.includes(ext)) {
            return "archive"
        }

        if (!ext || fileName.indexOf('.') === -1) {
            return "binary"
        }

        return "file"
    }

    function isImageFile(fileName) {
        if (!fileName) {
            return false
        }
        return determineFileType(fileName) === "image"
    }

    function getIconForFile(fileName) {
        const lowerName = fileName.toLowerCase()
        if (lowerName.startsWith("dockerfile")) {
            return "docker"
        }
        const ext = fileName.split('.').pop()
        return ext || ""
    }

    function formatFileSize(size) {
        if (size < 1024)
            return size + " B"
        if (size < 1024 * 1024)
            return (size / 1024).toFixed(1) + " KB"
        if (size < 1024 * 1024 * 1024)
            return (size / (1024 * 1024)).toFixed(1) + " MB"
        return (size / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    height: 44
    radius: Theme.cornerRadius
    color: {
        if (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)
            return Theme.surfacePressed
        return listMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"
    }
    border.color: keyboardNavigationActive && listDelegateRoot.index === selectedIndex ? Theme.primary : "transparent"
    border.width: (keyboardNavigationActive && listDelegateRoot.index === selectedIndex) ? 2 : 0

    Component.onCompleted: {
        if (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)
            itemSelected(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir)
    }

    onSelectedIndexChanged: {
        if (keyboardNavigationActive && selectedIndex === listDelegateRoot.index)
            itemSelected(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir)
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingS

        Item {
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter

            CachingImage {
                id: listPreviewImage
                anchors.fill: parent
                source: (!listDelegateRoot.fileIsDir && isImageFile(listDelegateRoot.fileName)) ? ("file://" + listDelegateRoot.filePath) : ""
                fillMode: Image.PreserveAspectCrop
                maxCacheSize: 32
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: listPreviewImage
                maskEnabled: true
                maskSource: listImageMask
                visible: listPreviewImage.status === Image.Ready && !listDelegateRoot.fileIsDir && isImageFile(listDelegateRoot.fileName)
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Item {
                id: listImageMask
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: "black"
                    antialiasing: true
                }
            }

            DankNFIcon {
                anchors.centerIn: parent
                name: listDelegateRoot.fileIsDir ? "folder" : getIconForFile(listDelegateRoot.fileName)
                size: Theme.iconSize - 2
                color: listDelegateRoot.fileIsDir ? Theme.primary : Theme.surfaceText
                visible: listDelegateRoot.fileIsDir || !isImageFile(listDelegateRoot.fileName)
            }
        }

        StyledText {
            text: listDelegateRoot.fileName || ""
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            width: parent.width - 280
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            maximumLineCount: 1
            clip: true
        }

        StyledText {
            text: listDelegateRoot.fileIsDir ? "" : formatFileSize(listDelegateRoot.fileSize)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            width: 70
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: Qt.formatDateTime(listDelegateRoot.fileModified, "MMM d, yyyy h:mm AP")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            width: 140
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: listMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            itemClicked(listDelegateRoot.index, listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir)
        }
    }
}
