pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var entry: null
    property string cachedImageData: ""
    property string cachedMimeType: ""
    property var _requestedEntryId: null

    readonly property bool canLoadImage: !!entry?.isImage && (entry?.mimeType ?? "").startsWith("image/")
    readonly property string sourceUrl: resolvedSourceUrl(cachedImageData, cachedMimeType || (entry?.mimeType ?? ""))

    radius: Math.max(6, Theme.cornerRadius - 2)
    clip: true
    color: Theme.surfaceContainerHigh
    border.color: Theme.withAlpha(Theme.outline, 0.16)
    border.width: 1

    onEntryChanged: reloadPreview()
    Component.onCompleted: reloadPreview()

    function isImageMimeType(mimeType) {
        return (mimeType || "").toString().toLowerCase().startsWith("image/");
    }

    function resolvedSourceUrl(data, mimeType) {
        const rawData = (data || "").toString();
        if (rawData.length === 0)
            return "";
        if (rawData.startsWith("data:"))
            return rawData.startsWith("data:image/") ? rawData : "";
        if (!isImageMimeType(mimeType))
            return "";
        return "data:" + mimeType + ";base64," + rawData;
    }

    function reloadPreview() {
        cachedImageData = "";
        cachedMimeType = "";
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
            if (!response.result) {
                ClipboardService.refresh();
                return;
            }
            const result = response.result;
            const mimeType = (result.mimeType ?? entry?.mimeType ?? "").toString();
            const data = (result.data ?? "").toString();
            if (data.length === 0 || !resolvedSourceUrl(data, mimeType))
                return;
            cachedMimeType = mimeType;
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
