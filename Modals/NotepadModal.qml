import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    property bool notepadModalVisible: false
    property bool fileDialogOpen: false
    property string currentFileName: ""  // Track the currently loaded file

    function show() {
        notepadModalVisible = true;
        shouldHaveFocus = Qt.binding(() => {
            return notepadModalVisible && !fileDialogOpen;
        });
        open();
    }

    function hide() {
        notepadModalVisible = false;
        // Clear filename when closing (so it doesn't persist between sessions)
        currentFileName = "";
        close();
    }

    function toggle() {
        if (notepadModalVisible)
            hide();
        else
            show();
    }

    visible: notepadModalVisible
    width: 700
    height: 500
    enableShadow: true
    onShouldHaveFocusChanged: {
        console.log("Notepad: shouldHaveFocus changed to", shouldHaveFocus, "modalVisible:", notepadModalVisible, "dialogOpen:", fileDialogOpen);
    }
    onBackgroundClicked: hide()

    content: Component {
        Item {
            id: contentItem

            anchors.fill: parent
            property alias textArea: textArea
            
            Connections {
                target: root
                function onNotepadModalVisibleChanged() {
                    if (root.notepadModalVisible) {
                        Qt.callLater(() => {
                            textArea.forceActiveFocus();
                        });
                    }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    height: 40

                    Row {
                        width: parent.width - closeButton.width
                        spacing: Theme.spacingM

                        Column {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            
                            StyledText {
                                text: "Notepad"
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }
                            
                            StyledText {
                                text: currentFileName
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                visible: currentFileName !== ""
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                width: 200
                            }
                        }

                        StyledText {
                            text: SessionData.notepadContent.length > 0 ? `${SessionData.notepadContent.length} characters` : "Empty"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    DankActionButton {
                        id: closeButton

                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        hoverColor: Theme.errorHover
                        onClicked: root.hide()
                    }

                }

                StyledRect {
                    width: parent.width
                    height: parent.height - 80
                    color: Theme.surface
                    border.color: Theme.outlineMedium
                    border.width: 1
                    radius: Theme.cornerRadius

                    ScrollView {
                        id: scrollView

                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true

                        TextArea {
                            id: textArea

                            text: SessionData.notepadContent
                            placeholderText: "Start typing your notes here..."
                            font.family: SettingsData.monoFontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            selectByMouse: true
                            selectByKeyboard: true
                            wrapMode: TextArea.Wrap
                            focus: root.notepadModalVisible
                            activeFocusOnTab: true
                            
                            onTextChanged: {
                                if (text !== SessionData.notepadContent) {
                                    SessionData.notepadContent = text;
                                    saveTimer.restart();
                                }
                            }
                            
                            Keys.onEscapePressed: (event) => {
                                root.hide();
                                event.accepted = true;
                            }
                            
                            Component.onCompleted: {
                                if (root.notepadModalVisible) {
                                    Qt.callLater(() => {
                                        forceActiveFocus();
                                    });
                                }
                            }

                            background: Rectangle {
                                color: "transparent"
                            }

                        }

                    }

                }

                Row {
                    width: parent.width
                    height: 32
                    spacing: Theme.spacingL

                    Row {
                        spacing: Theme.spacingS

                        DankActionButton {
                            iconName: "save"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.primary
                            hoverColor: Theme.primaryHover
                            onClicked: {
                                console.log("Notepad: Opening save dialog, releasing modal focus");
                                root.allowFocusOverride = true;
                                root.shouldHaveFocus = false;
                                fileDialogOpen = true;
                                saveBrowser.open();
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Save to file"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }

                    Row {
                        spacing: Theme.spacingS

                        DankActionButton {
                            iconName: "folder_open"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.secondary
                            hoverColor: Theme.secondaryHover
                            onClicked: {
                                console.log("Notepad: Opening load dialog, releasing modal focus");
                                root.allowFocusOverride = true;
                                root.shouldHaveFocus = false;
                                fileDialogOpen = true;
                                loadBrowser.open();
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Load file"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }

                    Item {
                        width: 1
                        height: 1
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: saveTimer.running ? "Auto-saving..." : "Auto-saved"
                        font.pixelSize: Theme.fontSizeSmall
                        color: saveTimer.running ? Theme.primary : Theme.surfaceTextMedium
                        opacity: SessionData.notepadContent.length > 0 ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }

            }

            Timer {
                id: saveTimer

                interval: 1000
                repeat: false
                onTriggered: SessionData.saveSettings()
            }

            FileBrowserModal {
                id: saveBrowser

                browserTitle: "Save Notepad File"
                browserIcon: "save"
                browserType: "notepad_save"
                fileExtensions: ["*.txt", "*.*"]
                allowStacking: true
                saveMode: true
                defaultFileName: "note.txt"
                
                onFileSelected: (path) => {
                    fileDialogOpen = false;
                    selectedFilePath = path;
                    const content = textArea.text;
                    if (content.length > 0) {
                        writeFileProcess.command = ["sh", "-c", `echo '${content.replace(/'/g, "'\\''")}' > '${path}'`];
                        writeFileProcess.running = true;
                    }
                    close();
                    // Restore modal focus
                    root.allowFocusOverride = false;
                    root.shouldHaveFocus = Qt.binding(() => {
                        return root.notepadModalVisible && !fileDialogOpen;
                    });
                    // Restore focus to TextArea after dialog closes
                    Qt.callLater(() => {
                        textArea.forceActiveFocus();
                    });
                }
                
                onDialogClosed: {
                    fileDialogOpen = false;
                    // Restore modal focus
                    root.allowFocusOverride = false;
                    root.shouldHaveFocus = Qt.binding(() => {
                        return root.notepadModalVisible && !fileDialogOpen;
                    });
                    // Restore focus to TextArea after dialog closes  
                    Qt.callLater(() => {
                        textArea.forceActiveFocus();
                    });
                }
                
                property string selectedFilePath: ""
            }

            FileBrowserModal {
                id: loadBrowser

                browserTitle: "Load Notepad File"
                browserIcon: "folder_open"
                browserType: "notepad_load"
                fileExtensions: ["*.txt", "*.*"]
                allowStacking: true
                
                onFileSelected: (path) => {
                    fileDialogOpen = false;
                    // Clean the file path - remove file:// prefix if present
                    var cleanPath = path.toString().replace(/^file:\/\//, '');
                    // Extract filename from path
                    var fileName = cleanPath.split('/').pop();
                    currentFileName = fileName;
                    console.log("Notepad: Loading file from path:", cleanPath);
                    readFileProcess.command = ["cat", cleanPath];
                    readFileProcess.running = true;
                    close();
                    // Restore modal focus
                    root.allowFocusOverride = false;
                    root.shouldHaveFocus = Qt.binding(() => {
                        return root.notepadModalVisible && !fileDialogOpen;
                    });
                    // Restore focus to TextArea after dialog closes
                    Qt.callLater(() => {
                        textArea.forceActiveFocus();
                    });
                }
                
                onDialogClosed: {
                    fileDialogOpen = false;
                    // Restore modal focus
                    root.allowFocusOverride = false;
                    root.shouldHaveFocus = Qt.binding(() => {
                        return root.notepadModalVisible && !fileDialogOpen;
                    });
                    // Restore focus to TextArea after dialog closes
                    Qt.callLater(() => {
                        textArea.forceActiveFocus();
                    });
                }
            }

            Process {
                id: writeFileProcess

                command: []
                running: false
                onExited: (exitCode) => {
                    if (exitCode === 0)
                        console.log("Notepad: File saved successfully");
                    else
                        console.warn("Notepad: Failed to save file, exit code:", exitCode);
                }
            }

            Process {
                id: readFileProcess

                command: []
                running: false
                
                stdout: StdioCollector {
                    onStreamFinished: {
                        console.log("Notepad: File content loaded, length:", text.length);
                        textArea.text = text;
                        SessionData.notepadContent = text;
                        SessionData.saveSettings();
                        console.log("Notepad: File loaded and saved to session");
                    }
                }
                
                onExited: (exitCode) => {
                    console.log("Notepad: File read process exited with code:", exitCode);
                    if (exitCode !== 0) {
                        console.warn("Notepad: Failed to load file, exit code:", exitCode);
                    }
                }
            }

        }

    }

}
