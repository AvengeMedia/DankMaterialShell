import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

StyledRect {
    id: delegateRoot

    required property bool fileIsDir
    required property string filePath
    required property string fileName
    required property int index

    property bool weMode: false
    property var iconSizes: [80, 120, 160, 200]
    property int iconSizeIndex: 1
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false

    signal itemClicked(int index, string path, string name, bool isDir)
    signal itemSelected(int index, string path, string name, bool isDir)

    function getFileExtension(fileName) {
        const parts = fileName.split('.');
        if (parts.length > 1) {
            return parts[parts.length - 1].toLowerCase();
        }
        return "";
    }

    function determineFileType(fileName) {
        const ext = getFileExtension(fileName);

        const imageExts = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "svg", "ico", "jxl", "avif", "heif", "exr"];
        if (imageExts.includes(ext)) {
            return "image";
        }

        const videoExts = ["mp4", "mkv", "avi", "mov", "webm", "flv", "wmv", "m4v"];
        if (videoExts.includes(ext)) {
            return "video";
        }

        const audioExts = ["mp3", "wav", "flac", "ogg", "m4a", "aac", "wma"];
        if (audioExts.includes(ext)) {
            return "audio";
        }

        const codeExts = ["js", "ts", "jsx", "tsx", "py", "go", "rs", "c", "cpp", "h", "java", "kt", "swift", "rb", "php", "html", "css", "scss", "json", "xml", "yaml", "yml", "toml", "sh", "bash", "zsh", "fish", "qml", "vue", "svelte"];
        if (codeExts.includes(ext)) {
            return "code";
        }

        const docExts = ["txt", "md", "pdf", "doc", "docx", "odt", "rtf"];
        if (docExts.includes(ext)) {
            return "document";
        }

        const archiveExts = ["zip", "tar", "gz", "bz2", "xz", "7z", "rar"];
        if (archiveExts.includes(ext)) {
            return "archive";
        }

        if (!ext || fileName.indexOf('.') === -1) {
            return "binary";
        }

        return "file";
    }

    function isImageFile(fileName) {
        if (!fileName) {
            return false;
        }
        return determineFileType(fileName) === "image";
    }

    function isVideoFile(fileName) {
        if (!fileName) {
            return false;
        }
        return determineFileType(fileName) === "video";
    }

    property string _cacheDir: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
    property string _thumbnailSize: iconSizeIndex >= 2 ? "x-large" : "large"
    property int _thumbnailPx: iconSizeIndex >= 2 ? 512 : 256
    property string videoThumbnailPath: {
        if (!delegateRoot.fileIsDir && isVideoFile(delegateRoot.fileName)) {
            const hash = Qt.md5("file://" + delegateRoot.filePath);
            return _cacheDir + "/thumbnails/" + _thumbnailSize + "/" + hash + ".png";
        }
        return "";
    }

    function getIconForFile(fileName) {
        const lowerName = fileName.toLowerCase();
        if (lowerName.startsWith("dockerfile")) {
            return "docker";
        }
        const ext = fileName.split('.').pop();
        return ext || "";
    }

    width: weMode ? 245 : iconSizes[iconSizeIndex] + 16
    height: weMode ? 205 : iconSizes[iconSizeIndex] + 48
    radius: Theme.cornerRadius
    color: {
        if (keyboardNavigationActive && delegateRoot.index === selectedIndex)
            return Theme.surfacePressed;

        return mouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent";
    }
    border.color: keyboardNavigationActive && delegateRoot.index === selectedIndex ? Theme.primary : "transparent"
    border.width: (keyboardNavigationActive && delegateRoot.index === selectedIndex) ? 2 : 0

    Component.onCompleted: {
        if (keyboardNavigationActive && delegateRoot.index === selectedIndex)
            itemSelected(delegateRoot.index, delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir);
    }

    onSelectedIndexChanged: {
        if (keyboardNavigationActive && selectedIndex === delegateRoot.index)
            itemSelected(delegateRoot.index, delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir);
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Item {
            width: weMode ? 225 : (iconSizes[iconSizeIndex] - 8)
            height: weMode ? 165 : (iconSizes[iconSizeIndex] - 8)
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                id: gridPreviewImage
                anchors.fill: parent
                anchors.margins: 2
                property var weExtensions: [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tga", ".jxl", ".avif", ".heif", ".exr"]
                property int weExtIndex: 0
                property string imagePath: {
                    if (weMode && delegateRoot.fileIsDir)
                        return delegateRoot.filePath + "/preview" + weExtensions[weExtIndex];
                    if (!delegateRoot.fileIsDir && isImageFile(delegateRoot.fileName))
                        return delegateRoot.filePath;
                    if (videoThumbnailPath)
                        return videoThumbnailPath;
                    return "";
                }
                source: imagePath ? "file://" + imagePath.split('/').map(s => encodeURIComponent(s)).join('/') : ""
                onStatusChanged: {
                    if (weMode && delegateRoot.fileIsDir && status === Image.Error) {
                        if (weExtIndex < weExtensions.length - 1) {
                            weExtIndex++;
                        } else {
                            imagePath = "";
                        }
                    }
                    if (status === Image.Error && videoThumbnailPath) {
                        const thumbPath = videoThumbnailPath;
                        const thumbDir = _cacheDir + "/thumbnails/" + _thumbnailSize;
                        const size = _thumbnailPx;
                        Proc.runCommand("vidthumb-" + delegateRoot.filePath, ["sh", "-c", "mkdir -p '" + thumbDir + "' && ffmpegthumbnailer -i '" + delegateRoot.filePath + "' -o '" + thumbPath + "' -s " + String(size) + " -f"], function(output, exitCode) {
                            if (exitCode === 0) {
                                gridPreviewImage.imagePath = "";
                                gridPreviewImage.imagePath = thumbPath;
                            }
                        });
                    }
                }
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: weMode ? 225 : iconSizes[iconSizeIndex]
                sourceSize.height: weMode ? 225 : iconSizes[iconSizeIndex]
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                anchors.margins: 2
                source: gridPreviewImage
                maskEnabled: true
                maskSource: gridImageMask
                visible: gridPreviewImage.status === Image.Ready && ((!delegateRoot.fileIsDir && (isImageFile(delegateRoot.fileName) || isVideoFile(delegateRoot.fileName))) || (weMode && delegateRoot.fileIsDir))
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Item {
                id: gridImageMask
                anchors.fill: parent
                anchors.margins: 2
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
                name: delegateRoot.fileIsDir ? "folder" : getIconForFile(delegateRoot.fileName)
                size: iconSizes[iconSizeIndex] * 0.45
                color: delegateRoot.fileIsDir ? Theme.primary : Theme.surfaceText
                visible: (!delegateRoot.fileIsDir && !isImageFile(delegateRoot.fileName) && !(isVideoFile(delegateRoot.fileName) && gridPreviewImage.status === Image.Ready)) || (delegateRoot.fileIsDir && !weMode)
            }
        }

        StyledText {
            text: delegateRoot.fileName || ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            width: delegateRoot.width - Theme.spacingM
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            itemClicked(delegateRoot.index, delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir);
        }
    }
}
