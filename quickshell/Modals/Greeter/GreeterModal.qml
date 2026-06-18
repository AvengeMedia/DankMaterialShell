import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root
    readonly property var log: Log.scoped("GreeterModal")

    property bool disablePopupTransparency: true
    property int currentPage: 0
    readonly property int totalPages: 3
    readonly property var pageComponents: [welcomePage, doctorPage, completePage]

    property var cheatsheetData: ({})
    property bool cheatsheetLoaded: false

    readonly property int modalWidth: 720
    readonly property int modalHeight: screen ? Math.min(760, screen.height - 80) : 760

    signal greeterCompleted

    Component.onCompleted: Qt.callLater(loadCheatsheet)

    function loadCheatsheet() {
        const provider = KeybindsService.cheatsheetProvider;
        if (KeybindsService.cheatsheetAvailable && provider && !cheatsheetLoaded) {
            cheatsheetProcess.command = ["dms", "keybinds", "show", provider];
            cheatsheetProcess.running = true;
        }
    }

    Connections {
        target: KeybindsService
        function onCheatsheetAvailableChanged() {
            if (KeybindsService.cheatsheetAvailable && !root.cheatsheetLoaded)
                loadCheatsheet();
        }
    }

    function getKeybind(actionPattern) {
        if (!cheatsheetLoaded || !cheatsheetData.binds)
            return "";
        for (const category in cheatsheetData.binds) {
            const binds = cheatsheetData.binds[category];
            for (let i = 0; i < binds.length; i++) {
                const bind = binds[i];
                if (bind.action && bind.action.includes(actionPattern))
                    return bind.key || "";
            }
        }
        return "";
    }

    function show() {
        currentPage = FirstLaunchService.requestedStartPage || 0;
        visible = true;
    }

    function showAtPage(page) {
        currentPage = page;
        visible = true;
    }

    function nextPage() {
        if (currentPage < totalPages - 1)
            currentPage++;
    }

    function prevPage() {
        if (currentPage > 0)
            currentPage--;
    }

    function finish() {
        FirstLaunchService.markFirstLaunchComplete();
        greeterCompleted();
        visible = false;
    }

    function skip() {
        FirstLaunchService.markFirstLaunchComplete();
        greeterCompleted();
        visible = false;
    }

    objectName: "greeterModal"
    title: I18n.tr("Welcome", "greeter modal window title")
    minimumSize: Qt.size(modalWidth, modalHeight)
    maximumSize: Qt.size(modalWidth, modalHeight)
    color: Theme.surfaceContainer
    visible: false

    Process {
        id: cheatsheetProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim();
                if (trimmed.length === 0)
                    return;
                try {
                    root.cheatsheetData = JSON.parse(trimmed);
                    root.cheatsheetLoaded = true;
                } catch (e) {
                    log.warn("Greeter: Failed to parse cheatsheet:", e);
                }
            }
        }
    }

    FocusScope {
        id: contentFocusScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            root.skip();
            event.accepted = true;
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (root.currentPage < root.totalPages - 1)
                    root.nextPage();
                else
                    root.finish();
                event.accepted = true;
                break;
            case Qt.Key_Left:
                if (root.currentPage > 0)
                    root.prevPage();
                event.accepted = true;
                break;
            case Qt.Key_Right:
                if (root.currentPage < root.totalPages - 1)
                    root.nextPage();
                event.accepted = true;
                break;
            }
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: headerRow.height + Theme.spacingM
            onPressed: windowControls.tryStartMove()
            onDoubleClicked: windowControls.tryToggleMaximize()
        }

        Item {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            height: Math.round(Theme.fontSizeMedium * 2.85)

            Rectangle {
                id: pageIndicatorContainer
                readonly property real indicatorHeight: Math.round(Theme.fontSizeMedium * 2)

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: pageIndicatorRow.width + Theme.spacingM * 2
                height: indicatorHeight
                radius: indicatorHeight / 2
                color: Theme.surfaceContainerHigh

                Row {
                    id: pageIndicatorRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.totalPages

                        Rectangle {
                            required property int index
                            property bool isActive: index === root.currentPage
                            readonly property real dotSize: Math.round(Theme.spacingS * 1.3)

                            width: isActive ? dotSize * 3 : dotSize
                            height: dotSize
                            radius: dotSize / 2
                            color: isActive ? Theme.primary : Theme.surfaceTextAlpha
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.emphasizedEasing
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                }
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                DankActionButton {
                    visible: windowControls.canMaximize
                    iconName: root.maximized ? "fullscreen_exit" : "fullscreen"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: windowControls.tryToggleMaximize()
                }

                DankActionButton {
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: root.skip()

                    DankTooltip {
                        text: I18n.tr("Skip setup", "greeter skip button tooltip")
                    }
                }
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerRow.bottom
            anchors.bottom: footerRow.top
            anchors.topMargin: Theme.spacingS

            Loader {
                id: pageLoader
                anchors.fill: parent
                sourceComponent: root.pageComponents[root.currentPage]

                property var greeterRoot: root
            }
        }

        Rectangle {
            id: footerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.round(Theme.fontSizeMedium * 4.5)
            color: Theme.surfaceContainerHigh

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Theme.outlineMedium
                opacity: 0.5
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankButton {
                    visible: root.currentPage < root.totalPages - 1
                    text: I18n.tr("Skip", "greeter skip button")
                    backgroundColor: "transparent"
                    textColor: Theme.surfaceVariantText
                    onClicked: root.skip()
                }

                DankButton {
                    visible: root.currentPage > 0
                    text: I18n.tr("Back", "greeter back button")
                    iconName: "arrow_back"
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    onClicked: root.prevPage()
                }

                DankButton {
                    visible: root.currentPage < root.totalPages - 1
                    enabled: !(root.currentPage === 1 && pageLoader.item && pageLoader.item.isRunning)
                    text: root.currentPage === 0 ? I18n.tr("Get Started", "greeter first page button") : I18n.tr("Next", "greeter next button")
                    iconName: "arrow_forward"
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: root.nextPage()
                }

                DankButton {
                    visible: root.currentPage === root.totalPages - 1
                    text: I18n.tr("Finish", "greeter finish button")
                    iconName: "check"
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: root.finish()
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }

    Component {
        id: welcomePage
        GreeterWelcomePage {}
    }

    Component {
        id: doctorPage
        GreeterDoctorPage {}
    }

    Component {
        id: completePage
        GreeterCompletePage {}
    }
}
