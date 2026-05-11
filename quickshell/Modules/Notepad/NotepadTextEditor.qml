pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    Component.onCompleted: {
        if (PluginService.isPluginLoaded("dankNotepadModule")) {
            pluginHighlightedHtml = SettingsData.getBuiltInPluginSetting("dankNotepadModule", "highlightedHtml", "");
        }
    }

    property alias text: textArea.text
    property alias textArea: textArea
    property bool contentLoaded: false
    property string lastSavedContent: ""
    property var currentTab: NotepadStorageService.tabs.length > NotepadStorageService.currentTabIndex ? NotepadStorageService.tabs[NotepadStorageService.currentTabIndex] : null
    property bool searchVisible: false
    property string searchQuery: ""
    property var searchMatches: []
    property int currentMatchIndex: -1
    property int matchCount: 0
    property bool inlinePreviewVisible: false
    property string previewMode: "split" // split | full
    property string pluginHighlightedHtml: ""
    property string lastPluginContent: ""
    property int loadRequestId: 0

    signal saveRequested
    signal openRequested
    signal newRequested
    signal previewRequested
    signal escapePressed
    signal contentChanged
    signal settingsRequested

    function hasUnsavedChanges() {
        if (!currentTab || !contentLoaded) {
            return false;
        }

        if (currentTab.isTemporary) {
            return textArea.text.length > 0;
        }
        return textArea.text !== lastSavedContent;
    }

    function loadCurrentTabContent() {
        if (!currentTab)
            return;
        const requestedTabId = currentTab.id;
        const requestId = ++loadRequestId;
        contentLoaded = false;
        NotepadStorageService.loadTabContent(NotepadStorageService.currentTabIndex, content => {
            const activeTab = NotepadStorageService.tabs.length > NotepadStorageService.currentTabIndex ? NotepadStorageService.tabs[NotepadStorageService.currentTabIndex] : null;
            if (requestId !== loadRequestId || !activeTab || activeTab.id !== requestedTabId)
                return;
            lastSavedContent = content;
            textArea.text = content;
            contentLoaded = true;
            syncContentToPlugin();
        });
    }

    function saveCurrentTabContent() {
        if (!currentTab || !contentLoaded)
            return;
        NotepadStorageService.saveTabContent(NotepadStorageService.currentTabIndex, textArea.text);
        lastSavedContent = textArea.text;
    }

    function autoSaveToSession() {
        if (!currentTab || !contentLoaded)
            return;
        saveCurrentTabContent();
    }

    function setTextDocumentLineHeight() {
        return;
    }

    property string lastTextForLineModel: ""
    property var lineModel: []

    function updateLineModel() {
        if (!SettingsData.notepadShowLineNumbers) {
            lineModel = [];
            lastTextForLineModel = "";
            return;
        }

        if (textArea.text !== lastTextForLineModel || lineModel.length === 0) {
            lastTextForLineModel = textArea.text;
            lineModel = textArea.text.split('\n');
        }
    }

    function performSearch() {
        let matches = [];
        currentMatchIndex = -1;

        if (!searchQuery || searchQuery.length === 0) {
            searchMatches = [];
            matchCount = 0;
            textArea.select(0, 0);
            return;
        }

        const text = textArea.text;
        const query = searchQuery.toLowerCase();
        let index = 0;

        while (index < text.length) {
            const foundIndex = text.toLowerCase().indexOf(query, index);
            if (foundIndex === -1)
                break;
            matches.push({
                start: foundIndex,
                end: foundIndex + searchQuery.length
            });
            index = foundIndex + 1;
        }

        searchMatches = matches;
        matchCount = matches.length;

        if (matchCount > 0) {
            currentMatchIndex = 0;
            highlightCurrentMatch();
        } else {
            textArea.select(0, 0);
        }
    }

    function highlightCurrentMatch() {
        if (currentMatchIndex >= 0 && currentMatchIndex < searchMatches.length) {
            const match = searchMatches[currentMatchIndex];

            textArea.cursorPosition = match.start;
            textArea.moveCursorSelection(match.end, TextEdit.SelectCharacters);

            const flickable = textArea.parent;
            if (flickable && flickable.contentY !== undefined) {
                const lineHeight = textArea.font.pixelSize * 1.5;
                const approxLine = textArea.text.substring(0, match.start).split('\n').length;
                const targetY = approxLine * lineHeight - flickable.height / 2;
                flickable.contentY = Math.max(0, Math.min(targetY, flickable.contentHeight - flickable.height));
            }
        }
    }

    function findNext() {
        if (matchCount === 0 || searchMatches.length === 0)
            return;
        currentMatchIndex = (currentMatchIndex + 1) % matchCount;
        highlightCurrentMatch();
    }

    function findPrevious() {
        if (matchCount === 0 || searchMatches.length === 0)
            return;
        currentMatchIndex = currentMatchIndex <= 0 ? matchCount - 1 : currentMatchIndex - 1;
        highlightCurrentMatch();
    }

    function showSearch() {
        searchVisible = true;
        Qt.callLater(() => {
            searchField.forceActiveFocus();
        });
    }

    function togglePreview() {
        if (!inlinePreviewVisible) {
            inlinePreviewVisible = true;
            previewMode = "split";
        } else if (previewMode === "split") {
            previewMode = "full";
        } else {
            inlinePreviewVisible = false;
            previewMode = "split";
        }
        syncContentToPlugin();
    }

    function renderPreviewHtml() {
        if (!inlinePreviewVisible)
            return "";
        return pluginHighlightedHtml.length > 0 ? pluginHighlightedHtml : "<p><i>Rendering preview…</i></p>";
    }

    function syncContentToPlugin() {
        if (!PluginService.isPluginLoaded("dankNotepadModule"))
            return;
        if (!currentTab)
            return;
        const filePath = currentTab?.filePath || "";
        const ext = filePath.split('.').pop().toLowerCase();
        const content = textArea.text;

        if (content === lastPluginContent && SettingsData.getBuiltInPluginSetting("dankNotepadModule", "previewActive", false) === inlinePreviewVisible) {
            return;
        }

        lastPluginContent = content;
        SettingsData.setBuiltInPluginSetting("dankNotepadModule", "previewActive", inlinePreviewVisible);
        SettingsData.setBuiltInPluginSetting("dankNotepadModule", "currentFilePath", filePath);
        SettingsData.setBuiltInPluginSetting("dankNotepadModule", "currentFileExtension", ext);
        SettingsData.setBuiltInPluginSetting("dankNotepadModule", "sourceContent", content);
        SettingsData.setBuiltInPluginSetting("dankNotepadModule", "updatedAt", Date.now());
    }

    function hideSearch() {
        searchVisible = false;
        searchQuery = "";
        searchMatches = [];
        matchCount = 0;
        currentMatchIndex = -1;
        textArea.select(0, 0);
        textArea.forceActiveFocus();
    }

    function copyPlainTextToClipboard() {
        if (!inlinePreviewVisible || !textArea.text)
            return;
        const content = textArea.text;
        if (content.length === 0)
            return;
        const proc = clipboardCopyProcComp.createObject(root, {
            content: content,
            running: true
        });
        proc.exited.connect(() => {
            ToastService.showInfo(I18n.tr("Copied to clipboard"));
            proc.destroy();
        });
    }

    function copyHtmlToClipboard() {
        if (!inlinePreviewVisible || !pluginHighlightedHtml)
            return;
        if (pluginHighlightedHtml.length === 0)
            return;
        const proc = clipboardCopyProcComp.createObject(root, {
            content: pluginHighlightedHtml,
            running: true
        });
        proc.exited.connect(() => {
            ToastService.showInfo(I18n.tr("HTML copied to clipboard"));
            proc.destroy();
        });
    }

    Component {
        id: clipboardCopyProcComp
        Process {
            property string content: ""
            command: ["sh", "-c", "printf '%s' \"$CONTENT\" | dms clipboard copy"]
            environment: ({
                    "CONTENT": content
                })
        }
    }

    spacing: Theme.spacingM

    StyledRect {
        id: searchBar
        width: parent.width
        height: 48
        visible: searchVisible
        opacity: searchVisible ? 1 : 0
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        border.color: searchField.activeFocus ? Theme.primary : Theme.outlineMedium
        border.width: searchField.activeFocus ? 2 : 1
        radius: Theme.cornerRadius

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingS

            // Search icon
            DankIcon {
                Layout.alignment: Qt.AlignVCenter
                name: "search"
                size: Theme.iconSize - 2
                color: searchField.activeFocus ? Theme.primary : Theme.surfaceVariantText
            }

            // Search input field
            TextInput {
                id: searchField
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 32
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                clip: true

                Component.onCompleted: {
                    text = root.searchQuery;
                }

                Connections {
                    target: root
                    function onSearchQueryChanged() {
                        if (searchField.text !== root.searchQuery) {
                            searchField.text = root.searchQuery;
                        }
                    }
                }

                onTextChanged: {
                    if (root.searchQuery !== text) {
                        root.searchQuery = text;
                        root.performSearch();
                    }
                }
                Keys.onEscapePressed: event => {
                    root.hideSearch();
                    event.accepted = true;
                }
                Keys.onReturnPressed: event => {
                    if (event.modifiers & Qt.ShiftModifier) {
                        root.findPrevious();
                    } else {
                        root.findNext();
                    }
                    event.accepted = true;
                }
                Keys.onEnterPressed: event => {
                    if (event.modifiers & Qt.ShiftModifier) {
                        root.findPrevious();
                    } else {
                        root.findNext();
                    }
                    event.accepted = true;
                }
            }

            // Placeholder text
            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: I18n.tr("Find in note...")
                font: searchField.font
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                visible: searchField.text.length === 0 && !searchField.activeFocus
                Layout.leftMargin: -(searchField.width - 20) // Position over the input field
            }

            // Match count display
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: matchCount > 0 ? "%1/%2".arg(currentMatchIndex + 1).arg(matchCount) : searchQuery.length > 0 ? I18n.tr("No matches") : ""
                font.pixelSize: Theme.fontSizeSmall
                color: matchCount > 0 ? Theme.primary : Theme.surfaceTextMedium
                visible: searchQuery.length > 0
                Layout.rightMargin: Theme.spacingS
            }

            // Navigation buttons
            DankActionButton {
                id: prevButton
                Layout.alignment: Qt.AlignVCenter
                iconName: "keyboard_arrow_up"
                iconSize: Theme.iconSize
                iconColor: matchCount > 0 ? Theme.surfaceText : Theme.surfaceTextAlpha
                enabled: matchCount > 0
                onClicked: root.findPrevious()
            }

            DankActionButton {
                id: nextButton
                Layout.alignment: Qt.AlignVCenter
                iconName: "keyboard_arrow_down"
                iconSize: Theme.iconSize
                iconColor: matchCount > 0 ? Theme.surfaceText : Theme.surfaceTextAlpha
                enabled: matchCount > 0
                onClicked: root.findNext()
            }

            DankActionButton {
                id: closeSearchButton
                Layout.alignment: Qt.AlignVCenter
                iconName: "close"
                iconSize: Theme.iconSize - 2
                iconColor: Theme.surfaceText
                onClicked: root.hideSearch()
            }
        }
    }

    StyledRect {
        width: parent.width
        height: parent.height - bottomControls.height - Theme.spacingM - (searchVisible ? searchBar.height + Theme.spacingM : 0)
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.notepadTransparency)
        border.color: Theme.outlineMedium
        border.width: 1
        radius: Theme.cornerRadius

        RowLayout {
            id: editorPreviewRow
            anchors.fill: parent
            anchors.margins: 1
            spacing: Theme.spacingM

            Item {
                id: editorPane
                visible: !inlinePreviewVisible || previewMode === "split"
                Layout.fillHeight: true
                Layout.fillWidth: !inlinePreviewVisible || previewMode === "split"
                Layout.preferredWidth: inlinePreviewVisible ? parent.width * 0.55 : parent.width
                clip: true

                DankFlickable {
                    id: flickable
                    anchors.fill: parent
                    clip: true
                    contentWidth: width - 11

                    Rectangle {
                        id: lineNumberArea
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: SettingsData.notepadShowLineNumbers ? Math.max(30, 32 + Theme.spacingXS) : 0
                        height: textArea.contentHeight + textArea.topPadding + textArea.bottomPadding
                        color: "transparent"
                        visible: SettingsData.notepadShowLineNumbers

                        ListView {
                            id: lineNumberList
                            anchors.top: parent.top
                            anchors.topMargin: textArea.topPadding
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            width: 32
                            height: textArea.contentHeight
                            model: SettingsData.notepadShowLineNumbers ? root.lineModel : []
                            interactive: false
                            spacing: 0

                            delegate: Item {
                                id: lineDelegate
                                required property int index
                                required property string modelData
                                width: 32
                                height: measuringText.contentHeight

                                Text {
                                    id: measuringText
                                    width: textArea.width - textArea.leftPadding - textArea.rightPadding
                                    text: modelData || " "
                                    font: textArea.font
                                    wrapMode: Text.Wrap
                                    visible: false
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.top: parent.top
                                    text: index + 1
                                    font.family: textArea.font.family
                                    font.pixelSize: textArea.font.pixelSize
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }

                    TextArea.flickable: TextArea {
                        id: textArea
                        placeholderText: ""
                        placeholderTextColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                        font.family: SettingsData.notepadUseMonospace ? SettingsData.monoFontFamily : (SettingsData.notepadFontFamily || SettingsData.fontFamily)
                        font.pixelSize: SettingsData.notepadFontSize * SettingsData.fontScale
                        font.letterSpacing: 0
                        color: Theme.surfaceText
                        selectedTextColor: Theme.background
                        selectionColor: Theme.primary
                        selectByMouse: true
                        selectByKeyboard: true
                        wrapMode: TextArea.Wrap
                        focus: true
                        activeFocusOnTab: true
                        textFormat: TextEdit.PlainText
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        persistentSelection: true
                        tabStopDistance: 40
                        leftPadding: (SettingsData.notepadShowLineNumbers ? lineNumberArea.width + Theme.spacingXS : Theme.spacingM)
                        topPadding: Theme.spacingM
                        rightPadding: Theme.spacingM
                        bottomPadding: Theme.spacingM
                        cursorDelegate: Rectangle {
                            width: 1.5
                            radius: 1
                            color: Theme.surfaceText
                            x: textArea.cursorRectangle.x
                            y: textArea.cursorRectangle.y
                            height: textArea.cursorRectangle.height
                            opacity: 1.0

                            SequentialAnimation on opacity {
                                running: textArea.activeFocus
                                loops: Animation.Infinite
                                OpacityAnimator {
                                    from: 1.0
                                    to: 0.0
                                    duration: 650
                                    easing.type: Easing.InOutQuad
                                }
                                OpacityAnimator {
                                    from: 0.0
                                    to: 1.0
                                    duration: 650
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        Component.onCompleted: {
                            loadCurrentTabContent();
                            setTextDocumentLineHeight();
                            root.updateLineModel();
                            Qt.callLater(() => {
                                textArea.forceActiveFocus();
                            });
                        }

                        Connections {
                            target: NotepadStorageService
                            function onCurrentTabIndexChanged() {
                                loadCurrentTabContent();
                                Qt.callLater(() => {
                                    textArea.forceActiveFocus();
                                });
                            }
                            function onTabsChanged() {
                                if (NotepadStorageService.tabs.length > 0 && !contentLoaded) {
                                    loadCurrentTabContent();
                                }
                            }
                        }

                        Connections {
                            target: SettingsData
                            function onNotepadShowLineNumbersChanged() {
                                root.updateLineModel();
                            }
                        }

                        onTextChanged: {
                            if (contentLoaded && text !== lastSavedContent) {
                                autoSaveTimer.restart();
                            }
                            root.contentChanged();
                            root.updateLineModel();
                            pluginSyncTimer.restart();
                        }

                        Keys.onEscapePressed: event => {
                            root.escapePressed();
                            event.accepted = true;
                        }

                        Keys.onPressed: event => {
                            if (event.modifiers & Qt.ControlModifier) {
                                switch (event.key) {
                                case Qt.Key_S:
                                    event.accepted = true;
                                    root.saveRequested();
                                    break;
                                case Qt.Key_O:
                                    event.accepted = true;
                                    root.openRequested();
                                    break;
                                case Qt.Key_N:
                                    event.accepted = true;
                                    root.newRequested();
                                    break;
                                case Qt.Key_A:
                                    event.accepted = true;
                                    textArea.selectAll();
                                    break;
                                case Qt.Key_F:
                                    event.accepted = true;
                                    root.showSearch();
                                    break;
                                case Qt.Key_P:
                                    if (PluginService.isPluginLoaded("dankNotepadModule")) {
                                        event.accepted = true;
                                        root.previewRequested();
                                    }
                                    break;
                                }
                            }
                        }

                        background: Rectangle {
                            color: "transparent"
                        }
                    }

                    StyledText {
                        id: placeholderOverlay
                        text: I18n.tr("Start typing your notes here...")
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                        font.family: textArea.font.family
                        font.pixelSize: textArea.font.pixelSize
                        visible: textArea.text.length === 0
                        anchors.left: textArea.left
                        anchors.top: textArea.top
                        anchors.leftMargin: textArea.leftPadding
                        anchors.topMargin: textArea.topPadding
                        z: textArea.z + 1
                    }
                }
            }

            Rectangle {
                id: previewDivider
                visible: inlinePreviewVisible && previewMode === "split"
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Theme.outlineMedium
            }

            Item {
                id: previewPane
                visible: inlinePreviewVisible
                Layout.fillHeight: true
                Layout.fillWidth: previewMode === "full"
                Layout.preferredWidth: previewMode === "full" ? parent.width : parent.width * 0.45
                clip: true

                // Preview header with copy buttons
                Rectangle {
                    id: previewHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 36
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.notepadTransparency)
                    z: 2

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        // Copy plain text button
                        DankActionButton {
                            iconName: "content_copy"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceTextMedium
                            onClicked: copyPlainTextToClipboard()
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Copy Text")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }

                        Rectangle {
                            width: 1
                            height: 20
                            color: Theme.outlineVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Copy HTML button
                        DankActionButton {
                            iconName: "code"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceTextMedium
                            onClicked: copyHtmlToClipboard()
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Copy HTML")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }
                }

                DankFlickable {
                    id: previewFlickable
                    anchors.top: previewHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.topMargin: Theme.spacingS
                    clip: true
                    contentWidth: width - 11
                    contentHeight: previewText.paintedHeight + Theme.spacingM * 2

                    Text {
                        id: previewText
                        width: parent.width - Theme.spacingM
                        padding: Theme.spacingM
                        wrapMode: Text.WordWrap
                        textFormat: Text.RichText
                        text: inlinePreviewVisible ? renderPreviewHtml() : ""
                        color: Theme.surfaceText
                        font.family: SettingsData.notepadFontFamily || SettingsData.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        linkColor: Theme.primary

                        onLinkActivated: url => Qt.openUrlExternally(url)
                    }
                }
            }
        }
    }

    Column {
        id: bottomControls
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingL

                Row {
                    spacing: Theme.spacingS
                    DankActionButton {
                        iconName: "save"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.primary
                        enabled: currentTab && (hasUnsavedChanges() || textArea.text.length > 0)
                        onClicked: root.saveRequested()
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Save")
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
                        onClicked: root.openRequested()
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Open")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                }

                Row {
                    spacing: Theme.spacingS
                    DankActionButton {
                        iconName: "note_add"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.surfaceText
                        onClicked: root.newRequested()
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("New")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                }

                Row {
                    spacing: Theme.spacingS
                    visible: PluginService.isPluginLoaded("dankNotepadModule")
                    DankActionButton {
                        iconName: inlinePreviewVisible ? "visibility" : "visibility_off"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.surfaceText
                        enabled: textArea.text.length > 0
                        onClicked: root.previewRequested()
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Preview")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                }
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "more_horiz"
                iconSize: Theme.iconSize - 2
                iconColor: Theme.surfaceText
                onClicked: root.settingsRequested()
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingL

            StyledText {
                text: {
                    const len = textArea.text.length;
                    if (len === 0)
                        return I18n.tr("Empty");
                    return len === 1 ? I18n.tr("%1 character").arg(len) : I18n.tr("%1 characters").arg(len);
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }

            StyledText {
                text: textArea.lineCount === 1 ? I18n.tr("Line: %1").arg(textArea.lineCount) : I18n.tr("Lines: %1").arg(textArea.lineCount)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                visible: textArea.text.length > 0
                opacity: 1.0
            }

            StyledText {
                text: {
                    if (autoSaveTimer.running) {
                        return I18n.tr("Auto-saving...");
                    }

                    if (hasUnsavedChanges()) {
                        if (currentTab && currentTab.isTemporary) {
                            return I18n.tr("Unsaved note...");
                        } else {
                            return I18n.tr("Unsaved changes");
                        }
                    } else {
                        return I18n.tr("Saved");
                    }
                }
                font.pixelSize: Theme.fontSizeSmall
                color: {
                    if (autoSaveTimer.running) {
                        return Theme.primary;
                    }

                    if (hasUnsavedChanges()) {
                        return Theme.warning;
                    } else {
                        return Theme.success;
                    }
                }
                opacity: textArea.text.length > 0 ? 1.0 : 0.0
            }
        }
    }

    Timer {
        id: autoSaveTimer
        interval: 2000
        repeat: false
        onTriggered: {
            autoSaveToSession();
        }
    }

    Timer {
        id: pluginSyncTimer
        interval: 350
        repeat: false
        onTriggered: syncContentToPlugin()
    }

    Connections {
        target: SettingsData
        function onBuiltInPluginSettingsChanged() {
            if (PluginService.isPluginLoaded("dankNotepadModule")) {
                pluginHighlightedHtml = SettingsData.getBuiltInPluginSetting("dankNotepadModule", "highlightedHtml", "");
            }
        }
    }
}
