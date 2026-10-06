import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Notepad
import qs.DCommon.Common as DC

ShellRoot {
    id: root

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        Proc.runCommand("", ["mkdir", "-p", NotepadStorageService.baseDir], (_, code) => {
            if (code !== 0) {
                console.error("FIXTURE_FAIL could not create notepad state directory");
                Qt.quit();
                return;
            }
            tester.run();
        }, 0);
    }

    Component {
        id: notepadComponent
        Notepad {
            width: 800
            height: 600
        }
    }

    FileView {
        id: file
        blockWrites: true
        blockLoading: true
        atomicWrites: true
    }

    TestCase {
        id: tester
        when: false

        function check(condition, message) {
            if (!condition)
                throw new Error(message);
        }

        function findEditor(item) {
            if (typeof item.commitLiveBuffer === "function")
                return item;
            for (const child of item.children ?? []) {
                const found = findEditor(child);
                if (found)
                    return found;
            }
            return null;
        }

        function drainSaves() {
            let settled = false;
            Qt.callLater(() => Qt.callLater(() => settled = true));
            tryVerify(() => settled, 20000);
        }

        function diskContent(path) {
            file.path = "";
            file.path = path;
            return file.text();
        }

        function run() {
            try {
                SettingsData.notepadAutoSave = false;
                const firstPath = NotepadStorageService.baseDir + "/first.txt";
                const secondPath = NotepadStorageService.baseDir + "/second.txt";
                const original = "original notes\n";
                const first = "1. first note\n2. second note\n";
                const second = first + "3. third note\n";
                file.path = firstPath;
                file.setText(original);
                file.path = NotepadStorageService.metadataPath;
                file.setText(JSON.stringify({
                    version: 1,
                    currentTabIndex: 0,
                    tabs: [
                        {
                            id: 1,
                            title: "first.txt",
                            filePath: firstPath,
                            isTemporary: false,
                            lastSavedContent: original
                        }
                    ]
                }));

                const notepad = notepadComponent.createObject(root);
                const editor = findEditor(notepad);
                check(editor !== null, "notepad editor is available");
                tryVerify(() => editor.contentLoaded && editor.text === original, 20000);
                editor.text = first;
                editor.saveRequested();
                editor.saveRequested();
                drainSaves();
                check(diskContent(firstPath) === first, "repeated Save preserves the notes on disk");
                check(editor.lastSavedContent === first, "repeated Save retains the editor baseline");
                check(NotepadStorageService.tabs[0].lastSavedContent === first, "repeated Save retains the tab baseline");
                check(!editor.hasUnsavedChanges(), "repeated Save leaves the editor saved");

                editor.text = second;
                notepad.saveToFile("file://" + firstPath);
                NotepadStorageService.saveTabAs(0, secondPath);
                editor.text = "different destination\n";
                notepad.saveToFile("file://" + secondPath);
                drainSaves();
                check(diskContent(firstPath) === second, "the first save keeps its content and destination");
                check(diskContent(secondPath) === editor.text, "the next save uses its own content and destination");
                check(editor.lastSavedContent === editor.text, "the editor baseline matches the last save");
                check(NotepadStorageService.tabs[0].lastSavedContent === editor.text, "the tab baseline matches the last save");
                console.log("FIXTURE_PASS notepad repeated saves preserve content, destinations and baselines");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
