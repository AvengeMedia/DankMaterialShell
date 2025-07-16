import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: inputDialog
    
    property bool dialogVisible: false
    property string dialogTitle: "Input Required"
    property string dialogSubtitle: "Please enter the required information"
    property string inputPlaceholder: "Enter text"
    property string inputValue: ""
    property bool isPassword: false
    property string confirmButtonText: "Confirm"
    property string cancelButtonText: "Cancel"
    
    signal confirmed(string value)
    signal cancelled()
    
    visible: dialogVisible
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: dialogVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    color: "transparent"
    
    onVisibleChanged: {
        if (visible) {
            textInput.forceActiveFocus()
            textInput.text = inputValue
        }
    }
    
    function showDialog(title, subtitle, placeholder, isPass, confirmText, cancelText) {
        dialogTitle = title || "Input Required"
        dialogSubtitle = subtitle || "Please enter the required information"
        inputPlaceholder = placeholder || "Enter text"
        isPassword = isPass || false
        confirmButtonText = confirmText || "Confirm"
        cancelButtonText = cancelText || "Cancel"
        inputValue = ""
        dialogVisible = true
    }
    
    function hideDialog() {
        dialogVisible = false
        inputValue = ""
    }
    
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: dialogVisible ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.standardEasing
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                inputDialog.cancelled()
                hideDialog()
            }
        }
    }
    
    Rectangle {
        width: Math.min(400, parent.width - Theme.spacingL * 2)
        height: Math.min(250, parent.height - Theme.spacingL * 2)
        anchors.centerIn: parent
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        
        opacity: dialogVisible ? 1.0 : 0.0
        scale: dialogVisible ? 1.0 : 0.9
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingL
            
            // Header
            Row {
                width: parent.width
                
                Column {
                    width: parent.width - 40
                    spacing: Theme.spacingXS
                    
                    Text {
                        text: dialogTitle
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    Text {
                        text: dialogSubtitle
                        font.pixelSize: Theme.fontSizeMedium
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        width: parent.width
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }
                }
                
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closeDialogArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 4
                        color: closeDialogArea.containsMouse ? Theme.error : Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: closeDialogArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            inputDialog.cancelled()
                            hideDialog()
                        }
                    }
                }
            }
            
            // Text input
            Rectangle {
                width: parent.width
                height: 50
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                border.color: textInput.activeFocus ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: textInput.activeFocus ? 2 : 1
                
                TextInput {
                    id: textInput
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    echoMode: isPassword && !showPasswordCheckbox.checked ? TextInput.Password : TextInput.Normal
                    verticalAlignment: TextInput.AlignVCenter
                    cursorVisible: activeFocus
                    selectByMouse: true
                    
                    Text {
                        anchors.fill: parent
                        text: inputPlaceholder
                        font: parent.font
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                        verticalAlignment: Text.AlignVCenter
                        visible: parent.text.length === 0
                    }
                    
                    onTextChanged: {
                        inputValue = text
                    }
                    
                    onAccepted: {
                        inputDialog.confirmed(inputValue)
                        hideDialog()
                    }
                    
                    Component.onCompleted: {
                        if (dialogVisible) {
                            forceActiveFocus()
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: {
                        textInput.forceActiveFocus()
                    }
                }
            }
            
            // Show password checkbox (only visible for password inputs)
            Row {
                spacing: Theme.spacingS
                visible: isPassword
                
                Rectangle {
                    id: showPasswordCheckbox
                    property bool checked: false
                    
                    width: 20
                    height: 20
                    radius: 4
                    color: checked ? Theme.primary : "transparent"
                    border.color: checked ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)
                    border.width: 2
                    
                    Text {
                        anchors.centerIn: parent
                        text: "check"
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.background
                        visible: parent.checked
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            showPasswordCheckbox.checked = !showPasswordCheckbox.checked
                        }
                    }
                }
                
                Text {
                    text: "Show password"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            // Buttons
            Item {
                width: parent.width
                height: 40
                
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM
                    
                    Rectangle {
                        width: Math.max(70, cancelText.contentWidth + Theme.spacingM * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: cancelArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : "transparent"
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        border.width: 1
                        
                        Text {
                            id: cancelText
                            anchors.centerIn: parent
                            text: cancelButtonText
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }
                        
                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                inputDialog.cancelled()
                                hideDialog()
                            }
                        }
                    }
                    
                    Rectangle {
                        width: Math.max(80, confirmText.contentWidth + Theme.spacingM * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: confirmArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                        enabled: inputValue.length > 0
                        opacity: enabled ? 1.0 : 0.5
                        
                        Text {
                            id: confirmText
                            anchors.centerIn: parent
                            text: confirmButtonText
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.background
                            font.weight: Font.Medium
                        }
                        
                        MouseArea {
                            id: confirmArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: parent.enabled
                            onClicked: {
                                inputDialog.confirmed(inputValue)
                                hideDialog()
                            }
                        }
                        
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }
            }
        }
    }
}