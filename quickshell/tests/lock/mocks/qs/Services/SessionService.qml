pragma Singleton
import QtQuick

QtObject {
    property bool preparingForSleep: false
    signal sessionResumed
    signal lidOpened
}
