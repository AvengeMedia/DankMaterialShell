import QtQuick

Item {
    property bool active: false
    property string config
    property string configDirectory
    property string message
    property bool responseRequired: false
    property int starts: 0
    property bool startSucceeds: true
    property bool startFailsSynchronously: false
    signal completed(int res)
    function start() {
        if (active)
            return false;
        if (startFailsSynchronously) {
            completed(PamResult.Error);
            return false;
        }
        if (!startSucceeds)
            return false;
        starts++;
        active = true;
        return true;
    }
    function abort() {
        active = false;
    }
    function respond(value) {
    }
    function finish(result) {
        active = false;
        completed(result);
    }
}
