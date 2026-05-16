pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var entry: null
    property string cachedImageData: ""
    property var _requestedEntryId: null

    readonly property bool canLoadImage: !!entry?.isImage && (entry?.mimeType ?? "").startsWith("image/")
    readonly property string sourceUrl: cachedImageData.length > 0 ? "data:" + (entry?.mimeType ?? "image/png") + ";base64," + cachedImageData : ""

    radius: Math.max(6, Theme.cornerRadius - 2)
    clip: true
    color: Theme.surfaceContainerHigh
    border.color: Theme.withAlpha(Theme.outline, 0.16)
    border.width: 1

    onEntryChanged: reloadPreview()
    Component.onCompleted: reloadPreview()

    function reloadPreview() {
        cachedImageData = "";
        if (!canLoadImage || !entry?.id) {
            _requestedEntryId = null;
            return;
        }

        const entryId = entry.id;
        _requestedEntryId = entryId;
        DMSService.sendRequest("clipboard.getEntry", {
            "id": entryId
        }, function (response) {
            if (_requestedEntryId !== entryId)
                return;
            if (response.error)
                return;
            const data = response.result?.data ?? "";
            if (data.length > 0)
                cachedImageData = data;
        });
    }

    Image {
        id: previewImage
        anchors.fill: parent
        source: root.sourceUrl
        asynchronous: true
        cache: false
        smooth: true
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }

    DankIcon {
        anchors.centerIn: parent
        name: "image"
        size: Math.min(22, Math.max(16, root.height * 0.46))
        color: Theme.primary
        visible: previewImage.status !== Image.Ready
    }
}
