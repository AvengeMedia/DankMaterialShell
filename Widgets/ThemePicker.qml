import QtQuick
import "../Common"

Column {
    id: themePicker
    spacing: Theme.spacingS
    
    Text {
        text: "Current Theme: " + Theme.themes[Theme.currentThemeIndex].name
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        font.weight: Font.Medium
        anchors.horizontalCenter: parent.horizontalCenter
    }
    
    // Theme description
    Text {
        text: {
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
                    border.width: Theme.currentThemeIndex === index ? 2 : 1
                    
                    scale: Theme.currentThemeIndex === index ? 1.1 : 1.0
                    
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
                            Theme.switchTheme(index)
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
    }
}
