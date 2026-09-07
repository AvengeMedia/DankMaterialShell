import qs.DankCommon.Common as DankCommon

DankCommon.DankSocket {
    function reconnect() {
        _teardown();
        if (connected)
            _scheduleReconnect();
    }
}
