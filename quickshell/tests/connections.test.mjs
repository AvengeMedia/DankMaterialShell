import assert from "node:assert/strict";
import vm from "node:vm";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const ctx = loadScript(new URL("../Modules/ProcessList/Connections.js", import.meta.url));
const C = vm.runInContext("({splitRemote, kind, service, group, unitKind, unescapeUnit})", ctx);
const plain = v => JSON.parse(JSON.stringify(v));

test("splitRemote handles IPv4 and bracketed IPv6", () => {
    assert.deepEqual(plain(C.splitRemote("1.2.3.4:443")), { host: "1.2.3.4", port: 443 });
    assert.deepEqual(plain(C.splitRemote("[2a00:1450::200e]:443")), { host: "2a00:1450::200e", port: 443 });
});

test("kind tells Tailscale from other local remotes", () => {
    assert.equal(C.kind({ remote: "142.250.185.78:443" }), "internet");
    assert.equal(C.kind({ remote: "100.92.15.3:8096", local: true }), "tailscale");
    assert.equal(C.kind({ remote: "100.128.0.1:80", local: true }), "local");
    assert.equal(C.kind({ remote: "[fd7a:115c:a1e0::1]:22", local: true }), "tailscale");
    assert.equal(C.kind({ remote: "192.168.178.20:8123", local: true }), "local");
});

test("service names known ports and QUIC", () => {
    assert.equal(C.service(443, "tcp"), "HTTPS");
    assert.equal(C.service(443, "udp"), "QUIC");
    assert.equal(C.service(8096, "tcp"), "8096");
});

test("group merges repeats, names Tailscale peers and sorts busiest first", () => {
    const g = C.group([
        { remote: "1.1.1.1:443", protocol: "tcp" }, { remote: "2.2.2.2:443", protocol: "tcp" }, { remote: "2.2.2.2:443", protocol: "tcp" },
        { remote: "100.92.15.3:8096", protocol: "tcp", local: true }
    ], { "100.92.15.3": "jellyfin-nas" });
    assert.deepEqual(plain(g.internet.map(r => [r.host, r.count])), [["2.2.2.2", 2], ["1.1.1.1", 1]]);
    assert.equal(g.tailscale[0].name, "jellyfin-nas");
    assert.equal(g.local.length, 0);
});

test("unitKind separates services from app scopes and sessions", () => {
    assert.equal(C.unitKind("dms.service"), "service");
    assert.equal(C.unitKind("app-hyprland-zen-4791.scope"), "app");
    assert.equal(C.unitKind("app-firefox@1.service"), "app");
    assert.equal(C.unitKind("session-3.scope"), "session");
    assert.equal(C.unitKind("init.scope"), "other");
    assert.equal(C.unitKind(""), "");
});

test("unescapeUnit decodes systemd escapes", () => {
    assert.equal(C.unescapeUnit("app-proton\\x2dmail-25686.scope"), "app-proton-mail-25686.scope");
});
