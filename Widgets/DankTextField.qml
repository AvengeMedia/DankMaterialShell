import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    activeFocusOnTab: true

    KeyNavigation.tab: keyNavigationTab
    KeyNavigation.backtab: keyNavigationBacktab

    onActiveFocusChanged: {
        if (activeFocus) {
            textInput.forceActiveFocus()
        }
    }

    property alias text: textInput.text
    property string placeholderText: ""
    property alias font: textInput.font
    property alias textColor: textInput.color
    property alias enabled: textInput.enabled
    property alias echoMode: textInput.echoMode
    property alias validator: textInput.validator
    property alias maximumLength: textInput.maximumLength
    property string leftIconName: ""
    property int leftIconSize: Theme.iconSize
    property color leftIconColor: Theme.surfaceVariantText
    property color leftIconFocusedColor: Theme.primary
    property bool showClearButton: false
    property color backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    property color focusedBorderColor: Theme.primary
    property color normalBorderColor: Theme.outlineStrong
    property color placeholderColor: Theme.outlineButton
    property int borderWidth: 1
    property int focusedBorderWidth: 2
    property real cornerRadius: Theme.cornerRadius
    readonly property real leftPadding: Theme.spacingM + (leftIconName ? leftIconSize + Theme.spacingM : 0)
    readonly property real rightPadding: Theme.spacingM + (showClearButton && text.length > 0 ? 24 + Theme.spacingM : 0)
    property real topPadding: Theme.spacingM
    property real bottomPadding: Theme.spacingM
    property bool ignoreLeftRightKeys: false
    property bool ignoreTabKeys: false
    property var keyForwardTargets: []
    property Item keyNavigationTab: null
    property Item keyNavigationBacktab: null

    signal textEdited
    signal editingFinished
    signal accepted
    signal focusStateChanged(bool hasFocus)

    function getActiveFocus() {
        return textInput.activeFocus
    }
    function setFocus(value) {
        textInput.focus = value
    }
    function forceActiveFocus() {
        textInput.forceActiveFocus()
    }
    function selectAll() {
        textInput.selectAll()
    }
    function clear() {
        textInput.clear()
    }
    function insertText(str) {
        textInput.insert(textInput.cursorPosition, str)
    }

    width: 200
    height: 48
    radius: cornerRadius
    color: backgroundColor
    border.color: textInput.activeFocus ? focusedBorderColor : normalBorderColor
    border.width: textInput.activeFocus ? focusedBorderWidth : borderWidth

    DankIcon {
        id: leftIcon

        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        name: leftIconName
        size: leftIconSize
        color: textInput.activeFocus ? leftIconFocusedColor : leftIconColor
        visible: leftIconName !== ""
    }

    TextInput {
        id: textInput

        anchors.fill: parent
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding
        anchors.topMargin: root.topPadding
        anchors.bottomMargin: root.bottomPadding
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: !root.ignoreLeftRightKeys
        clip: true
        activeFocusOnTab: true
        KeyNavigation.tab: root.keyNavigationTab
        KeyNavigation.backtab: root.keyNavigationBacktab
        onTextChanged: root.textEdited()
        onEditingFinished: root.editingFinished()
        onAccepted: root.accepted()
        onActiveFocusChanged: root.focusStateChanged(activeFocus)
        Keys.forwardTo: root.keyForwardTargets
        Keys.onLeftPressed: event => {
                                if (root.ignoreLeftRightKeys) {
                                    event.accepted = true
                                } else {
                                    // Allow normal TextInput cursor movement
                                    event.accepted = false
                                }
                            }
        Keys.onRightPressed: event => {
                                 if (root.ignoreLeftRightKeys) {
                                     event.accepted = true
                                 } else {
                                     event.accepted = false
                                 }
                             }
        Keys.onPressed: event => {
                            if (root.ignoreTabKeys && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                                event.accepted = false
                                for (var i = 0; i < root.keyForwardTargets.length; i++) {
                                    if (root.keyForwardTargets[i]) {
                                        root.keyForwardTargets[i].Keys.pressed(event)
                                    }
                                }
                            }
                        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true 
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
        }
    }

    StyledRect {
        id: clearButton

        width: 24
        height: 24
        radius: 12
        color: clearArea.containsMouse ? Theme.outlineStrong : "transparent"
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        visible: showClearButton && text.length > 0

        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: 16
            color: clearArea.containsMouse ? Theme.outline : Theme.surfaceVariantText
        }

        MouseArea {
            id: clearArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                textInput.text = ""
            }
        }
    }

    StyledText {
        id: placeholderLabel

        anchors.fill: textInput
        text: root.placeholderText
        font: textInput.font
        color: placeholderColor
        verticalAlignment: textInput.verticalAlignment
        visible: textInput.text.length === 0 && !textInput.activeFocus
        elide: Text.ElideRight
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on border.width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
