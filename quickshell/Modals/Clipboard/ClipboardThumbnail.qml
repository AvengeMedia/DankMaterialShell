import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: thumbnail
    readonly property var log: Log.scoped("ClipboardThumbnail")

    required property var entry
    required property string entryType
    required property var modal
    required property var listView
    required property int itemIndex
    property bool disposed: false

    Image {
        id: thumbnailImage

        property bool isVisible: false
        property string cachedImageData: ""
        property bool loadQueued: false
        property bool activeLoad: false
        property bool completed: false
        property int loadGeneration: 0
        property var activeEntryId: null
        property var activeRequest: null
        property var currentEntryId: entry && entry.id !== undefined ? entry.id : null
        property string currentEntryType: entryType

        anchors.fill: parent
        source: cachedImageData ? `data:image/png;base64,${cachedImageData}` : ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: false
        visible: false
        asynchronous: true
        sourceSize.width: 128
        sourceSize.height: 128

        onCurrentEntryIdChanged: {
            if (thumbnailImage.completed) {
                thumbnailImage.resetForEntry();
            }
        }

        onCurrentEntryTypeChanged: {
            if (thumbnailImage.completed) {
                thumbnailImage.resetForEntry();
            }
        }

        function hasValidEntryId() {
            return entry && entry.id !== undefined && entry.id !== null;
        }

        function releaseActiveLoad() {
            if (!thumbnailImage.activeLoad) {
                return;
            }
            thumbnailImage.activeLoad = false;
            if (modal && modal.activeImageLoads > 0) {
                modal.activeImageLoads--;
            }
        }

        function finishLoad(request) {
            thumbnailImage.loadQueued = false;
            thumbnailImage.activeEntryId = null;
            if (!request || thumbnailImage.activeRequest === request) {
                thumbnailImage.activeRequest = null;
            }
            thumbnailImage.releaseActiveLoad();
        }

        function cancelLoad() {
            if (thumbnailImage.activeRequest) {
                thumbnailImage.activeRequest.cancelled = true;
                thumbnailImage.activeRequest = null;
            }
            retryTimer.stop();
            visibilityTimer.stop();
            thumbnailImage.loadQueued = false;
            thumbnailImage.activeEntryId = null;
            thumbnailImage.releaseActiveLoad();
        }

        function resetForEntry() {
            thumbnailImage.loadGeneration++;
            thumbnailImage.cachedImageData = "";
            thumbnailImage.isVisible = false;
            thumbnailImage.cancelLoad();
            Qt.callLater(function () {
                if (thumbnail.disposed) {
                    return;
                }
                thumbnailImage.checkVisibility();
            });
        }

        function startLoad() {
            if (!modal) {
                thumbnailImage.loadQueued = false;
                return;
            }
            modal.activeImageLoads++;
            thumbnailImage.activeLoad = true;
            thumbnailImage.loadImage();
        }

        function tryLoadImage() {
            if (thumbnail.disposed || thumbnailImage.loadQueued || entryType !== "image" || thumbnailImage.cachedImageData || !thumbnailImage.hasValidEntryId()) {
                return;
            }
            thumbnailImage.loadQueued = true;
            if (modal && modal.activeImageLoads < modal.maxConcurrentLoads) {
                thumbnailImage.startLoad();
            } else {
                retryTimer.restart();
            }
        }

        function loadImage() {
            if (!thumbnailImage.hasValidEntryId()) {
                thumbnailImage.finishLoad();
                return;
            }
            const requestedId = entry.id;
            const generation = thumbnailImage.loadGeneration;
            const request = {
                "cancelled": false
            };
            thumbnailImage.activeEntryId = requestedId;
            thumbnailImage.activeRequest = request;
            DMSService.sendRequest("clipboard.getEntry", {
                "id": requestedId
            }, function (response) {
                if (request.cancelled) {
                    return;
                }
                if (thumbnail.disposed || generation !== thumbnailImage.loadGeneration || thumbnailImage.activeRequest !== request || thumbnailImage.activeEntryId !== requestedId) {
                    return;
                }
                thumbnailImage.finishLoad(request);
                if (!entry || entry.id !== requestedId || entryType !== "image") {
                    return;
                }
                if (response.error) {
                    log.warn("Failed to load image:", requestedId);
                    return;
                }
                if (!response.result) {
                    ClipboardService.refresh();
                    return;
                }
                const data = response.result?.data;
                if (data) {
                    thumbnailImage.cachedImageData = data;
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
                if (modal && modal.activeImageLoads < modal.maxConcurrentLoads) {
                    thumbnailImage.startLoad();
                } else {
                    retryTimer.restart();
                }
            }
        }

        Component.onCompleted: {
            thumbnailImage.completed = true;
            if (entryType !== "image" || listView.height <= 0 || !thumbnailImage.hasValidEntryId()) {
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

        Component.onDestruction: {
            thumbnail.disposed = true;
            thumbnailImage.cancelLoad();
        }

        Timer {
            id: visibilityTimer
            interval: 100
            onTriggered: thumbnailImage.checkVisibility()
        }

        function checkVisibility() {
            if (thumbnail.disposed || entryType !== "image" || listView.height <= 0 || isVisible || !thumbnailImage.hasValidEntryId()) {
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
