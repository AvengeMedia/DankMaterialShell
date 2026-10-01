import QtQuick

Item {
    property var command
    property bool running: false
    signal exited(int exitCode)
}
