import QtQuick

Item {
    id: root

    required property var targetWindow
    property bool supported: typeof targetWindow.startSystemMove === "function"

    anchors.fill: parent

    function tryStartMove() {
        if (!supported)
            return;
        targetWindow.startSystemMove();
    }

    function tryStartResize(edges) {
        if (!supported)
            return;
        targetWindow.startSystemResize(edges);
    }

    function tryToggleMaximize() {
        if (!supported)
            return;
        targetWindow.maximized = !targetWindow.maximized;
    }

    MouseArea {
        visible: root.supported
        height: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        cursorShape: Qt.SizeVerCursor
        onPressed: root.tryStartResize(Qt.TopEdge)
    }

    MouseArea {
        visible: root.supported
        width: 6
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        cursorShape: Qt.SizeHorCursor
        onPressed: root.tryStartResize(Qt.LeftEdge)
    }

    MouseArea {
        visible: root.supported
        width: 6
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        cursorShape: Qt.SizeHorCursor
        onPressed: root.tryStartResize(Qt.RightEdge)
    }

    MouseArea {
        visible: root.supported
        width: 6
        height: 6
        anchors.left: parent.left
        anchors.top: parent.top
        cursorShape: Qt.SizeFDiagCursor
        onPressed: root.tryStartResize(Qt.LeftEdge | Qt.TopEdge)
    }

    MouseArea {
        visible: root.supported
        width: 6
        height: 6
        anchors.right: parent.right
        anchors.top: parent.top
        cursorShape: Qt.SizeBDiagCursor
        onPressed: root.tryStartResize(Qt.RightEdge | Qt.TopEdge)
    }

    MouseArea {
        visible: root.supported
        height: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        cursorShape: Qt.SizeVerCursor
        onPressed: root.tryStartResize(Qt.BottomEdge)
    }

    MouseArea {
        visible: root.supported
        width: 6
        height: 6
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        cursorShape: Qt.SizeBDiagCursor
        onPressed: root.tryStartResize(Qt.LeftEdge | Qt.BottomEdge)
    }

    MouseArea {
        visible: root.supported
        width: 6
        height: 6
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        cursorShape: Qt.SizeFDiagCursor
        onPressed: root.tryStartResize(Qt.RightEdge | Qt.BottomEdge)
    }
}
