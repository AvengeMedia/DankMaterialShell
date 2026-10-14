import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Services/AudioService.qml", import.meta.url), "utf8");
const binding = source.match(/readonly property string sinkVolumeIconName: (\{[\s\S]*?^    \})/m)?.[1];
if (!binding)
    throw new Error("sinkVolumeIconName binding not found in AudioService.qml");

function extract(name) {
    const found = source.match(new RegExp(`^    function ${name}\\([^)]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"));
    if (!found)
        throw new Error(`${name} not found in AudioService.qml`);
    return found[0];
}

test("connected Bluetooth headsets use headphones unless silent; other outputs retain their volume icon", () => {
    const headset = { connected: true, icon: "headset" };
    const devices = new Map([
        ["headset", headset],
        ["disconnected", { connected: false, icon: "headset" }],
        ["speaker", { connected: true, icon: "speaker" }]
    ]);
    const scope = vm.createContext({
        sink: null,
        BluetoothService: {
            deviceForNodeName: name => devices.get(name),
            getDeviceIcon: device => device.icon
        }
    });
    vm.runInContext(`${extract("isSilent")}\n${extract("volumeIconName")}\nfunction outputIcon() ${binding}`, scope);

    for (const [sink, expected] of [
        [{ name: "headset", audio: { volume: 0.7, muted: false } }, "headphones"],
        [{ name: "headset", audio: { volume: 0.7, muted: true } }, "volume_off"],
        [{ name: "headset", audio: { volume: 0, muted: false } }, "volume_mute"],
        [{ name: "disconnected", audio: { volume: 0.7, muted: false } }, "volume_up"],
        [{ name: "speaker", audio: { volume: 0.2, muted: false } }, "volume_down"],
        [{ name: "wired", audio: { volume: 0.7, muted: true } }, "volume_off"],
        [null, "volume_off"]
    ]) {
        scope.sink = sink;
        assert.equal(scope.outputIcon(), expected);
    }

    scope.sink = { name: "headset", audio: { volume: 0.7, muted: false } };
    headset.connected = false;
    assert.equal(scope.outputIcon(), "volume_up");
});
