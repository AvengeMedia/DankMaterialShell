import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: thumbnail

    required property var entry
    required property string entryType
    required property var modal
    required property var listView
    required property int itemIndex

    Image {
        id: thumbnailImage

        property bool isVisible: false
        property string cachedImageData: ""
        property bool loadQueued: false

        anchors.fill: parent
        source: cachedImageData ? `data:image/png;base64,${cachedImageData}` : ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: false
        visible: false
        asynchronous: true
        sourceSize.width: 128
        sourceSize.height: 128

        function tryLoadImage() {
            if (loadQueued || entryType !== "image" || cachedImageData) {
                return;
            }
            loadQueued = true;
            if (modal.activeImageLoads < modal.maxConcurrentLoads) {
                modal.activeImageLoads++;
                loadImage();
            } else {
                retryTimer.restart();
            }
        }

        function loadImage() {
            DMSService.sendRequest("clipboard.getEntry", {
                "id": entry.id
            }, function (response) {
                loadQueued = false;
                if (modal.activeImageLoads > 0) {
                    modal.activeImageLoads--;
                }
                if (response.error) {
                    console.warn("ClipboardThumbnail: Failed to load image:", entry.id);
                    return;
                }
                const data = response.result?.data;
                if (data) {
                    cachedImageData = data;
                }
            });
        }

        Timer {
            id: retryTimer
            interval: ClipboardConstants.retryInterval
            onTriggered: {
                if (!thumbnailImage.loadQueued) {
                    return;
                }
                if (modal.activeImageLoads < modal.maxConcurrentLoads) {
                    modal.activeImageLoads++;
                    thumbnailImage.loadImage();
                } else {
                    retryTimer.restart();
                }
            }
        }

        Component.onCompleted: {
            if (entryType !== "image" || listView.height <= 0) {
                return;
            }

            const itemY = itemIndex * (ClipboardConstants.itemHeight + listView.spacing);
            const viewTop = listView.contentY;
            const viewBottom = viewTop + listView.height;
            isVisible = (itemY + ClipboardConstants.itemHeight >= viewTop && itemY <= viewBottom);

            if (isVisible) {
                tryLoadImage();
            }
        }

        Timer {
            id: visibilityTimer
            interval: 100
            onTriggered: thumbnailImage.checkVisibility()
        }

        function checkVisibility() {
            if (entryType !== "image" || listView.height <= 0 || isVisible) {
                return;
            }
            const itemY = itemIndex * (ClipboardConstants.itemHeight + listView.spacing);
            const viewTop = listView.contentY - ClipboardConstants.viewportBuffer;
            const viewBottom = viewTop + listView.height + ClipboardConstants.extendedBuffer;
            const nowVisible = (itemY + ClipboardConstants.itemHeight >= viewTop && itemY <= viewBottom);
            if (nowVisible) {
                isVisible = true;
                tryLoadImage();
            }
        }

        Connections {
            target: listView

            function onContentYChanged() {
                if (thumbnailImage.isVisible || entryType !== "image") {
                    return;
                }
                visibilityTimer.restart();
            }

            function onHeightChanged() {
                if (thumbnailImage.isVisible || entryType !== "image") {
                    return;
                }
                visibilityTimer.restart();
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        anchors.margins: 2
        source: thumbnailImage
        maskEnabled: true
        maskSource: clipboardRoundedRectangularMask
        visible: entryType === "image" && thumbnailImage.status === Image.Ready && thumbnailImage.source != ""
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Item {
        id: clipboardRoundedRectangularMask
        width: ClipboardConstants.thumbnailSize
        height: ClipboardConstants.itemHeight - 4
        layer.enabled: true
        layer.smooth: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius / 2 // Thumbnail corner radius is divided by 2 so it doesnt look weird on large corner radius (eg: 32px)
            color: "black"
            antialiasing: true
        }
    }

    DankIcon {
        visible: !(entryType === "image" && thumbnailImage.status === Image.Ready && thumbnailImage.source != "")
        name: {
            switch (entryType) {
            case "image":
                return "image";
            case "long_text":
                return "subject";
            default:
                return "content_copy";
            }
        }
        size: Theme.iconSize
        color: Theme.primary
        anchors.centerIn: parent
    }
}
