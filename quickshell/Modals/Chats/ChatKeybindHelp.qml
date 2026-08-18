pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

// What you can press inside the chat window.
//
// Only shortcuts that work here; the global bindings for opening chat live in
// Settings under Keyboard Shortcuts, because those are the user's to choose and
// this cannot know what they picked.
StyledRect {
    id: root

    signal dismissed

    color: Theme.withAlpha(Theme.surfaceContainer, 0.97)
    radius: Theme.cornerRadius

    // Swallow clicks so nothing behind reacts while help is up.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.dismissed()
    }

    readonly property var groups: [
        {
            "title": I18n.tr("Selecting a message"),
            "binds": [
                {
                    "keys": "Alt + K",
                    "text": I18n.tr("Select the previous message")
                },
                {
                    "keys": "Alt + J",
                    "text": I18n.tr("Select the next message")
                },
                {
                    "keys": "Shift + Enter",
                    "text": I18n.tr("Open the selected message's attachment or link")
                },
                {
                    "keys": "Esc",
                    "text": I18n.tr("Clear the selection, then close")
                }
            ]
        },
        {
            "title": I18n.tr("Acting on the selected message"),
            "binds": [
                {
                    "keys": "Ctrl + Shift + C",
                    "text": I18n.tr("Copy the text, or the attachment as a file")
                },
                {
                    "keys": "Alt + R",
                    "text": I18n.tr("Reply, where the provider supports it")
                },
                {
                    "keys": "Alt + F",
                    "text": I18n.tr("Forward to another conversation")
                },
                {
                    "keys": "Delete",
                    "text": I18n.tr("Delete from this device, after confirming")
                },
                {
                    "keys": "Shift + Delete",
                    "text": I18n.tr("Delete for everyone, after confirming")
                }
            ]
        },
        {
            "title": I18n.tr("Writing"),
            "binds": [
                {
                    "keys": "Enter",
                    "text": I18n.tr("Send, always -- the text field keeps focus")
                },
                {
                    "keys": "Ctrl + V",
                    "text": I18n.tr("Attach an image or file from the clipboard")
                }
            ]
        },
        {
            "title": I18n.tr("Finding"),
            "binds": [
                {
                    "keys": I18n.tr("Type in the search box"),
                    "text": I18n.tr("Filters conversations, and searches message text after two characters")
                }
            ]
        }
    ]

    Keys.onEscapePressed: event => {
        root.dismissed();
        event.accepted = true;
    }

    DankFlickable {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        clip: true
        contentHeight: helpColumn.height

        Column {
            id: helpColumn
            width: parent.width
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - closeButton.width - Theme.spacingS
                    text: I18n.tr("Keyboard Shortcuts")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                DankActionButton {
                    id: closeButton
                    anchors.verticalCenter: parent.verticalCenter
                    buttonSize: 28
                    iconName: "close"
                    iconColor: Theme.surfaceVariantText
                    onClicked: root.dismissed()
                }
            }

            Repeater {
                model: root.groups

                Column {
                    required property var modelData

                    width: helpColumn.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: parent.modelData.title
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.primary
                        bottomPadding: 2
                    }

                    Repeater {
                        model: parent.modelData.binds

                        Row {
                            required property var modelData

                            width: helpColumn.width
                            spacing: Theme.spacingM

                            StyledRect {
                                width: Math.max(110, keyLabel.implicitWidth + Theme.spacingM)
                                height: keyLabel.implicitHeight + Theme.spacingXS * 2
                                radius: Theme.cornerRadius / 2
                                color: Theme.withAlpha(Theme.surfaceVariantText, 0.14)

                                StyledText {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: parent.parent.modelData.keys
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.monoFontFamily
                                    color: Theme.surfaceText
                                }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: helpColumn.width - Math.max(110, keyLabel.implicitWidth + Theme.spacingM) - Theme.spacingM
                                text: parent.modelData.text
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            StyledText {
                width: parent.width
                topPadding: Theme.spacingS
                text: I18n.tr("Shortcuts for opening chat from anywhere are set under Settings, Keyboard Shortcuts.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }
    }
}
