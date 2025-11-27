import QtQuick
import QtQuick.Shapes
import qs.Common

Item {
    id: root

    required property var barWindow
    required property var axis
    required property var barConfig

    anchors.fill: parent

    anchors.left: parent.left
    anchors.top: parent.top
    readonly property bool gothEnabled: barConfig?.gothCornersEnabled ?? false
    anchors.leftMargin: -(gothEnabled && axis.isVertical && axis.edge === "right" ? barWindow._wingR : 0)
    anchors.rightMargin: -(gothEnabled && axis.isVertical && axis.edge === "left" ? barWindow._wingR : 0)
    anchors.topMargin: -(gothEnabled && !axis.isVertical && axis.edge === "bottom" ? barWindow._wingR : 0)
    anchors.bottomMargin: -(gothEnabled && !axis.isVertical && axis.edge === "top" ? barWindow._wingR : 0)

    readonly property int barPos: barConfig?.position ?? 0
    readonly property bool isTop: barPos === SettingsData.Position.Top
    readonly property bool isBottom: barPos === SettingsData.Position.Bottom
    readonly property bool isLeft: barPos === SettingsData.Position.Left
    readonly property bool isRight: barPos === SettingsData.Position.Right

    readonly property real wing: gothEnabled ? barWindow._wingR : 0
    readonly property real rt: (barConfig?.squareCorners ?? false) ? 0 : Theme.cornerRadius

    property string _cachedMainPath: ""
    property string _cachedBorderFullPath: ""
    property string _cachedBorderEdgePath: ""
    property string _pathKey: ""

    readonly property string currentPathKey: `${width}|${height}|${barPos}|${wing}|${rt}|${barBorder.inset}`

    onCurrentPathKeyChanged: {
        if (_pathKey !== currentPathKey) {
            _pathKey = currentPathKey;
            _cachedMainPath = generatePathForPosition();
            _cachedBorderFullPath = generateBorderFullPath();
            _cachedBorderEdgePath = generateBorderEdgePath();
        }
    }

    Component.onCompleted: {
        _pathKey = currentPathKey;
        _cachedMainPath = generatePathForPosition();
        _cachedBorderFullPath = generateBorderFullPath();
        _cachedBorderEdgePath = generateBorderEdgePath();
    }

    readonly property string mainPath: _cachedMainPath
    readonly property string borderFullPath: _cachedBorderFullPath
    readonly property string borderEdgePath: _cachedBorderEdgePath

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

    Shape {
        id: barShape
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

    Shape {
        id: barTint
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        readonly property real alphaTint: (barWindow._bgColor?.a ?? 1) < 0.99 ? (Theme.stateLayerOpacity ?? 0) : 0

        ShapePath {
            fillColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, barTint.alphaTint)
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
                path: root.mainPath
            }
        }
    }

    Shape {
        id: barBorder
        anchors.fill: parent
        visible: barConfig?.borderEnabled ?? false
        preferredRendererType: Shape.CurveRenderer

        readonly property real borderThickness: Math.max(1, barConfig?.borderThickness ?? 1)
        readonly property real inset: showFullBorder ? Math.ceil(borderThickness / 2) : borderThickness / 2
        readonly property string borderColorKey: barConfig?.borderColor || "surfaceText"
        readonly property color baseColor: (borderColorKey === "surfaceText") ? Theme.surfaceText : (borderColorKey === "primary") ? Theme.primary : Theme.secondary
        readonly property color borderColor: Theme.withAlpha(baseColor, barConfig?.borderOpacity ?? 1.0)
        readonly property bool showFullBorder: (barConfig?.spacing ?? 4) > 0

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

    function generatePathForPosition() {
        if (isTop)
            return generateTopPath();
        if (isBottom)
            return generateBottomPath();
        if (isLeft)
            return generateLeftPath();
        if (isRight)
            return generateRightPath();
        return generateTopPath();
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

    function generateTopPath() {
        const w = width;
        const h = height - wing;
        const r = wing;
        const cr = rt;

        if (w <= 0 || h <= 0)
            return "";

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

    function generateBottomPath() {
        const w = width;
        const h = height - wing;
        const r = wing;
        const cr = rt;

        if (w <= 0 || h <= 0)
            return "";

        let d = `M ${cr} ${height}`;
        d += ` L ${w - cr} ${height}`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 0 ${w} ${height - cr}`;
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
        d += ` L 0 ${height - cr}`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 0 ${cr} ${height}`;
        d += " Z";
        return d;
    }

    function generateLeftPath() {
        const w = width - wing;
        const h = height;
        const r = wing;
        const cr = rt;

        if (w <= 0 || h <= 0)
            return "";

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

    function generateRightPath() {
        const w = width - wing;
        const h = height;
        const r = wing;
        const cr = rt;

        if (w <= 0 || h <= 0)
            return "";

        let d = `M ${width} ${cr}`;
        d += ` L ${width} ${h - cr}`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 1 ${width - cr} ${h}`;
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
        d += ` L ${width - cr} 0`;
        if (cr > 0)
            d += ` A ${cr} ${cr} 0 0 1 ${width} ${cr}`;
        d += " Z";
        return d;
    }

    function generateTopBorderPath() {
        const w = barBorder.width;
        const h = barBorder.height - wing;
        const r = wing;
        const cr = rt;

        if (w <= 0 || h <= 0)
            return "";

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

        if (w <= 0)
            return "";

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

        if (h <= 0)
            return "";

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

        if (h <= 0)
            return "";

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

    function generateBorderFullPath() {
        const i = barBorder.inset;
        const r = wing;
        const cr = rt;

        if (isTop) {
            const w = width - i * 2;
            const h = height - wing - i * 2;
            if (w <= 0 || h <= 0)
                return "";

            let d = `M ${i + cr} ${i}`;
            d += ` L ${i + w - cr} ${i}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${i + w} ${i + cr}`;
            if (r > 0) {
                d += ` L ${i + w} ${height - i}`;
                d += ` A ${r} ${r} 0 0 0 ${i + w - r} ${i + h}`;
                d += ` L ${i + r} ${i + h}`;
                d += ` A ${r} ${r} 0 0 0 ${i} ${height - i}`;
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
            const w = width - i * 2;
            const h = height - wing - i * 2;
            if (w <= 0 || h <= 0)
                return "";

            let d = `M ${i + cr} ${height - i}`;
            d += ` L ${i + w - cr} ${height - i}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${i + w} ${height - i - cr}`;
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
            d += ` L ${i} ${height - i - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${i + cr} ${height - i}`;
            d += " Z";
            return d;
        }

        if (isLeft) {
            const w = width - wing - i * 2;
            const h = height - i * 2;
            if (w <= 0 || h <= 0)
                return "";

            let d = `M ${i} ${i + cr}`;
            d += ` L ${i} ${i + h - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 0 ${i + cr} ${i + h}`;
            if (r > 0) {
                d += ` L ${width - i} ${i + h}`;
                d += ` A ${r} ${r} 0 0 1 ${i + w} ${i + h - r}`;
                d += ` L ${i + w} ${i + r}`;
                d += ` A ${r} ${r} 0 0 1 ${width - i} ${i}`;
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
            const w = width - wing - i * 2;
            const h = height - i * 2;
            if (w <= 0 || h <= 0)
                return "";

            let d = `M ${width - i} ${i + cr}`;
            d += ` L ${width - i} ${i + h - cr}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${width - i - cr} ${i + h}`;
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
            d += ` L ${width - i - cr} ${i}`;
            if (cr > 0)
                d += ` A ${cr} ${cr} 0 0 1 ${width - i} ${i + cr}`;
            d += " Z";
            return d;
        }

        return "";
    }

    function generateBorderEdgePath() {
        const i = barBorder.inset;
        const r = wing;
        const cr = rt;

        if (isTop) {
            const w = width - i * 2;
            const h = height - wing - i * 2;
            if (w <= 0 || h <= 0)
                return "";

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
            const w = width - i * 2;
            if (w <= 0)
                return "";

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
            const w = width - wing - i * 2;
            const h = height - i * 2;
            if (h <= 0)
                return "";

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
            const h = height - i * 2;
            if (h <= 0)
                return "";

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
