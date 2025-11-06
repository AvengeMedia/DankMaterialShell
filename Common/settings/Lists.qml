pragma Singleton

pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

Singleton {
    id: root

    function init(leftModel, centerModel, rightModel, left, center, right) {
        const dummy = {
            widgetId: "dummy",
            enabled: true,
            size: 20,
            selectedGpuIndex: 0,
            pciId: "",
            mountPath: "/",
            minimumWidth: true,
            showSwap: false
        }
        leftModel.append(dummy)
        centerModel.append(dummy)
        rightModel.append(dummy)

        update(leftModel, left)
        update(centerModel, center)
        update(rightModel, right)
    }

    function update(model, order) {
        model.clear()
        for (var i = 0; i < order.length; i++) {
            var widgetId = typeof order[i] === "string" ? order[i] : order[i].id
            var enabled = typeof order[i] === "string" ? true : order[i].enabled
            var size = typeof order[i] === "string" ? undefined : order[i].size
            var selectedGpuIndex = typeof order[i] === "string" ? undefined : order[i].selectedGpuIndex
            var pciId = typeof order[i] === "string" ? undefined : order[i].pciId
            var mountPath = typeof order[i] === "string" ? undefined : order[i].mountPath
            var minimumWidth = typeof order[i] === "string" ? undefined : order[i].minimumWidth
            var showSwap = typeof order[i] === "string" ? undefined : order[i].showSwap
            var item = {
                widgetId: widgetId,
                enabled: enabled
            }
            if (size !== undefined) item.size = size
            if (selectedGpuIndex !== undefined) item.selectedGpuIndex = selectedGpuIndex
            if (pciId !== undefined) item.pciId = pciId
            if (mountPath !== undefined) item.mountPath = mountPath
            if (minimumWidth !== undefined) item.minimumWidth = minimumWidth
            if (showSwap !== undefined) item.showSwap = showSwap

            model.append(item)
        }
    }
}
