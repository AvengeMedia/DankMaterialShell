import QtQuick
import qs.Common

Text {
    property bool isMonospace: false
    FontLoader {
        id: interFont
        source: Qt.resolvedUrl("../assets/fonts/inter/InterVariable.ttf")
    }

    FontLoader {
        id: firaCodeFont
        source: Qt.resolvedUrl("../assets/fonts/nerd-fonts/FiraCodeNerdFont-Regular.ttf")
    }

    readonly property string resolvedFontFamily: {
        const requestedFont = isMonospace ? Theme.monoFontFamily : Theme.fontFamily;
        const defaultFont = isMonospace ? Theme.defaultMonoFontFamily : Theme.defaultFontFamily;

        if (requestedFont === defaultFont) {
            return isMonospace ? firaCodeFont.name : interFont.name;
        }
        return requestedFont;
    }

    readonly property int resolvedRenderType: {
        switch (SettingsData.textRenderType) {
        case SettingsData.TextRenderType.Qt:
            return Text.QtRendering;
        case SettingsData.TextRenderType.Curve:
            return Text.CurveRendering;
        default:
            return Text.NativeRendering;
        }
    }

    readonly property int resolvedRenderQuality: {
        switch (SettingsData.textRenderQuality) {
        case SettingsData.TextRenderQuality.Low:
            return Text.LowRenderTypeQuality;
        case SettingsData.TextRenderQuality.Normal:
            return Text.NormalRenderTypeQuality;
        case SettingsData.TextRenderQuality.High:
            return Text.HighRenderTypeQuality;
        case SettingsData.TextRenderQuality.VeryHigh:
            return Text.VeryHighRenderTypeQuality;
        default:
            return Text.DefaultRenderTypeQuality;
        }
    }

    readonly property var standardAnimation: {
        "duration": Appearance.anim.durations.normal,
        "easing.type": Easing.BezierSpline,
        "easing.bezierCurve": Appearance.anim.curves.standard
    }

    color: Theme.surfaceText
    font.pixelSize: Appearance.fontSize.normal
    font.family: resolvedFontFamily
    font.weight: Theme.fontWeight
    wrapMode: Text.WordWrap
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: resolvedRenderType
    renderTypeQuality: resolvedRenderQuality

    Behavior on opacity {
        NumberAnimation {
            duration: standardAnimation.duration
            easing.type: standardAnimation["easing.type"]
            easing.bezierCurve: standardAnimation["easing.bezierCurve"]
        }
    }
}
