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
            showSwap: false,
            mediaSize: 1,
            showNetworkIcon: true,
            showBluetoothIcon: true,
            showAudioIcon: true,
            showAudioPercent: true,
            showVpnIcon: true,
            showBrightnessIcon: false,
            showBrightnessPercent: false,
            showMicIcon: false,
            showMicPercent: true,
            showBatteryIcon: false,
            showPrinterIcon: false
        };
        leftModel.append(dummy);
        centerModel.append(dummy);
        rightModel.append(dummy);

        update(leftModel, left);
        update(centerModel, center);
        update(rightModel, right);
    }

    function update(model, order) {
        model.clear();
        for (var i = 0; i < order.length; i++) {
            var isObj = typeof order[i] !== "string";
            var widgetId = isObj ? order[i].id : order[i];
            var item = {
                widgetId: widgetId,
                enabled: isObj ? order[i].enabled : true
            };
            if (isObj && order[i].size !== undefined)
                item.size = order[i].size;
            if (isObj && order[i].selectedGpuIndex !== undefined)
                item.selectedGpuIndex = order[i].selectedGpuIndex;
            if (isObj && order[i].pciId !== undefined)
                item.pciId = order[i].pciId;
            if (isObj && order[i].mountPath !== undefined)
                item.mountPath = order[i].mountPath;
            if (isObj && order[i].minimumWidth !== undefined)
                item.minimumWidth = order[i].minimumWidth;
            if (isObj && order[i].showSwap !== undefined)
                item.showSwap = order[i].showSwap;
            if (isObj && order[i].mediaSize !== undefined)
                item.mediaSize = order[i].mediaSize;
            if (isObj && order[i].showNetworkIcon !== undefined)
                item.showNetworkIcon = order[i].showNetworkIcon;
            if (isObj && order[i].showBluetoothIcon !== undefined)
                item.showBluetoothIcon = order[i].showBluetoothIcon;
            if (isObj && order[i].showAudioIcon !== undefined)
                item.showAudioIcon = order[i].showAudioIcon;
            if (isObj && order[i].showAudioPercent !== undefined)
                item.showAudioPercent = order[i].showAudioPercent;
            if (isObj && order[i].showVpnIcon !== undefined)
                item.showVpnIcon = order[i].showVpnIcon;
            if (isObj && order[i].showBrightnessIcon !== undefined)
                item.showBrightnessIcon = order[i].showBrightnessIcon;
            if (isObj && order[i].showBrightnessPercent !== undefined)
                item.showBrightnessPercent = order[i].showBrightnessPercent;
            if (isObj && order[i].showMicIcon !== undefined)
                item.showMicIcon = order[i].showMicIcon;
            if (isObj && order[i].showMicPercent !== undefined)
                item.showMicPercent = order[i].showMicPercent;
            if (isObj && order[i].showBatteryIcon !== undefined)
                item.showBatteryIcon = order[i].showBatteryIcon;
            if (isObj && order[i].showPrinterIcon !== undefined)
                item.showPrinterIcon = order[i].showPrinterIcon;

            model.append(item);
        }
    }
}
