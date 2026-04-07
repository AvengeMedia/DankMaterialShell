import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: gaugeRoot

    property real value: 0
    property string label: ""
    property string sublabel: ""
    property string detail: ""
    property color accentColor: Theme.primary
    property color detailColor: Theme.surfaceVariantText

    readonly property real thickness: Math.max(4, Math.min(width, height) / 15)
    readonly property real glowExtra: thickness * 1.4
    readonly property real arcPadding: (thickness + glowExtra) / 2

    readonly property real innerDiameter: width - (arcPadding + thickness + glowExtra) * 2
    readonly property real maxTextWidth: innerDiameter * 0.9
    readonly property real baseLabelSize: Math.round(width * 0.18)
    readonly property real labelSize: Math.round(Math.min(baseLabelSize, maxTextWidth / Math.max(1, label.length * 0.65)))
    readonly property real sublabelSize: Math.round(Math.min(width * 0.13, maxTextWidth / Math.max(1, sublabel.length * 0.7)))
    readonly property real detailSize: Math.round(Math.min(width * 0.12, maxTextWidth / Math.max(1, detail.length * 0.65)))

    property real animValue: 0

    onValueChanged: animValue = Math.min(1, Math.max(0, value))

    Behavior on animValue {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: animValue = Math.min(1, Math.max(0, value))

    Canvas {
        id: glowCanvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const radius = (Math.min(width, height) / 2) - gaugeRoot.arcPadding;
            const startAngle = -Math.PI * 0.5;
            const endAngle = Math.PI * 1.5;

            ctx.lineCap = "round";

            if (gaugeRoot.animValue > 0) {
                const prog = startAngle + (endAngle - startAngle) * gaugeRoot.animValue;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, startAngle, prog);
                ctx.strokeStyle = Qt.rgba(gaugeRoot.accentColor.r, gaugeRoot.accentColor.g, gaugeRoot.accentColor.b, 0.2);
                ctx.lineWidth = gaugeRoot.thickness + gaugeRoot.glowExtra;
                ctx.stroke();
            }
        }

        Connections {
            target: gaugeRoot
            function onAnimValueChanged() {
                glowCanvas.requestPaint();
            }
            function onAccentColorChanged() {
                glowCanvas.requestPaint();
            }
            function onWidthChanged() {
                glowCanvas.requestPaint();
            }
            function onHeightChanged() {
                glowCanvas.requestPaint();
            }
        }

        Component.onCompleted: requestPaint()
    }

    Canvas {
        id: arcCanvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const radius = (Math.min(width, height) / 2) - gaugeRoot.arcPadding;
            const startAngle = -Math.PI * 0.5;
            const endAngle = Math.PI * 1.5;

            ctx.lineCap = "round";

            ctx.beginPath();
            ctx.arc(cx, cy, radius, startAngle, endAngle);
            ctx.strokeStyle = Qt.rgba(gaugeRoot.accentColor.r, gaugeRoot.accentColor.g, gaugeRoot.accentColor.b, 0.1);
            ctx.lineWidth = gaugeRoot.thickness;
            ctx.stroke();

            if (gaugeRoot.animValue > 0) {
                const prog = startAngle + (endAngle - startAngle) * gaugeRoot.animValue;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, startAngle, prog);
                ctx.strokeStyle = gaugeRoot.accentColor;
                ctx.lineWidth = gaugeRoot.thickness;
                ctx.stroke();
            }
        }

        Connections {
            target: gaugeRoot
            function onAnimValueChanged() {
                arcCanvas.requestPaint();
            }
            function onAccentColorChanged() {
                arcCanvas.requestPaint();
            }
            function onWidthChanged() {
                arcCanvas.requestPaint();
            }
            function onHeightChanged() {
                arcCanvas.requestPaint();
            }
        }

        Component.onCompleted: requestPaint()
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        StyledText {
            text: gaugeRoot.label
            font.pixelSize: gaugeRoot.labelSize
            font.family: SettingsData.monoFontFamily
            font.weight: Font.Bold
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: gaugeRoot.sublabel
            font.pixelSize: gaugeRoot.sublabelSize
            font.weight: Font.Medium
            color: gaugeRoot.accentColor
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: gaugeRoot.detail
            font.pixelSize: gaugeRoot.detailSize
            font.family: SettingsData.monoFontFamily
            color: gaugeRoot.detailColor
            anchors.horizontalCenter: parent.horizontalCenter
            visible: gaugeRoot.detail.length > 0
        }
    }
}
