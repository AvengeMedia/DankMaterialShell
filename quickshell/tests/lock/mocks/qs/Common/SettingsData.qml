pragma Singleton
import QtQuick

QtObject {
    property bool enableFprint: true
    property bool enableU2f: false
    property string u2fMode: "and"
    property bool lockPamExternallyManaged: false
    property string lockPamPath: ""
    property string lockU2fPamPath: ""
    property bool lockPamInlineFprint: false
    property bool lockPamInlineU2f: false
    property bool lockFingerprintReady: true
    property bool lockU2fReady: true
    property int maxFprintTries: 2
}
