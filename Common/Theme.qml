import QtQuick
pragma Singleton
pragma ComponentBehavior: Bound

QtObject {
    id: root
    
    // Theme definitions with complete Material 3 expressive color palettes
    property var themes: [
        {
            name: "Blue",
            primary: "#42a5f5",
            primaryText: "#ffffff", 
            primaryContainer: "#1976d2",
            secondary: "#8ab4f8",
            surface: "#1a1c1e",
            surfaceText: "#e3e8ef",
            surfaceVariant: "#44464f",
            surfaceVariantText: "#c4c7c5",
            surfaceTint: "#8ab4f8",
            background: "#1a1c1e",
            backgroundText: "#e3e8ef",
            outline: "#8e918f",
            surfaceContainer: "#1e2023",
            surfaceContainerHigh: "#292b2f"
        },
        {
            name: "Deep Blue",
            primary: "#0061a4",
            primaryText: "#ffffff",
            primaryContainer: "#004881",
            secondary: "#42a5f5",
            surface: "#1a1c1e",
            surfaceText: "#e3e8ef",
            surfaceVariant: "#44464f",
            surfaceVariantText: "#c4c7c5",
            surfaceTint: "#8ab4f8",
            background: "#1a1c1e",
            backgroundText: "#e3e8ef",
            outline: "#8e918f",
            surfaceContainer: "#1e2023",
            surfaceContainerHigh: "#292b2f"
        },
        {
            name: "Purple",
            primary: "#D0BCFF",
            primaryText: "#381E72",
            primaryContainer: "#4F378B",
            secondary: "#CCC2DC",
            surface: "#10121E",
            surfaceText: "#E6E0E9",
            surfaceVariant: "#49454F",
            surfaceVariantText: "#CAC4D0",
            surfaceTint: "#D0BCFF",
            background: "#10121E",
            backgroundText: "#E6E0E9",
            outline: "#938F99",
            surfaceContainer: "#1D1B20",
            surfaceContainerHigh: "#2B2930"
        },
        {
            name: "Green",
            primary: "#4caf50",
            primaryText: "#ffffff",
            primaryContainer: "#388e3c",
            secondary: "#81c995",
            surface: "#0f1411",
            surfaceText: "#e1f5e3",
            surfaceVariant: "#404943",
            surfaceVariantText: "#c1cbc4",
            surfaceTint: "#81c995",
            background: "#0f1411",
            backgroundText: "#e1f5e3",
            outline: "#8b938c",
            surfaceContainer: "#1a1f1b",
            surfaceContainerHigh: "#252a26"
        },
        {
            name: "Orange",
            primary: "#ff6d00",
            primaryText: "#ffffff",
            primaryContainer: "#e65100",
            secondary: "#ffb74d",
            surface: "#1c1410",
            surfaceText: "#f5f1ea",
            surfaceVariant: "#4a453a",
            surfaceVariantText: "#cbc5b8",
            surfaceTint: "#ffb74d",
            background: "#1c1410",
            backgroundText: "#f5f1ea",
            outline: "#958f84",
            surfaceContainer: "#211e17",
            surfaceContainerHigh: "#2c291f"
        },
        {
            name: "Red",
            primary: "#f44336",
            primaryText: "#ffffff",
            primaryContainer: "#d32f2f",
            secondary: "#f28b82",
            surface: "#1c1011",
            surfaceText: "#f5e8ea",
            surfaceVariant: "#4a3f41",
            surfaceVariantText: "#cbc2c4",
            surfaceTint: "#f28b82",
            background: "#1c1011",
            backgroundText: "#f5e8ea",
            outline: "#958b8d",
            surfaceContainer: "#211b1c",
            surfaceContainerHigh: "#2c2426"
        },
        {
            name: "Cyan",
            primary: "#00bcd4",
            primaryText: "#ffffff",
            primaryContainer: "#0097a7",
            secondary: "#4dd0e1",
            surface: "#0f1617",
            surfaceText: "#e8f4f5",
            surfaceVariant: "#3f474a",
            surfaceVariantText: "#c2c9cb",
            surfaceTint: "#4dd0e1",
            background: "#0f1617",
            backgroundText: "#e8f4f5",
            outline: "#8c9194",
            surfaceContainer: "#1a1f20",
            surfaceContainerHigh: "#252b2c"
        },
        {
            name: "Pink",
            primary: "#e91e63",
            primaryText: "#ffffff",
            primaryContainer: "#c2185b",
            secondary: "#f8bbd9",
            surface: "#1a1014",
            surfaceText: "#f3e8ee",
            surfaceVariant: "#483f45",
            surfaceVariantText: "#c9c2c7",
            surfaceTint: "#f8bbd9",
            background: "#1a1014",
            backgroundText: "#f3e8ee",
            outline: "#938a90",
            surfaceContainer: "#1f1b1e",
            surfaceContainerHigh: "#2a2428"
        },
        {
            name: "Amber",
            primary: "#ffc107",
            primaryText: "#000000",
            primaryContainer: "#ff8f00",
            secondary: "#ffd54f",
            surface: "#1a1710",
            surfaceText: "#f3f0e8",
            surfaceVariant: "#49453a",
            surfaceVariantText: "#cac5b8",
            surfaceTint: "#ffd54f",
            background: "#1a1710",
            backgroundText: "#f3f0e8",
            outline: "#949084",
            surfaceContainer: "#1f1e17",
            surfaceContainerHigh: "#2a281f"
        },
        {
            name: "Coral",
            primary: "#ffb4ab",
            primaryText: "#5f1412",
            primaryContainer: "#8c1d18",
            secondary: "#f9dedc",
            surface: "#1a1110",
            surfaceText: "#f1e8e7",
            surfaceVariant: "#4a4142",
            surfaceVariantText: "#cdc2c1",
            surfaceTint: "#ffb4ab",
            background: "#1a1110",
            backgroundText: "#f1e8e7",
            outline: "#968b8a",
            surfaceContainer: "#201a19",
            surfaceContainerHigh: "#2b2221"
        }
    ]
    
    // Current theme index
    property int currentThemeIndex: 0
    
    // Function to switch themes
    function switchTheme(themeIndex) {
        if (themeIndex >= 0 && themeIndex < themes.length) {
            currentThemeIndex = themeIndex
            // Simple persistence - store in a property
            // In a real application, you might use Qt.labs.settings or another persistence mechanism
        }
    }
    
    // Dynamic color properties that change based on current theme
    property color primary: themes[currentThemeIndex].primary
    property color primaryText: themes[currentThemeIndex].primaryText
    property color primaryContainer: themes[currentThemeIndex].primaryContainer
    property color secondary: themes[currentThemeIndex].secondary
    property color surface: themes[currentThemeIndex].surface
    property color surfaceText: themes[currentThemeIndex].surfaceText
    property color surfaceVariant: themes[currentThemeIndex].surfaceVariant
    property color surfaceVariantText: themes[currentThemeIndex].surfaceVariantText
    property color surfaceTint: themes[currentThemeIndex].surfaceTint
    property color background: themes[currentThemeIndex].background
    property color backgroundText: themes[currentThemeIndex].backgroundText
    property color outline: themes[currentThemeIndex].outline
    property color surfaceContainer: themes[currentThemeIndex].surfaceContainer
    property color surfaceContainerHigh: themes[currentThemeIndex].surfaceContainerHigh
    
    // Static colors that don't change with themes
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