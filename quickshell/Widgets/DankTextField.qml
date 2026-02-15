import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    KeyNavigation.tab: keyNavigationTab
    KeyNavigation.backtab: keyNavigationBacktab

    function checkParentDisablesTransparency() {
        let p = parent;
        while (p) {
            if (p.disablePopupTransparency === true)
                return true;
            p = p.parent;
        }
        return false;
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
    property bool showPasswordToggle: false
    property bool passwordVisible: false
    property bool usePopupTransparency: !checkParentDisablesTransparency()
    property color backgroundColor: usePopupTransparency ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.surfaceContainerHigh
    property color focusedBorderColor: Theme.primary
    property color normalBorderColor: Theme.outlineMedium
    property color placeholderColor: Theme.outlineButton
    property int borderWidth: 1
    property int focusedBorderWidth: 2
    property real cornerRadius: Theme.cornerRadius
    readonly property real leftPadding: Theme.spacingM + (leftIconName ? leftIconSize + Theme.spacingM : 0)
    readonly property real rightPadding: {
        let p = Theme.spacingS;
        if (showPasswordToggle)
            p += 20 + Theme.spacingXS;
        if (showClearButton && text.length > 0)
            p += 20 + Theme.spacingXS;
        return p;
    }
    property real topPadding: Theme.spacingS
    property real bottomPadding: Theme.spacingS
    property bool ignoreLeftRightKeys: false
    property bool ignoreUpDownKeys: false
    property bool ignoreTabKeys: false
    property var keyForwardTargets: []
    property Item keyNavigationTab: null
    property Item keyNavigationBacktab: null

    signal textEdited
    signal editingFinished
    signal accepted
    signal focusStateChanged(bool hasFocus)

    function getActiveFocus() {
        return textInput.activeFocus;
    }
    function setFocus(value) {
        textInput.focus = value;
    }
    function forceActiveFocus() {
        textInput.forceActiveFocus();
    }
    function selectAll() {
        textInput.selectAll();
    }
    function clear() {
        textInput.clear();
    }
    function insertText(str) {
        textInput.insert(textInput.cursorPosition, str);
    }

    width: 200
    height: Math.round(Theme.fontSizeMedium * 3)
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

        anchors.left: leftIcon.visible ? leftIcon.right : parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.right: rightButtonsRow.left
        anchors.rightMargin: rightButtonsRow.visible ? Theme.spacingS : Theme.spacingM
        anchors.top: parent.top
        anchors.topMargin: root.topPadding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomPadding
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        selectionColor: Theme.primaryContainer
        selectedTextColor: Theme.primary
        horizontalAlignment: TextInput.AlignLeft
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
                event.accepted = true;
            } else {
                // Allow normal TextInput cursor movement
                event.accepted = false;
            }
        }
        Keys.onRightPressed: event => {
            if (root.ignoreLeftRightKeys) {
                event.accepted = true;
            } else {
                event.accepted = false;
            }
        }
        Keys.onPressed: event => {
            if (root.ignoreTabKeys && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                event.accepted = false;
                for (var i = 0; i < root.keyForwardTargets.length; i++) {
                    if (root.keyForwardTargets[i])
                        root.keyForwardTargets[i].Keys.pressed(event);
                }
                return;
            }
            if (root.ignoreUpDownKeys && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                event.accepted = false;
                for (var i = 0; i < root.keyForwardTargets.length; i++) {
                    if (root.keyForwardTargets[i])
                        root.keyForwardTargets[i].Keys.pressed(event);
                }
                return;
            }
            if ((event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && root.keyForwardTargets.length > 0) {
                for (var i = 0; i < root.keyForwardTargets.length; i++) {
                    if (root.keyForwardTargets[i])
                        root.keyForwardTargets[i].Keys.pressed(event);
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

    Row {
        id: rightButtonsRow

        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS
        visible: showPasswordToggle || (showClearButton && text.length > 0)

        StyledRect {
            id: passwordToggleButton

            width: 20
            height: 20
            radius: 10
            color: passwordToggleArea.containsMouse ? Theme.outlineStrong : "transparent"
            visible: showPasswordToggle

            DankIcon {
                anchors.centerIn: parent
                name: passwordVisible ? "visibility_off" : "visibility"
                size: 14
                color: passwordToggleArea.containsMouse ? Theme.outline : Theme.surfaceVariantText
            }

            MouseArea {
                id: passwordToggleArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: passwordVisible = !passwordVisible
            }
        }

        StyledRect {
            id: clearButton

            width: 20
            height: 20
            radius: 10
            color: clearArea.containsMouse ? Theme.outlineStrong : "transparent"
            visible: showClearButton && text.length > 0

            DankIcon {
                anchors.centerIn: parent
                name: "close"
                size: 14
                color: clearArea.containsMouse ? Theme.outline : Theme.surfaceVariantText
            }

            MouseArea {
                id: clearArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: textInput.text = ""
            }
        }
    }

    StyledText {
        id: placeholderLabel

        anchors.fill: textInput
        text: root.placeholderText
        font: textInput.font
        color: placeholderColor
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: textInput.verticalAlignment
        visible: textInput.text.length === 0 && !textInput.activeFocus
        elide: I18n.isRtl ? Text.ElideLeft : Text.ElideRight
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
