import QtQuick
pragma Singleton
pragma ComponentBehavior: Bound

QtObject {
    id: root
    
    property color primary: "#D0BCFF"
    property color primaryText: "#381E72"
    property color primaryContainer: "#4F378B"
    property color secondary: "#CCC2DC"
    property color surface: "#10121E"
    property color surfaceText: "#E6E0E9"
    property color surfaceVariant: "#49454F"
    property color surfaceVariantText: "#CAC4D0"
    property color surfaceTint: "#D0BCFF"
    property color background: "#10121E"
    property color backgroundText: "#E6E0E9"
    property color outline: "#938F99"
    property color surfaceContainer: "#1D1B20"
    property color surfaceContainerHigh: "#2B2930"
    property color archBlue: "#1793D1"
    property color success: "#4CAF50"
    property color warning: "#FF9800"
    property color info: "#2196F3"
    property color error: "#F2B8B5"
    
    property int shortDuration: 150
    property int mediumDuration: 300
    property int longDuration: 500
    property int extraLongDuration: 1000
    
    property int standardEasing: Easing.OutCubic
    property int emphasizedEasing: Easing.OutQuart
    
    property real cornerRadius: 12
    property real cornerRadiusSmall: 8
    property real cornerRadiusLarge: 16
    property real cornerRadiusXLarge: 24
    
    property real spacingXS: 4
    property real spacingS: 8
    property real spacingM: 12
    property real spacingL: 16
    property real spacingXL: 24
    
    property real fontSizeSmall: 12
    property real fontSizeMedium: 14
    property real fontSizeLarge: 16
    property real fontSizeXLarge: 20
    
    property real barHeight: 48
    property real iconSize: 24
    property real iconSizeSmall: 16
    property real iconSizeLarge: 32
    
    property real opacityDisabled: 0.38
    property real opacityMedium: 0.60
    property real opacityHigh: 0.87
    property real opacityFull: 1.0
    
    property string iconFont: "Material Symbols Rounded"
    property string iconFontFilled: "Material Symbols Rounded"
    property int iconFontWeight: Font.Normal
    property int iconFontFilledWeight: Font.Medium
}