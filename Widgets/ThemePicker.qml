import QtQuick
import "../Common"

Column {
    id: themePicker
    spacing: Theme.spacingS
    
    Text {
        text: "Current Theme: " + (Theme.isDynamicTheme ? "Auto" : (Theme.currentThemeIndex < Theme.themes.length ? Theme.themes[Theme.currentThemeIndex].name : "Blue"))
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        font.weight: Font.Medium
        anchors.horizontalCenter: parent.horizontalCenter
    }
    
    // Theme description
    Text {
        text: {
            if (Theme.isDynamicTheme) {
                return "Wallpaper-based dynamic colors"
            }
            var descriptions = [
                "Material blue inspired by modern interfaces",
                "Deep blue inspired by material 3",
                "Rich purple tones for BB elegance",
                "Natural green for productivity",
                "Energetic orange for creativity",
                "Bold red for impact",
                "Cool cyan for tranquility",
                "Vibrant pink for expression",
                "Warm amber for comfort",
                "Soft coral for gentle warmth"
            ]
            return descriptions[Theme.currentThemeIndex] || "Select a theme"
        }
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        anchors.horizontalCenter: parent.horizontalCenter
        wrapMode: Text.WordWrap
        width: Math.min(parent.width, 200)
        horizontalAlignment: Text.AlignHCenter
    }
    
    // Grid layout for 10 themes (2 rows of 5)
    Column {
        spacing: Theme.spacingS
        anchors.horizontalCenter: parent.horizontalCenter
        
        // First row - Blue, Deep Blue, Purple, Green, Orange
        Row {
            spacing: Theme.spacingM
            anchors.horizontalCenter: parent.horizontalCenter
            
            Repeater {
                model: 5
                
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.themes[index].primary
                    border.color: Theme.outline
                    border.width: (Theme.currentThemeIndex === index && !Theme.isDynamicTheme) ? 2 : 1
                    
                    scale: (Theme.currentThemeIndex === index && !Theme.isDynamicTheme) ? 1.1 : 1.0
                    
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                    
                    Behavior on border.width {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                    
                    // Theme name tooltip
                    Rectangle {
                        width: nameText.contentWidth + Theme.spacingS * 2
                        height: nameText.contentHeight + Theme.spacingXS * 2
                        color: Theme.surfaceContainer
                        border.color: Theme.outline
                        border.width: 1
                        radius: Theme.cornerRadiusSmall
                        anchors.bottom: parent.top
                        anchors.bottomMargin: Theme.spacingXS
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: mouseArea.containsMouse
                        
                        Text {
                            id: nameText
                            text: Theme.themes[index].name
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.centerIn: parent
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.switchTheme(index, false)
                        }
                    }
                }
            }
        }
        
        // Second row - Red, Cyan, Pink, Amber, Coral
        Row {
            spacing: Theme.spacingM
            anchors.horizontalCenter: parent.horizontalCenter
            
            Repeater {
                model: 5
                
                Rectangle {
                    property int themeIndex: index + 5
                    width: 32
                    height: 32
                    radius: 16
                    color: themeIndex < Theme.themes.length ? Theme.themes[themeIndex].primary : "transparent"
                    border.color: Theme.outline
                    border.width: Theme.currentThemeIndex === themeIndex ? 2 : 1
                    visible: themeIndex < Theme.themes.length
                    
                    scale: Theme.currentThemeIndex === themeIndex ? 1.1 : 1.0
                    
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                    
                    Behavior on border.width {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                    
                    // Theme name tooltip
                    Rectangle {
                        width: nameText2.contentWidth + Theme.spacingS * 2
                        height: nameText2.contentHeight + Theme.spacingXS * 2
                        color: Theme.surfaceContainer
                        border.color: Theme.outline
                        border.width: 1
                        radius: Theme.cornerRadiusSmall
                        anchors.bottom: parent.top
                        anchors.bottomMargin: Theme.spacingXS
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: mouseArea2.containsMouse && themeIndex < Theme.themes.length
                        
                        Text {
                            id: nameText2
                            text: themeIndex < Theme.themes.length ? Theme.themes[themeIndex].name : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.centerIn: parent
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (themeIndex < Theme.themes.length) {
                                Theme.switchTheme(themeIndex)
                            }
                        }
                    }
                }
            }
        }
        
        // Auto theme button - prominent oval below the grid
        Rectangle {
            width: 120
            height: 40
            radius: 20
            anchors.horizontalCenter: parent.horizontalCenter
            
            color: {
                if (root.wallpaperErrorStatus === "error" || root.wallpaperErrorStatus === "matugen_missing") {
                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                } else {
                    return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                }
            }
            
            border.color: {
                if (root.wallpaperErrorStatus === "error" || root.wallpaperErrorStatus === "matugen_missing") {
                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.5)
                } else if (Theme.isDynamicTheme) {
                    return Theme.primary
                } else {
                    return Theme.outline
                }
            }
            border.width: Theme.isDynamicTheme ? 2 : 1
            
            
            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                
                Text {
                    text: {
                        if (root.wallpaperErrorStatus === "error" || root.wallpaperErrorStatus === "matugen_missing") return "error"
                        else return "palette"
                    }
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    color: {
                        if (root.wallpaperErrorStatus === "error" || root.wallpaperErrorStatus === "matugen_missing") return Theme.error
                        else return Theme.surfaceText
                    }
                    font.weight: Theme.iconFontWeight
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: {
                        if (root.wallpaperErrorStatus === "error") return "Error"
                        else if (root.wallpaperErrorStatus === "matugen_missing") return "No matugen"
                        else return "Auto"
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    color: {
                        if (root.wallpaperErrorStatus === "error" || root.wallpaperErrorStatus === "matugen_missing") return Theme.error
                        else return Theme.surfaceText
                    }
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            scale: Theme.isDynamicTheme ? 1.1 : (autoMouseArea.containsMouse ? 1.02 : 1.0)
            
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.emphasizedEasing
                }
            }
            
            Behavior on color {
                ColorAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Theme.standardEasing
                }
            }
            
            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Theme.standardEasing
                }
            }
            
            MouseArea {
                id: autoMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    Theme.switchTheme(10, true)
                }
            }
            
            // Tooltip for Auto button
            Rectangle {
                width: autoTooltipText.contentWidth + Theme.spacingM * 2
                height: autoTooltipText.contentHeight + Theme.spacingS * 2
                color: Theme.surfaceContainer
                border.color: Theme.outline
                border.width: 1
                radius: Theme.cornerRadiusSmall
                anchors.bottom: parent.top
                anchors.bottomMargin: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                visible: autoMouseArea.containsMouse && (!Theme.isDynamicTheme || root.wallpaperErrorStatus === "error" || root.wallpaperErrorStatus === "matugen_missing")
                
                Text {
                    id: autoTooltipText
                    text: {
                        if (root.wallpaperErrorStatus === "error") {
                            return "Wallpaper symlink missing at ~/quickshell/current_wallpaper"
                        } else if (root.wallpaperErrorStatus === "matugen_missing") {
                            return "Install matugen package for dynamic themes"
                        } else {
                            return "Dynamic wallpaper-based colors"
                        }
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: (root.wallpaperErrorStatus === "error" || root.wallpaperErrorStatus === "matugen_missing") ? Theme.error : Theme.surfaceText
                    anchors.centerIn: parent
                    wrapMode: Text.WordWrap
                    width: Math.min(implicitWidth, 250)
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
