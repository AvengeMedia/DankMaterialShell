import QtQuick
import qs.Common

Item {
    id: root

    property color swatchColor: "transparent"
    property color ringColor: Theme.outline
    property real minPreviewAlpha: 0.4
    readonly property bool translucent: swatchColor.a > 0 && swatchColor.a < 1
    readonly property color displayColor: translucent ? Qt.rgba(swatchColor.r, swatchColor.g, swatchColor.b, Math.max(swatchColor.a, minPreviewAlpha)) : swatchColor

    Loader {
        anchors.fill: parent
        active: root.translucent
        sourceComponent: Component {
            Canvas {
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
                    ctx.clip();
                    const s = Math.max(2, Math.round(width / 4));
                    for (let y = 0; y < height; y += s) {
                        for (let x = 0; x < width; x += s) {
                            ctx.fillStyle = (((x / s) + (y / s)) % 2 === 0) ? "#ffffff" : "#bdbdbd";
                            ctx.fillRect(x, y, s, s);
                        }
                    }
                }
                onVisibleChanged: if (visible)
                    requestPaint()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.displayColor
        border.color: root.ringColor
        border.width: 1
    }
}
