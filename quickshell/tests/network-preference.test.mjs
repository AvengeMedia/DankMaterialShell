import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Services/DMSNetworkService.qml", import.meta.url), "utf8");

function sliceFunction(name) {
    const match = source.match(new RegExp(`^    function ${name}\\([^\\n]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"));
    assert.ok(match, `${name} not found`);
    return match[0];
}

// Unknown service properties read as undefined and assignments land in `store`.
function service(preference) {
    const requests = [];
    const settings = { networkPreference: preference };
    const store = {
        DMSService: { apiVersion: 99, sendRequest: (method, params, cb) => requests.push({ method, params, cb }) },
        SettingsData: { get networkPreference() { return settings.networkPreference; }, set: (key, value) => { settings[key] = value; } },
        ToastService: { showInfo() {}, showError() {} },
        I18n: { tr: text => ({ arg: () => text }) },
        log: { info() {}, warn() {} },
        connectionChanged() {},
        networkAvailable: true,
        get userPreference() { return settings.networkPreference; }
    };
    const scope = new Proxy(store, {
        has: (_, key) => typeof key === "string" && key !== "__scope",
        get: (target, key) => key in target ? target[key] : globalThis[key],
        set: (target, key, value) => { target[key] = value; return true; }
    });
    const context = vm.createContext({ __scope: scope });
    for (const name of ["keepUnchanged", "updateState", "setNetworkPreference", "applyNetworkPreference"])
        vm.runInContext(`with (__scope) { __scope.${name} = (${sliceFunction(name)}); }`, context);
    return { svc: store, requests, settings };
}

const connected = { wifiConnected: true, wifiSSID: "home", wifiIP: "10.0.0.2" };

test("a successful Wi-Fi connect re-applies a Wi-Fi preference", () => {
    const { svc, requests } = service("wifi");
    svc.pendingConnectionSSID = "home";
    svc.updateState(connected);
    assert.equal(JSON.stringify(requests.map(r => [r.method, r.params])), JSON.stringify([["network.preference.set", { preference: "wifi" }]]));
    assert.equal(svc.connectionStatus, "connected");
});

test("a successful Wi-Fi connect leaves other preferences alone", () => {
    for (const pref of ["auto", "ethernet", "cellular"]) {
        const { svc, requests } = service(pref);
        svc.pendingConnectionSSID = "home";
        svc.updateState(connected);
        assert.equal(requests.length, 0, pref);
    }
});

test("a failed re-apply keeps the stored preference", () => {
    const { svc, requests, settings } = service("wifi");
    svc.pendingConnectionSSID = "home";
    svc.updateState(connected);
    requests[0].cb({ error: "denied" });
    assert.equal(settings.networkPreference, "wifi");
    assert.equal(svc.changingPreference, false);
});

test("a failed preference change from settings rolls back", () => {
    const { svc, requests, settings } = service("auto");
    svc.setNetworkPreference("ethernet");
    assert.equal(settings.networkPreference, "ethernet");
    requests[0].cb({ error: "denied" });
    assert.equal(settings.networkPreference, "auto");
});
