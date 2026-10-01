pragma Singleton
import QtQuick

QtObject {
    property string state: "/test"
    function strip(value) {
        return value;
    }
}
