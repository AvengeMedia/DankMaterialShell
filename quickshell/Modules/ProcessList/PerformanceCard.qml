import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Rectangle {
    id: card

    property string title: ""
    property string icon: ""
    property string value: ""
    property string subtitle: ""
    property color accentColor: Theme.primary
    property var history: []
    property var history2: null
    property real maxValue: 100
    property bool showSecondary: false
    property string extraInfo: ""
    property color extraInfoColor: Theme.surfaceVariantText
    property int historySize: 60

    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Theme.outlineLight
    border.width: 1

    Canvas {
        id: graphCanvas
        anchors.fill: parent
        anchors.margins: 4
        renderStrategy: Canvas.Cooperative

        property var hist: card.history
        property var hist2: card.history2

        onHistChanged: requestPaint()
        onHist2Changed: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            if (!hist || hist.length < 2)
                return;

            let max = card.maxValue;
            if (max <= 0) {
                max = 1;
                for (let k = 0; k < hist.length; k++)
                    max = Math.max(max, hist[k]);
                if (hist2) {
                    for (let l = 0; l < hist2.length; l++)
                        max = Math.max(max, hist2[l]);
                }
                max *= 1.1;
            }

            const c = card.accentColor;
            const grad = ctx.createLinearGradient(0, 0, 0, height);
            grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.25));
            grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.02));

            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.moveTo(0, height);
            for (let i = 0; i < hist.length; i++) {
                const x = (width / (card.historySize - 1)) * i;
                const y = height - (hist[i] / max) * height * 0.8;
                ctx.lineTo(x, y);
            }
            ctx.lineTo((width / (card.historySize - 1)) * (hist.length - 1), height);
            ctx.closePath();
            ctx.fill();

            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.8);
            ctx.lineWidth = 2;
            ctx.beginPath();
            for (let j = 0; j < hist.length; j++) {
                const px = (width / (card.historySize - 1)) * j;
                const py = height - (hist[j] / max) * height * 0.8;
                j === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
            }
            ctx.stroke();

            if (hist2 && hist2.length >= 2 && card.showSecondary) {
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.4);
                ctx.lineWidth = 1.5;
                ctx.setLineDash([4, 4]);
                ctx.beginPath();
                for (let m = 0; m < hist2.length; m++) {
                    const sx = (width / (card.historySize - 1)) * m;
                    const sy = height - (hist2[m] / max) * height * 0.8;
                    m === 0 ? ctx.moveTo(sx, sy) : ctx.lineTo(sx, sy);
                }
                ctx.stroke();
                ctx.setLineDash([]);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankIcon {
                name: card.icon
                size: Theme.iconSize
                color: card.accentColor
            }

            StyledText {
                text: card.title
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: card.extraInfo
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                color: card.extraInfoColor
                visible: card.extraInfo.length > 0
            }
        }

        Item {
            Layout.fillHeight: true
        }

        StyledText {
            text: card.value
            font.pixelSize: Theme.fontSizeXLarge
            font.family: SettingsData.monoFontFamily
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: card.subtitle
            font.pixelSize: Theme.fontSizeSmall
            font.family: SettingsData.monoFontFamily
            color: Theme.surfaceVariantText
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
