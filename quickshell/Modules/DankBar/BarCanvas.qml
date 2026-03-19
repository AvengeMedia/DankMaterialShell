import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Services

Item {
    id: root

    required property var barWindow
    required property var axis
    required property var barConfig

    anchors.fill: parent

    anchors.left: parent.left
    anchors.top: parent.top
    readonly property bool gothEnabled: (barConfig?.gothCornersEnabled ?? false) && !barWindow.hasMaximizedToplevel
    anchors.leftMargin: -(gothEnabled && axis.isVertical && axis.edge === "right" ? barWindow._wingR : 0)
    anchors.rightMargin: -(gothEnabled && axis.isVertical && axis.edge === "left" ? barWindow._wingR : 0)
    anchors.topMargin: -(gothEnabled && !axis.isVertical && axis.edge === "bottom" ? barWindow._wingR : 0)
    anchors.bottomMargin: -(gothEnabled && !axis.isVertical && axis.edge === "top" ? barWindow._wingR : 0)

    readonly property int barPos: barConfig?.position ?? 0
    readonly property bool isTop: barPos === SettingsData.Position.Top
    readonly property bool isBottom: barPos === SettingsData.Position.Bottom
    readonly property bool isLeft: barPos === SettingsData.Position.Left
    readonly property bool isRight: barPos === SettingsData.Position.Right

    property real wing: gothEnabled ? barWindow._wingR : 0

    Behavior on wing {
        enabled: root.width > 0 && root.height > 0
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    property real rt: {
        if (barConfig?.squareCorners ?? false)
            return 0;
        if (barWindow.hasMaximizedToplevel)
            return 0;
        return Theme.cornerRadius;
    }

    Behavior on rt {
        enabled: root.width > 0 && root.height > 0
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property real shadowIntensity: barConfig?.shadowIntensity ?? 0
    readonly property bool shadowEnabled: shadowIntensity > 0
    readonly property int blurMax: 64
    readonly property real shadowBlurPx: shadowIntensity * 0.2
    readonly property real shadowBlur: Math.max(0, Math.min(1, shadowBlurPx / blurMax))
    readonly property real shadowOpacity: (barConfig?.shadowOpacity ?? 60) / 100
    readonly property string shadowColorMode: barConfig?.shadowColorMode ?? "text"
    readonly property color shadowBaseColor: {
        switch (shadowColorMode) {
        case "surface":
            return Theme.surface;
        case "primary":
            return Theme.primary;
        case "secondary":
            return Theme.secondary;
        case "custom":
            return barConfig?.shadowCustomColor ?? "#000000";
        default:
            return Theme.surfaceText;
        }
    }
    readonly property color shadowColor: Theme.withAlpha(shadowBaseColor, shadowOpacity * barWindow._backgroundAlpha)

    readonly property string mainPath: generatePathForPosition(width, height)
    readonly property string borderFullPath: generateBorderFullPath(width, height)
    readonly property string borderEdgePath: generateBorderEdgePath(width, height)
    property bool mainPathCorrectShape: false
    property bool borderFullPathCorrectShape: false
    property bool borderEdgePathCorrectShape: false

    onMainPathChanged: {
        if (width > 0 && height > 0) {
            root: mainPathCorrectShape = true;
        }
    }
    onBorderFullPathChanged: {
        if (width > 0 && height > 0) {
            root: borderFullPathCorrectShape = true;
        }
    }
    onBorderEdgePathChanged: {
        if (width > 0 && height > 0) {
            root: borderEdgePathCorrectShape = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        z: -999
        onClicked: {
            const activePopout = PopoutManager.getActivePopout(barWindow.screen);
            if (activePopout) {
                if (activePopout.dashVisible !== undefined) {
                    activePopout.dashVisible = false;
                } else if (activePopout.notificationHistoryVisible !== undefined) {
                    activePopout.notificationHistoryVisible = false;
                } else {
                    activePopout.close();
                }
            }
            TrayMenuManager.closeAllMenus();
        }
    }

    Loader {
        id: shadowLoader
        anchors.fill: parent
        active: root.shadowEnabled && mainPathCorrectShape
        asynchronous: false
        sourceComponent: Item {
            anchors.fill: parent

            layer.enabled: true
            layer.smooth: true
            layer.samples: 8
            layer.textureSize: Qt.size(Math.round(width * barWindow._dpr * 2), Math.round(height * barWindow._dpr * 2))
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: root.shadowBlur
                shadowColor: root.shadowColor
                shadowVerticalOffset: root.isTop ? root.shadowBlurPx * 0.5 : (root.isBottom ? -root.shadowBlurPx * 0.5 : 0)
                shadowHorizontalOffset: root.isLeft ? root.shadowBlurPx * 0.5 : (root.isRight ? -root.shadowBlurPx * 0.5 : 0)
                autoPaddingEnabled: true
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: barWindow._bgColor
                    strokeColor: "transparent"
                    strokeWidth: 0

                    PathSvg {
                        path: root.mainPath
                    }
                }
            }
        }
    }

    Loader {
        id: barShape
        anchors.fill: parent
        active: mainPathCorrectShape
        sourceComponent: Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: barWindow._bgColor
                strokeColor: "transparent"
                strokeWidth: 0

                PathSvg {
                    path: root.mainPath
                }
            }
        }
    }

    Loader {
        id: barBorder
        anchors.fill: parent
        active: borderFullPathCorrectShape && borderEdgePathCorrectShape

        readonly property real _scale: CompositorService.getScreenScale(barWindow.screen)
        readonly property real borderThickness: Math.ceil(Math.max(1, barConfig?.borderThickness ?? 1) * _scale) / _scale
        readonly property real inset: borderThickness / 2
        readonly property string borderColorKey: barConfig?.borderColor || "surfaceText"
        readonly property color baseColor: (borderColorKey === "surfaceText") ? Theme.surfaceText : (borderColorKey === "primary") ? Theme.primary : Theme.secondary
        readonly property color borderColor: Theme.withAlpha(baseColor, barConfig?.borderOpacity ?? 1.0)
        readonly property bool showFullBorder: (barConfig?.spacing ?? 4) > 0
        sourceComponent: Shape {
            id: barBorderShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: barConfig?.borderEnabled ?? false

            ShapePath {
                fillColor: "transparent"
                strokeColor: barBorder.borderColor
                strokeWidth: barBorder.borderThickness
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.FlatCap

                PathSvg {
                    path: barBorder.showFullBorder ? root.borderFullPath : root.borderEdgePath
                }
            }
        }
    }

    function generatePathForPosition(w, h) {
        if (isTop)
            return generateTopPath(w, h);
        if (isBottom)
            return generateBottomPath(w, h);
        if (isLeft)
            return generateLeftPath(w, h);
        if (isRight)
            return generateRightPath(w, h);
        return generateTopPath(w, h);
    }

    function generateBorderPathForPosition() {
        if (isTop)
            return generateTopBorderPath();
        if (isBottom)
            return generateBottomBorderPath();
        if (isLeft)
            return generateLeftBorderPath();
        if (isRight)
            return generateRightBorderPath();
        return generateTopBorderPath();
    }

    function generateTopPath(w, h) {
        h = h - wing;
        const r = wing;
        const cr = rt;

        let d = `M ${cr} 0`;
        d += ` L ${w - cr} 0`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 1 ${w} ${cr}`;
        if (r > 0) {
            d += ` L ${w} ${h + r}`;
            d += ` A ${r} ${r} 0 0 0 ${w - r} ${h}`;
            d += ` L ${r} ${h}`;
            d += ` A ${r} ${r} 0 0 0 0 ${h + r}`;
        } else {
            d += ` L ${w} ${h - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${w - cr} ${h}`;
            d += ` L ${cr} ${h}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 0 ${h - cr}`;
        }
        d += ` L 0 ${cr}`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 1 ${cr} 0`;
        d += " Z";
        return d;
    }

    function generateBottomPath(w, h) {
        const fullH = h;
        h = h - wing;
        const r = wing;
        const cr = rt;

        let d = `M ${cr} ${fullH}`;
        d += ` L ${w - cr} ${fullH}`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 0 ${w} ${fullH - cr}`;
        if (r > 0) {
            d += ` L ${w} 0`;
            d += ` A ${r} ${r} 0 0 1 ${w - r} ${r}`;
            d += ` L ${r} ${r}`;
            d += ` A ${r} ${r} 0 0 1 0 0`;
        } else {
            d += ` L ${w} ${cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${w - cr} 0`;
            d += ` L ${cr} 0`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 0 ${cr}`;
        }
        d += ` L 0 ${fullH - cr}`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 0 ${cr} ${fullH}`;
        d += " Z";
        return d;
    }

    function generateLeftPath(w, h) {
        w = w - wing;
        const r = wing;
        const cr = rt;

        let d = `M 0 ${cr}`;
        d += ` L 0 ${h - cr}`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 0 ${cr} ${h}`;
        if (r > 0) {
            d += ` L ${w + r} ${h}`;
            d += ` A ${r} ${r} 0 0 1 ${w} ${h - r}`;
            d += ` L ${w} ${r}`;
            d += ` A ${r} ${r} 0 0 1 ${w + r} 0`;
        } else {
            d += ` L ${w - cr} ${h}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${w} ${h - cr}`;
            d += ` L ${w} ${cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${w - cr} 0`;
        }
        d += ` L ${cr} 0`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 0 0 ${cr}`;
        d += " Z";
        return d;
    }

    function generateRightPath(w, h) {
        const fullW = w;
        w = w - wing;
        const r = wing;
        const cr = rt;

        let d = `M ${fullW} ${cr}`;
        d += ` L ${fullW} ${h - cr}`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 1 ${fullW - cr} ${h}`;
        if (r > 0) {
            d += ` L 0 ${h}`;
            d += ` A ${r} ${r} 0 0 0 ${r} ${h - r}`;
            d += ` L ${r} ${r}`;
            d += ` A ${r} ${r} 0 0 0 0 0`;
        } else {
            d += ` L ${cr} ${h}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 0 ${h - cr}`;
            d += ` L 0 ${cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${cr} 0`;
        }
        d += ` L ${fullW - cr} 0`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 1 ${fullW} ${cr}`;
        d += " Z";
        return d;
    }

    function generateTopBorderPath() {
        const w = barBorder.width;
        const h = barBorder.height - wing;
        const r = wing;
        const cr = rt;

        let d = "";
        if (r > 0) {
            d = `M ${w} ${h + r}`;
            d += ` A ${r} ${r} 0 0 0 ${w - r} ${h}`;
            d += ` L ${r} ${h}`;
            d += ` A ${r} ${r} 0 0 0 0 ${h + r}`;
        } else {
            d = `M ${w} ${h - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${w - cr} ${h}`;
            d += ` L ${cr} ${h}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 0 ${h - cr}`;
        }
        return d;
    }

    function generateBottomBorderPath() {
        const w = barBorder.width;
        const r = wing;
        const cr = rt;

        let d = "";
        if (r > 0) {
            d = `M ${w} 0`;
            d += ` A ${r} ${r} 0 0 1 ${w - r} ${r}`;
            d += ` L ${r} ${r}`;
            d += ` A ${r} ${r} 0 0 1 0 0`;
        } else {
            d = `M ${w} ${cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${w - cr} 0`;
            d += ` L ${cr} 0`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 0 ${cr}`;
        }
        return d;
    }

    function generateLeftBorderPath() {
        const w = barBorder.width - wing;
        const h = barBorder.height;
        const r = wing;
        const cr = rt;

        let d = "";
        if (r > 0) {
            d = `M ${w + r} ${h}`;
            d += ` A ${r} ${r} 0 0 1 ${w} ${h - r}`;
            d += ` L ${w} ${r}`;
            d += ` A ${r} ${r} 0 0 1 ${w + r} 0`;
        } else {
            d = `M ${w - cr} ${h}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${w} ${h - cr}`;
            d += ` L ${w} ${cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${w - cr} 0`;
        }
        return d;
    }

    function generateRightBorderPath() {
        const h = barBorder.height;
        const r = wing;
        const cr = rt;

        let d = "";
        if (r > 0) {
            d = `M 0 ${h}`;
            d += ` A ${r} ${r} 0 0 0 ${r} ${h - r}`;
            d += ` L ${r} ${r}`;
            d += ` A ${r} ${r} 0 0 0 0 0`;
        } else {
            d = `M ${cr} ${h}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 0 ${h - cr}`;
            d += ` L 0 ${cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${cr} 0`;
        }
        return d;
    }

    function generateBorderFullPath(fullW, fullH) {
        const i = barBorder.inset;
        const r = wing;
        const cr = rt;

        if (isTop) {
            const w = fullW - i * 2;
            const h = fullH - wing - i * 2;

            let d = `M ${i + cr} ${i}`;
            d += ` L ${i + w - cr} ${i}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${i + w} ${i + cr}`;
            if (r > 0) {
                d += ` L ${i + w} ${fullH - i}`;
                d += ` A ${r} ${r} 0 0 0 ${i + w - r} ${i + h}`;
                d += ` L ${i + r} ${i + h}`;
                d += ` A ${r} ${r} 0 0 0 ${i} ${fullH - i}`;
            } else {
                d += ` L ${i + w} ${i + h - cr}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 1 ${i + w - cr} ${i + h}`;
                d += ` L ${i + cr} ${i + h}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 1 ${i} ${i + h - cr}`;
            }
            d += ` L ${i} ${i + cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${i + cr} ${i}`;
            d += " Z";
            return d;
        }

        if (isBottom) {
            const w = fullW - i * 2;
            const h = fullH - wing - i * 2;

            let d = `M ${i + cr} ${fullH - i}`;
            d += ` L ${i + w - cr} ${fullH - i}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${i + w} ${fullH - i - cr}`;
            if (r > 0) {
                d += ` L ${i + w} ${i}`;
                d += ` A ${r} ${r} 0 0 1 ${i + w - r} ${i + r}`;
                d += ` L ${i + r} ${i + r}`;
                d += ` A ${r} ${r} 0 0 1 ${i} ${i}`;
            } else {
                d += ` L ${i + w} ${i + cr}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 0 ${i + w - cr} ${i}`;
                d += ` L ${i + cr} ${i}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 0 ${i} ${i + cr}`;
            }
            d += ` L ${i} ${fullH - i - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${i + cr} ${fullH - i}`;
            d += " Z";
            return d;
        }

        if (isLeft) {
            const w = fullW - wing - i * 2;
            const h = fullH - i * 2;

            let d = `M ${i} ${i + cr}`;
            d += ` L ${i} ${i + h - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${i + cr} ${i + h}`;
            if (r > 0) {
                d += ` L ${fullW - i} ${i + h}`;
                d += ` A ${r} ${r} 0 0 1 ${i + w} ${i + h - r}`;
                d += ` L ${i + w} ${i + r}`;
                d += ` A ${r} ${r} 0 0 1 ${fullW - i} ${i}`;
            } else {
                d += ` L ${i + w - cr} ${i + h}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 0 ${i + w} ${i + h - cr}`;
                d += ` L ${i + w} ${i + cr}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 0 ${i + w - cr} ${i}`;
            }
            d += ` L ${i + cr} ${i}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${i} ${i + cr}`;
            d += " Z";
            return d;
        }

        if (isRight) {
            const w = fullW - wing - i * 2;
            const h = fullH - i * 2;

            let d = `M ${fullW - i} ${i + cr}`;
            d += ` L ${fullW - i} ${i + h - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${fullW - i - cr} ${i + h}`;
            if (r > 0) {
                d += ` L ${i} ${i + h}`;
                d += ` A ${r} ${r} 0 0 0 ${i + r} ${i + h - r}`;
                d += ` L ${i + r} ${i + r}`;
                d += ` A ${r} ${r} 0 0 0 ${i} ${i}`;
            } else {
                d += ` L ${wing + i + cr} ${i + h}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 1 ${wing + i} ${i + h - cr}`;
                d += ` L ${wing + i} ${i + cr}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 1 ${wing + i + cr} ${i}`;
            }
            d += ` L ${fullW - i - cr} ${i}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${fullW - i} ${i + cr}`;
            d += " Z";
            return d;
        }

        return "";
    }

    function generateBorderEdgePath(fullW, fullH) {
        const i = barBorder.inset;
        const r = wing;
        const cr = rt;

        if (isTop) {
            const w = fullW - i * 2;
            const h = fullH - wing - i * 2;

            let d = "";
            if (r > 0) {
                d = `M ${i + w} ${i + h + r}`;
                d += ` A ${r} ${r} 0 0 0 ${i + w - r} ${i + h}`;
                d += ` L ${i + r} ${i + h}`;
                d += ` A ${r} ${r} 0 0 0 ${i} ${i + h + r}`;
            } else {
                d = `M ${i + w} ${i + h - cr}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 1 ${i + w - cr} ${i + h}`;
                d += ` L ${i + cr} ${i + h}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 1 ${i} ${i + h - cr}`;
            }
            return d;
        }

        if (isBottom) {
            const w = fullW - i * 2;

            let d = "";
            if (r > 0) {
                d = `M ${i + w} ${i}`;
                d += ` A ${r} ${r} 0 0 1 ${i + w - r} ${i + r}`;
                d += ` L ${i + r} ${i + r}`;
                d += ` A ${r} ${r} 0 0 1 ${i} ${i}`;
            } else {
                d = `M ${i + w} ${i + cr}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 0 ${i + w - cr} ${i}`;
                d += ` L ${i + cr} ${i}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 0 ${i} ${i + cr}`;
            }
            return d;
        }

        if (isLeft) {
            const w = fullW - wing - i * 2;
            const h = fullH - i * 2;

            let d = "";
            if (r > 0) {
                d = `M ${i + w + r} ${i + h}`;
                d += ` A ${r} ${r} 0 0 1 ${i + w} ${i + h - r}`;
                d += ` L ${i + w} ${i + r}`;
                d += ` A ${r} ${r} 0 0 1 ${i + w + r} ${i}`;
            } else {
                d = `M ${i + w - cr} ${i + h}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 0 ${i + w} ${i + h - cr}`;
                d += ` L ${i + w} ${i + cr}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 0 ${i + w - cr} ${i}`;
            }
            return d;
        }

        if (isRight) {
            const h = fullH - i * 2;

            let d = "";
            if (r > 0) {
                d = `M ${i} ${i + h}`;
                d += ` A ${r} ${r} 0 0 0 ${i + r} ${i + h - r}`;
                d += ` L ${i + r} ${i + r}`;
                d += ` A ${r} ${r} 0 0 0 ${i} ${i}`;
            } else {
                d = `M ${i + cr} ${i + h}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 1 ${i} ${i + h - cr}`;
                d += ` L ${i} ${i + cr}`;
                if (cr > 0)
                    d += ` A ${cr} ${cr} 0 0 1 ${i + cr} ${i}`;
            }
            return d;
        }

        return "";
    }
}
