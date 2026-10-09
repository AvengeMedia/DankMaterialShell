import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const context = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/ConnectionEditor.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), context);
const plain = value => value === undefined ? undefined : JSON.parse(JSON.stringify(value));
const ce = new Proxy(context, {
    get: (target, name) => typeof target[name] === "function" ? (...args) => plain(target[name](...args)) : plain(target[name])
});

const base = () => ({
    connection: { id: "Home", type: "802-3-ethernet", autoconnect: true },
    ipv4: { method: "manual", "address-data": [{ address: "192.0.2.10", prefix: 24 }], "dns-data": ["1.1.1.1", "9.9.9.9"] },
    ipv6: { method: "auto" }
});

test("settingsDiff sends only what changed, null for removals, whole new sections", () => {
    assert.equal(ce.settingsDiff(base(), base()), null);

    const changed = base();
    changed.connection.id = "Office";
    assert.deepEqual(ce.settingsDiff(base(), changed), { connection: { id: "Office" } });

    const keyRemoved = base();
    delete keyRemoved.ipv4["dns-data"];
    assert.deepEqual(ce.settingsDiff(base(), keyRemoved), { ipv4: { "dns-data": null } });

    const sectionRemoved = base();
    delete sectionRemoved.ipv6;
    assert.deepEqual(ce.settingsDiff(base(), sectionRemoved), { ipv6: null });

    const sectionAdded = base();
    sectionAdded["802-1x"] = { eap: ["peap"], identity: "u" };
    assert.deepEqual(ce.settingsDiff(base(), sectionAdded), { "802-1x": { eap: ["peap"], identity: "u" } });

    const reordered = base();
    reordered.ipv4["dns-data"] = ["9.9.9.9", "1.1.1.1"];
    assert.deepEqual(ce.settingsDiff(base(), reordered), { ipv4: { "dns-data": ["9.9.9.9", "1.1.1.1"] } });

    const reverted = base();
    reverted.ipv4["address-data"] = [{ address: "10.0.0.1", prefix: 8 }];
    reverted.ipv4["address-data"] = [{ prefix: 24, address: "192.0.2.10" }];
    reverted.connection.autoconnect = undefined;
    reverted.connection.autoconnect = true;
    assert.equal(ce.settingsDiff(base(), reverted), null);

    const nulled = base();
    nulled.ipv6 = null;
    nulled.connection.zone = null;
    assert.deepEqual(ce.settingsDiff(base(), nulled), { ipv6: null });
});

test("IP and CIDR validation covers compressed IPv6 and rejects malformed forms", () => {
    for (const ok of ["::", "fe80::1", "2001:db8::", "::ffff:192.0.2.1", "1:2:3:4:5:6:7:8"])
        assert.equal(ce.isValidIp(ok, 6), true, ok);
    for (const bad of [":::", "1::2::3", "1:2:3:4:5:6:7:8:9", "1:2:3:4:5:6:7", "12345::", "g::1", ""])
        assert.equal(ce.isValidIp(bad, 6), false, bad);
    assert.equal(ce.isValidIp("192.0.2.1", 4), true);
    for (const bad of ["256.0.0.1", "1.2.3", "1.2.3.4.5", "a.b.c.d", "fe80::1", "192.168.01.1", "00.0.0.0"])
        assert.equal(ce.isValidIp(bad, 4), false, bad);
    assert.equal(ce.isValidCidr("2001:db8::/32", 6), true);
    assert.equal(ce.isValidCidr("2001:db8::/129", 6), false);
    assert.equal(ce.isValidCidr("10.0.0.0/33", 4), false);
    assert.equal(ce.isValidCidr("10.0.0.0", 4), false);
    assert.equal(ce.isValidCidr("10.0.0.0/024", 4), false);
    assert.equal(ce.isValidCidr("10.0.0.0/0", 4), true);
});

test("addresses round-trip text and keep extra keys of existing entries", () => {
    const data = ce.addressDataFromText("192.0.2.10/24, 10.0.0.2/8", 4, []);
    assert.deepEqual(data, [{ address: "192.0.2.10", prefix: 24 }, { address: "10.0.0.2", prefix: 8 }]);
    assert.equal(ce.addressText(data), "192.0.2.10/24, 10.0.0.2/8");
    assert.equal(ce.addressDataFromText("192.0.2.10/33", 4, []), null);
    assert.equal(ce.addressDataFromText("192.0.2.10/24 nonsense", 4, []), null);
    assert.deepEqual(ce.addressDataFromText("192.0.2.10/25\n10.0.0.2/8", 4, [{ address: "192.0.2.10", prefix: 24, label: "eth0:1" }]),
        [{ address: "192.0.2.10", prefix: 25, label: "eth0:1" }, { address: "10.0.0.2", prefix: 8 }]);
    assert.deepEqual(ce.addressDataFromText("fe80::5", 6, []), [{ address: "fe80::5", prefix: 128 }]);
    assert.deepEqual(ce.addressDataFromText("  ", 4, []), []);
});

test("DNS servers and search domains parse from text", () => {
    assert.deepEqual(ce.serverListFromText("1.1.1.1, 9.9.9.9", 4), ["1.1.1.1", "9.9.9.9"]);
    assert.equal(ce.serverListFromText("1.1.1.1, 300.1.1.1", 4), null);
    assert.deepEqual(ce.serverListFromText("dns+tls://1.1.1.1#one.one.one.one dns+udp://9.9.9.9:53 1.1.1.1#cloudflare-dns.com", 4),
        ["dns+tls://1.1.1.1#one.one.one.one", "dns+udp://9.9.9.9:53", "1.1.1.1#cloudflare-dns.com"]);
    for (const bad of ["9.9.9.9:53", "dns+tls://1.1.1.1:65536", "dns+udp://1.1.1.1:0", "[2620:fe::fe]:853", "dns+tls://2620:fe::fe"])
        assert.equal(ce.serverListFromText(bad, bad.indexOf("[") >= 0 || bad.indexOf("fe::") >= 0 ? 6 : 4), null, bad);
    assert.deepEqual(ce.serverListFromText("2606:4700::1111 dns+tls://[2620:fe::fe]:853 fe80::1%eth0", 6), ["2606:4700::1111", "dns+tls://[2620:fe::fe]:853", "fe80::1%eth0"]);
    assert.equal(ce.serverListFromText("1.1.1.1", 6), null);
    assert.equal(ce.listText(["a", "b"]), "a, b");
    assert.deepEqual(ce.domainListFromText("example.com, ~."), ["example.com", "~."]);
});

test("routes keep extra attributes, omit empty next hop and metric, validate per family", () => {
    const data = [{ dest: "10.0.0.0", prefix: 8, "next-hop": "192.0.2.1", metric: 50, onlink: true }];
    const rows = ce.routeRows(data);
    assert.deepEqual(rows, [{ dest: "10.0.0.0/8", nextHop: "192.0.2.1", metric: "50", extra: { onlink: true } }]);
    assert.deepEqual(ce.routeDataFromRows(rows, 4), data);

    rows[0].metric = "";
    rows[0].nextHop = " ";
    assert.deepEqual(ce.routeDataFromRows(rows, 4), [{ dest: "10.0.0.0", prefix: 8, onlink: true }]);

    assert.equal(ce.routeDataFromRows([{ dest: "10.0.0.0/8", nextHop: "", metric: "x", extra: {} }], 4), null);
    assert.equal(ce.routeDataFromRows([{ dest: "", nextHop: "", metric: "", extra: {} }], 4), null);
    assert.equal(ce.routeDataFromRows([{ dest: "2001:db8::/32", nextHop: "", metric: "", extra: {} }], 4), null);
    assert.deepEqual(ce.routeDataFromRows([{ dest: "2001:db8::/32", nextHop: "fe80::1", metric: "", extra: {} }], 6),
        [{ dest: "2001:db8::", prefix: 32, "next-hop": "fe80::1" }]);
    assert.equal(ce.routeDataFromRows([{ dest: "2001:db8::/32", nextHop: "192.0.2.1", metric: "", extra: {} }], 6), null);
    assert.equal(ce.routeRows([{ dest: "10.0.0.0" }])[0].dest, "10.0.0.0");
});

test("IP methods per family", () => {
    assert.deepEqual(ce.ipMethods(4), ["auto", "manual", "link-local", "shared", "disabled"]);
    assert.deepEqual(ce.ipMethods(6), ["auto", "dhcp", "manual", "link-local", "shared", "ignore", "disabled"]);
});

// Matches `nmcli --offline connection add` on NetworkManager 1.58: every other key is accepted with every method.
test("keys each IP method rejects", () => {
    const off = ["address-data", "gateway", "dns-data", "dns-search"];
    const dns = ["dns-data", "dns-search"];
    const expected = {
        4: { auto: [], manual: [], "link-local": off, shared: dns, disabled: off },
        6: { auto: [], dhcp: [], manual: [], "link-local": off, shared: [], ignore: off, disabled: off }
    };
    for (const family of [4, 6]) {
        assert.deepEqual(Object.keys(expected[family]).sort(), ce.ipMethods(family).slice().sort());
        for (const method of ce.ipMethods(family))
            assert.deepEqual(ce.disallowedIpKeys(family, method).sort(), expected[family][method].slice().sort(), `ipv${family} ${method}`);
    }
});

test("changing the IP method drops rejected keys and brings stored ones back", () => {
    const stored = { method: "manual", "address-data": [{ address: "192.0.2.10", prefix: 24 }], gateway: "192.0.2.1", "dns-data": ["1.1.1.1"], "dns-search": ["lan"], "route-metric": 50 };

    const linkLocal = ce.applyIpMethod(stored, 4, "link-local", stored);
    assert.deepEqual(linkLocal, { method: "link-local", "route-metric": 50 });
    assert.deepEqual(ce.applyIpMethod(linkLocal, 4, "manual", stored), stored);

    assert.deepEqual(ce.applyIpMethod(stored, 4, "shared", stored), { method: "shared", "address-data": stored["address-data"], gateway: "192.0.2.1", "route-metric": 50 });
    assert.deepEqual(ce.applyIpMethod(stored, 6, "shared", stored), { ...stored, method: "shared" });

    // A key the user cleared stays cleared when the old method allowed it.
    const cleared = { ...stored };
    delete cleared["dns-data"];
    assert.equal(ce.applyIpMethod(cleared, 4, "auto", stored)["dns-data"], undefined);

    // NetworkManager refuses a gateway without an address under any method.
    const noAddress = { method: "manual", gateway: "192.0.2.1" };
    assert.deepEqual(ce.applyIpMethod(noAddress, 4, "auto", undefined), { method: "auto" });
    assert.deepEqual(ce.applyIpMethod({ ...noAddress, "address-data": [] }, 4, "auto", undefined), { method: "auto", "address-data": [] });

    assert.deepEqual(stored.method, "manual");
});

test("cloned MAC modes write assigned-mac-address and always drop the legacy key", () => {
    assert.equal(ce.isValidMac("aa:BB:cc:00:11:22"), true);
    assert.equal(ce.isValidMac("aa:bb:cc:00:11"), false);
    assert.equal(ce.clonedMacMode({}), "default");
    assert.equal(ce.clonedMacMode({ "assigned-mac-address": "stable" }), "stable");
    assert.equal(ce.clonedMacMode({ "assigned-mac-address": "AA:BB:CC:00:11:22" }), "manual");
    assert.equal(ce.clonedMacMode({ "cloned-mac-address": "AA:BB:CC:00:11:22" }), "manual");
    assert.equal(ce.clonedMacMode({ "assigned-mac-address": "stable-ssid" }), "stable-ssid");
    assert.equal(ce.clonedMacAddress({ "cloned-mac-address": "AA:BB:CC:00:11:22" }), "AA:BB:CC:00:11:22");
    assert.equal(ce.clonedMacAddress({ "assigned-mac-address": "random", "cloned-mac-address": "AA:BB:CC:00:11:22" }), "");

    const legacy = { mtu: 1500, "cloned-mac-address": "AA:BB:CC:00:11:22" };
    assert.deepEqual(ce.applyClonedMac(legacy, "random", ""), { mtu: 1500, "assigned-mac-address": "random" });
    assert.deepEqual(ce.applyClonedMac({ ...legacy, "assigned-mac-address": "stable" }, "default", ""), { mtu: 1500 });
    assert.deepEqual(ce.applyClonedMac(legacy, "manual", "02:00:00:00:00:01"), { mtu: 1500, "assigned-mac-address": "02:00:00:00:00:01" });
    assert.deepEqual(ce.applyClonedMac({}, "stable-ssid", ""), { "assigned-mac-address": "stable-ssid" });
    assert.deepEqual(legacy, { mtu: 1500, "cloned-mac-address": "AA:BB:CC:00:11:22" });
});

test("link negotiation and wake-on-LAN mappings", () => {
    const auto = ce.applyLinkNegotiation({ mtu: 9000, speed: 100, duplex: "half" }, "auto");
    assert.deepEqual(auto, { mtu: 9000, "auto-negotiate": true });
    assert.equal(ce.linkNegotiation(auto), "auto");
    const manual = ce.applyLinkNegotiation({}, "manual", 1000, "full");
    assert.deepEqual(manual, { "auto-negotiate": false, speed: 1000, duplex: "full" });
    assert.equal(ce.linkNegotiation(manual), "manual");
    const ignore = ce.applyLinkNegotiation(manual, "ignore");
    assert.deepEqual(ignore, { "auto-negotiate": false });
    assert.equal(ce.linkNegotiation(ignore), "ignore");
    assert.equal(ce.linkNegotiation({}), "ignore");

    assert.equal(ce.wolMode(undefined), "default");
    assert.equal(ce.wolMode(1), "default");
    assert.equal(ce.wolMode(0), "disabled");
    assert.equal(ce.wolMode(0x40), "magic");
    assert.equal(ce.wolMode(0x8000), "ignore");
    assert.equal(ce.wolMode(0x44), "0x44");
    assert.equal(ce.wolValue("default"), undefined);
    assert.deepEqual(["disabled", "magic", "ignore", "0x44"].map(m => ce.wolValue(m)), [0, 0x40, 0x8000, 0x44]);
});

test("security modes and transitions", () => {
    const wifi = { connection: { id: "x" }, "802-11-wireless": { ssid: "x" } };
    assert.equal(ce.securityMode(wifi), "none");
    assert.equal(ce.securityMode({ ...wifi, "802-11-wireless-security": { "key-mgmt": "sae" } }), "sae");
    assert.equal(ce.securityMode({ ...wifi, "802-11-wireless-security": { "key-mgmt": "wpa-eap-suite-b-192" } }), "wpa-eap-suite-b-192");
    assert.equal(ce.securityMode({ ...wifi, "802-11-wireless-security": { "key-mgmt": "none" } }), "wep");
    assert.equal(ce.securityMode({ ...wifi, "802-11-wireless-security": {} }), "none");

    const eap = { ...wifi, "802-1x": { eap: ["peap"] }, "802-11-wireless-security": { "key-mgmt": "wpa-eap" } };
    const sae = ce.applySecurityMode(eap, "sae", "correct horse");
    assert.deepEqual(sae["802-11-wireless-security"], { "key-mgmt": "sae", psk: "correct horse", "psk-flags": 0, pmf: 3 });
    assert.equal(sae["802-1x"], undefined);
    assert.equal(ce.settingsDiff(eap, sae)["802-1x"], null);

    const psk = ce.applySecurityMode(sae, "wpa-psk", "");
    assert.deepEqual(psk["802-11-wireless-security"], { "key-mgmt": "wpa-psk", psk: "correct horse", "psk-flags": 0 });

    const toEap = ce.applySecurityMode(psk, "wpa-eap");
    assert.deepEqual(toEap["802-11-wireless-security"], { "key-mgmt": "wpa-eap" });

    const owe = ce.applySecurityMode(psk, "owe");
    assert.deepEqual(owe["802-11-wireless-security"], { "key-mgmt": "owe" });

    const open = ce.applySecurityMode(eap, "none");
    assert.equal(open["802-11-wireless-security"], undefined);
    assert.equal(open["802-1x"], undefined);
    assert.deepEqual(eap["802-11-wireless-security"], { "key-mgmt": "wpa-eap" });

    assert.equal(ce.isValidPsk("1234567"), false);
    assert.equal(ce.isValidPsk("12345678"), true);
    assert.equal(ce.isValidPsk("a".repeat(64)), true);
    assert.equal(ce.isValidPsk("g".repeat(64)), false);
    assert.equal(ce.isValidPsk("pässwörd1"), false);
    assert.equal(ce.isValidPsk("tab\tinside"), false);
});

test("returning to Enterprise restores the stored 802-1x section instead of deleting it", () => {
    const eap = { connection: { id: "x" }, "802-11-wireless": { ssid: "x" }, "802-1x": { eap: ["peap"], identity: "u" }, "802-11-wireless-security": { "key-mgmt": "wpa-eap" } };
    const back = ce.applySecurityMode(ce.applySecurityMode(eap, "wpa-psk", "x"), "wpa-eap", undefined, eap);
    assert.equal("802-1x" in (ce.settingsDiff(eap, back) || {}), false);
    assert.deepEqual(back["802-1x"], eap["802-1x"]);
    const kept = ce.applySecurityMode(eap, "wpa-eap");
    assert.deepEqual(kept["802-1x"], eap["802-1x"]);
});

test("wpa-eap without original leaves a draft lacking 802-1x without one", () => {
    const psk = { "802-11-wireless-security": { "key-mgmt": "wpa-psk", psk: "password1" } };
    const out = ce.applySecurityMode(psk, "wpa-eap");
    assert.equal("802-1x" in out, false);
    assert.equal(out["802-11-wireless-security"]["key-mgmt"], "wpa-eap");
});

test("leaving WEP drops the WEP keys and auth-alg", () => {
    const wep = { "802-11-wireless-security": { "key-mgmt": "none", "wep-key0": "abcde", "wep-key1": "x", "wep-key2": "y", "wep-key3": "z",
        "wep-key-flags": 0, "wep-key-type": 1, "wep-tx-keyidx": 0, "auth-alg": "shared" } };
    assert.deepEqual(ce.applySecurityMode(wep, "wpa-psk", "password1")["802-11-wireless-security"], { "key-mgmt": "wpa-psk", psk: "password1", "psk-flags": 0 });
    const sae = { "802-11-wireless-security": { "key-mgmt": "sae", "auth-alg": "open", pmf: 3 } };
    assert.deepEqual(ce.applySecurityMode(sae, "owe")["802-11-wireless-security"], { "key-mgmt": "owe" });
});

test("registry: sections, groups and new-profile defaults", () => {
    assert.deepEqual(ce.sectionsFor("802-3-ethernet", {}), ["general", "ipv4", "ipv6", "ethernet", "security"]);
    assert.deepEqual(ce.sectionsFor("802-11-wireless", {}), ["general", "ipv4", "ipv6", "wifi", "security"]);
    assert.deepEqual(ce.sectionsFor("vpn", { connection: {}, ipv4: { method: "auto" } }), ["general", "vpnData", "ipv4"]);
    assert.deepEqual(ce.sectionsFor("tun", {}), ["general"]);
    assert.deepEqual(["802-3-ethernet", "802-11-wireless", "vpn", "wireguard", "gsm", "cdma", "bond"].map(t => ce.groupOf(t)),
        ["ethernet", "wifi", "vpn", "vpn", "cellular", "cellular", "other"]);
    assert.ok(ce.CONNECTION_TYPES.every(t => t.type && t.group && t.icon && typeof t.addable === "boolean"));

    const wifi = ce.newConnectionSettings("802-11-wireless", { name: "x" });
    assert.deepEqual(wifi, {
        connection: { id: "x", type: "802-11-wireless", autoconnect: true },
        ipv4: { method: "auto" },
        ipv6: { method: "auto" },
        "802-11-wireless": { ssid: "", mode: "infrastructure" }
    });
    const eth = ce.newConnectionSettings("802-3-ethernet", { name: "Wired" });
    assert.deepEqual(eth["802-3-ethernet"], {});
    assert.equal(eth["802-11-wireless-security"], undefined);
});

test("registry rows and new-profile autoconnect for VLAN, bond, bridge, mobile, DSL and Bluetooth", () => {
    const rows = [
        ["vlan", "other", "lan", true, ["general", "vlan", "ipv4", "ipv6"]],
        ["bond", "other", "link", true, ["general", "bond", "ports", "ipv4", "ipv6"]],
        ["bridge", "other", "device_hub", true, ["general", "bridge", "ports", "ipv4", "ipv6"]],
        ["pppoe", "other", "router", true, ["general", "pppoe", "ethernet", "ppp", "ipv4", "ipv6"]],
        ["gsm", "cellular", "signal_cellular_alt", true, ["general", "mobile", "ppp", "ipv4", "ipv6"]],
        ["cdma", "cellular", "signal_cellular_alt", false, ["general", "mobile", "ppp", "ipv4", "ipv6"]],
        ["bluetooth", "other", "bluetooth", false, ["general", "bluetooth", "ipv4", "ipv6"]]
    ];
    for (const [type, group, icon, addable, sections] of rows) {
        const info = ce.typeInfo(type);
        assert.deepEqual([info.group, info.icon, info.addable], [group, icon, addable], type);
        assert.equal(ce.groupOf(type), group, type);
        assert.deepEqual(ce.sectionsFor(type, { ipv4: {}, ipv6: {} }), sections, type);
    }
    for (const type of ["wireguard", "vpn", "vlan", "bond", "bridge", "pppoe", "gsm"])
        assert.equal(ce.newConnectionSettings(type, { name: "x" }).connection.autoconnect, false, type);
    for (const type of ["802-3-ethernet", "802-11-wireless"])
        assert.equal(ce.newConnectionSettings(type, { name: "x" }).connection.autoconnect, true, type);
});

test("groupProfiles orders groups and puts active profiles first", () => {
    const profiles = [
        { id: "a-vpn", type: "wireguard", active: false },
        { id: "b-eth", type: "802-3-ethernet", active: false },
        { id: "c-eth", type: "802-3-ethernet", active: true },
        { id: "d-eth", type: "802-3-ethernet", active: false },
        { id: "e-wifi", type: "802-11-wireless", active: false },
        { id: "f-lo", type: "loopback", active: true }
    ];
    assert.deepEqual(ce.groupProfiles(profiles).map(g => [g.group, g.profiles.map(p => p.id)]), [
        ["ethernet", ["c-eth", "b-eth", "d-eth"]],
        ["wifi", ["e-wifi"]],
        ["vpn", ["a-vpn"]],
        ["other", ["f-lo"]]
    ]);
});

test("lastUsed buckets by local calendar day", () => {
    const sec = (...parts) => new Date(...parts).getTime() / 1000;
    const now = sec(2026, 9, 3, 0, 0, 30);
    assert.equal(ce.lastUsed(0, now), "never");
    assert.equal(ce.lastUsed(sec(2026, 9, 3, 0, 0, 1), now), "today");
    assert.equal(ce.lastUsed(sec(2026, 9, 2, 23, 59, 59), now), "yesterday");
    assert.equal(ce.lastUsed(sec(2026, 9, 2, 0, 0, 1), now), "yesterday");
    assert.equal(ce.lastUsed(sec(2026, 9, 1, 23, 59, 59), now), "date");
    assert.equal(ce.lastUsed(sec(2026, 0, 1, 12), sec(2026, 0, 2, 9)), "yesterday");
    assert.equal(ce.lastUsed(sec(2025, 11, 31, 12), sec(2026, 0, 1, 9)), "yesterday");
});

const KEY_A = "yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=";
const KEY_B = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";

test("WireGuard peers round-trip through rows and keep unknown keys", () => {
    const peers = [
        { "public-key": KEY_A, endpoint: "vpn.example.com:51820", "allowed-ips": ["0.0.0.0/0", "::/0"], "preshared-key": KEY_B, "preshared-key-flags": 0, "persistent-keepalive": 25, foo: "bar" },
        { "public-key": KEY_B, "allowed-ips": ["10.0.0.0/24"] }
    ];
    const rows = ce.wgPeerRows(peers);
    assert.deepEqual(rows[0], { publicKey: KEY_A, allowedIps: "0.0.0.0/0, ::/0", endpoint: "vpn.example.com:51820", presharedKey: KEY_B, keepalive: "25",
        extra: { "preshared-key-flags": 0, foo: "bar" } });
    assert.deepEqual(ce.wgPeersFromRows(rows), peers);

    const cleared = ce.wgPeerRows(peers);
    cleared[0].presharedKey = "";
    cleared[0].keepalive = "0";
    assert.deepEqual(ce.wgPeersFromRows(cleared)[0], { "public-key": KEY_A, endpoint: "vpn.example.com:51820", "allowed-ips": ["0.0.0.0/0", "::/0"], foo: "bar" });
    // Clearing a PSK the loaded peer had sends a null so the backend deletes it.
    assert.deepEqual(ce.wgPeersFromRows(cleared, peers)[0], { "public-key": KEY_A, endpoint: "vpn.example.com:51820", "allowed-ips": ["0.0.0.0/0", "::/0"], foo: "bar", "preshared-key": null });
    assert.equal("preshared-key" in ce.wgPeersFromRows(ce.wgPeerRows(peers), peers)[1], false);
    const rekeyed = ce.wgPeerRows(peers);
    rekeyed[0].presharedKey = "";
    rekeyed[0].publicKey = KEY_B;
    assert.equal("preshared-key" in ce.wgPeersFromRows(rekeyed, peers)[0], false);
    const agentOwned = [{ "public-key": KEY_A, "preshared-key": KEY_B, "preshared-key-flags": 1 }];
    const agentCleared = ce.wgPeerRows(agentOwned);
    agentCleared[0].presharedKey = "";
    assert.deepEqual(ce.wgPeersFromRows(agentCleared, agentOwned)[0], { "public-key": KEY_A, "preshared-key-flags": 1 });

    const agent = [{ "public-key": KEY_A, "allowed-ips": ["10.0.0.0/24"], "preshared-key-flags": 2 }];
    assert.deepEqual(ce.wgPeersFromRows(ce.wgPeerRows(agent)), agent);

    const added = ce.wgPeerRows(peers);
    added[1].presharedKey = KEY_A;
    assert.deepEqual(ce.wgPeersFromRows(added)[1], { "public-key": KEY_B, "allowed-ips": ["10.0.0.0/24"], "preshared-key": KEY_A, "preshared-key-flags": 0 });

    const invalid = (field, value) => {
        const r = ce.wgPeerRows(peers);
        r[1][field] = value;
        return ce.wgPeersFromRows(r);
    };
    assert.equal(invalid("publicKey", "not-a-key"), null);
    assert.equal(invalid("publicKey", ""), null);
    assert.equal(invalid("allowedIps", "10.0.0.0/33"), null);
    assert.equal(invalid("endpoint", "host"), null);
    assert.equal(invalid("keepalive", "65536"), null);
    assert.equal(invalid("presharedKey", "short"), null);
    assert.deepEqual(invalid("endpoint", "[2001:db8::1]:51820")[1].endpoint, "[2001:db8::1]:51820");
    assert.deepEqual(invalid("allowedIps", "")[1], { "public-key": KEY_B });
});

test("WireGuard key, endpoint and interface name validation", () => {
    assert.equal(ce.isValidWgKey(KEY_A), true);
    assert.equal(ce.isValidWgKey(KEY_A.slice(1)), false);
    assert.equal(ce.isValidWgKey("AAAA" + KEY_A), false);
    assert.equal(ce.isValidEndpoint("192.0.2.1:51820"), true);
    assert.equal(ce.isValidEndpoint("[2001:db8::1]:1"), true);
    assert.equal(ce.isValidEndpoint("2001:db8::1:51820"), false);
    assert.equal(ce.isValidEndpoint("[nope]:51820"), false);
    assert.equal(ce.isValidEndpoint("host:0"), false);
    assert.equal(ce.isValidEndpoint("host:65536"), false);
    assert.equal(ce.isValidIfname("wg0"), true);
    assert.equal(ce.isValidIfname("protonvpn-DE-52"), true);
    assert.equal(ce.isValidIfname("protonvpn-DE-523"), false);
    assert.equal(ce.isValidIfname("wg\u00e4\u00e4\u00e4\u00e4\u00e4\u00e4\u00e4"), false);
    for (const bad of ["", ".", "..", "wg 0", "wg/0", "wg:0"])
        assert.equal(ce.isValidIfname(bad), false, bad);
});

test("bare vpn type omits an empty service-type", () => {
    assert.equal("service-type" in ce.newConnectionSettings("vpn", { name: "x" }).vpn, false);
});

test("kvFromRows keeps owned base entries and rejects bad keys", () => {
    const owned = ["remote"];
    const base = { remote: "a", foo: "1" };
    assert.deepEqual(ce.kvRows(base, owned), [{ key: "foo", value: "1" }]);
    assert.deepEqual(ce.kvFromRows([{ key: "foo", value: "2" }, { key: "bar", value: "3" }], base, owned), { remote: "a", foo: "2", bar: "3" });
    assert.deepEqual(ce.kvFromRows([], base, owned), { remote: "a" });
    assert.equal(ce.kvFromRows([{ key: "foo", value: "2" }, { key: "foo", value: "3" }], base, owned), null);
    assert.deepEqual(ce.kvFromRows([{ key: "toString", value: "1" }], base, owned).toString, "1");
    assert.equal(ce.kvFromRows([{ key: " ", value: "2" }], base, owned), null);
    assert.equal(ce.kvFromRows([{ key: "remote", value: "b" }], base, owned), null);
});

test("VPN sections follow the plugin, new WireGuard and VPN profiles get their defaults", () => {
    const vpn = svc => ({ connection: { type: "vpn" }, vpn: { "service-type": svc }, ipv4: {}, ipv6: {} });
    assert.deepEqual(ce.sectionsFor("vpn", vpn("org.freedesktop.NetworkManager.openvpn")), ["general", "openvpn", "vpnData", "ipv4", "ipv6"]);
    assert.deepEqual(ce.sectionsFor("vpn", vpn("org.freedesktop.NetworkManager.openconnect")), ["general", "openconnect", "vpnData", "ipv4", "ipv6"]);
    assert.deepEqual(ce.sectionsFor("vpn", vpn("org.freedesktop.NetworkManager.protun")), ["general", "vpnData", "ipv4", "ipv6"]);
    assert.deepEqual(ce.sectionsFor("wireguard", {}), ["general", "wireguard", "ipv4", "ipv6"]);
    assert.equal(ce.vpnForm("org.freedesktop.NetworkManager.openvpnx"), "");
    assert.equal(ce.groupOf("vpn:org.freedesktop.NetworkManager.openvpn"), "vpn");
    assert.ok(ce.VPN_FORM_KEYS.openvpn.data.includes("ta-dir"));
    assert.deepEqual(ce.VPN_FORM_KEYS.openvpn.secrets, ["password", "cert-pass"]);
    assert.deepEqual(ce.VPN_FORM_KEYS.openconnect.secrets, []);

    assert.deepEqual(ce.newConnectionSettings("wireguard", { name: "x" }), {
        connection: { id: "x", type: "wireguard", autoconnect: false, "interface-name": "wg0" },
        wireguard: {},
        ipv4: { method: "manual" },
        ipv6: { method: "ignore" }
    });
    assert.deepEqual(ce.newConnectionSettings("wireguard", { name: "x", privateKey: KEY_A }).wireguard, { "private-key": KEY_A });

    assert.deepEqual(ce.newConnectionSettings("vpn:org.freedesktop.NetworkManager.openconnect", { name: "y" }), {
        connection: { id: "y", type: "vpn", autoconnect: false },
        vpn: { "service-type": "org.freedesktop.NetworkManager.openconnect",
            data: { protocol: "anyconnect", "cookie-flags": "2", "gateway-flags": "2", "gwcert-flags": "2" } },
        ipv4: { method: "auto" },
        ipv6: { method: "auto" }
    });
    assert.deepEqual(ce.newConnectionSettings("vpn:org.freedesktop.NetworkManager.openvpn", { name: "z" }).vpn.data, { "connection-type": "tls" });
    assert.deepEqual(ce.newConnectionSettings("vpn:org.freedesktop.NetworkManager.protun", { name: "z" }).vpn.data, {});
    const again = ce.newConnectionSettings("vpn:org.freedesktop.NetworkManager.openvpn", { name: "z" });
    assert.deepEqual(again.vpn.data, { "connection-type": "tls" });
});

test("removing a stored secret sends a null entry, omission keeps", () => {
    const original = { password: "pw", foo: "1" };
    assert.deepEqual(ce.secretsWith(original, "password", "", original), { password: null, foo: "1" });
    assert.deepEqual(ce.secretsWith(original, "password", "new", original), { password: "new", foo: "1" });
    assert.equal(ce.secretsWith({ "cert-pass": "x" }, "cert-pass", "", {}), undefined);
    assert.equal(ce.secretsWith({}, "password", "", undefined), undefined);

    assert.deepEqual(ce.kvFromRows([], { password: null }, ["password"], original), { password: null, foo: null });
    assert.deepEqual(ce.kvFromRows([{ key: "foo", value: "2" }], {}, [], original), { foo: "2", password: null });
    assert.deepEqual(ce.kvFromRows([{ key: "bar", value: "3" }], {}, ["password"], original), { bar: "3", foo: null });
    assert.deepEqual(ce.kvFromRows([], {}, [], undefined), {});
    assert.deepEqual(ce.kvRows({ password: null, foo: "1" }, []), [{ key: "foo", value: "1" }]);

    const o = { vpn: { "service-type": "x", secrets: { password: "pw", foo: "1" } } };
    const d = { vpn: { "service-type": "x", secrets: { password: null, foo: "1" } } };
    assert.deepEqual(ce.settingsDiff(o, d), { vpn: { secrets: { password: null, foo: "1" } } });
    const wo = { wireguard: { peers: [{ "public-key": KEY_A, "preshared-key": KEY_B }] } };
    const wd = { wireguard: { peers: [{ "public-key": KEY_A, "preshared-key": null }] } };
    assert.deepEqual(ce.settingsDiff(wo, wd), wd);
});

test("secret flags map to saved and ask", () => {
    assert.equal(ce.secretSaved({ "password-flags": "2" }, "password"), false);
    assert.equal(ce.secretSaved({ "password-flags": "0" }, "password"), true);
    assert.equal(ce.secretSaved({}, "password"), true);
    assert.equal(ce.secretSaved(null, "password"), true);
    assert.deepEqual(ce.withSecretSaved({ remote: "a" }, "password", false), { remote: "a", "password-flags": "2" });
    assert.deepEqual(ce.withSecretSaved({ "password-flags": "2" }, "password", true), { "password-flags": "0" });
});

test("dropdown choices keep an unknown stored value selectable and map labels to values", () => {
    const list = [{ label: "Auto", value: "" }, { label: "5 GHz", value: "a" }];
    assert.deepEqual(ce.withChoice(list, "a"), list);
    assert.deepEqual(ce.withChoice(list, "6GHz"), list.concat([{ label: "6GHz", value: "6GHz" }]));
    assert.equal(ce.choiceLabel(list, ""), "Auto");
    assert.equal(ce.choiceLabel(list, 3), "3");
    assert.equal(ce.choiceValue(list, "5 GHz"), "a");
    assert.equal(ce.choiceValue(list, "nope"), undefined);
});

test("ports are detected by either key pair and lose their IP sections", () => {
    assert.deepEqual(ce.portOf({ connection: { master: "u", "slave-type": "bond" } }), { controller: "u", type: "bond" });
    assert.deepEqual(ce.portOf({ connection: { controller: "u", "port-type": "bridge" } }), { controller: "u", type: "bridge" });
    assert.equal(ce.portOf({ connection: { id: "x" } }), null);
    assert.equal(ce.portOf({ connection: { controller: "" } }), null);
    assert.equal(ce.portOf(null), null);

    const port = { connection: { master: "u", "slave-type": "bridge" }, ipv4: {}, ipv6: {} };
    assert.deepEqual(ce.sectionsFor("802-3-ethernet", port), ["general", "ethernet", "security", "port"]);
    assert.deepEqual(ce.sectionsFor("bluetooth", { bluetooth: { type: "dun" }, gsm: {}, ipv4: {} }), ["general", "bluetooth", "mobile", "ppp", "ipv4"]);
    assert.deepEqual(ce.sectionsFor("bluetooth", { bluetooth: { type: "panu" }, ipv4: {}, ipv6: {} }), ["general", "bluetooth", "ipv4", "ipv6"]);
    assert.deepEqual(ce.sectionsFor("bond", {}), ["general", "bond", "ports", "ipv4", "ipv6"]);
    assert.deepEqual(ce.sectionsFor("bridge", {}), ["general", "bridge", "ports", "ipv4", "ipv6"]);
    assert.deepEqual(ce.sectionsFor("vlan", {}), ["general", "vlan", "ipv4", "ipv6"]);
    assert.deepEqual(ce.sectionsFor("pppoe", {}), ["general", "pppoe", "ethernet", "ppp", "ipv4", "ipv6"]);
    assert.deepEqual(ce.sectionsFor("cdma", {}), ["general", "mobile", "ppp", "ipv4", "ipv6"]);
    assert.deepEqual(["vlan", "bond", "bridge", "pppoe", "gsm", "cdma", "bluetooth"].map(t => ce.typeInfo(t).addable),
        [true, true, true, true, true, false, false]);
});

test("new ports and controllers", () => {
    assert.deepEqual(ce.newPortSettings({ uuid: "U", ifname: "dmsbr0", type: "bridge" }, "enp5s0", false), {
        connection: { id: "dmsbr0-port-enp5s0", type: "802-3-ethernet", "interface-name": "enp5s0", master: "U", "slave-type": "bridge", autoconnect: false },
        "802-3-ethernet": {},
        "bridge-port": {}
    });
    assert.equal(ce.newPortSettings({ uuid: "U", ifname: "", id: "Bond", type: "bond" }, "enp5s0", true).connection.id, "Bond-port-enp5s0");
    assert.equal("bridge-port" in ce.newPortSettings({ uuid: "U", ifname: "bond0", type: "bond" }, "enp5s0", true), false);

    assert.deepEqual(ce.newConnectionSettings("bond", { name: "b" }), {
        connection: { id: "b", type: "bond", autoconnect: false, "interface-name": "bond0", "autoconnect-slaves": 1 },
        ipv4: { method: "auto" },
        ipv6: { method: "auto" },
        bond: { options: { mode: "balance-rr" } }
    });
    const bridge = ce.newConnectionSettings("bridge", { name: "br" });
    assert.deepEqual([bridge.connection["interface-name"], bridge.connection["autoconnect-slaves"], bridge.bridge], ["br0", 1, {}]);
    assert.deepEqual(ce.newConnectionSettings("vlan", { name: "v", parent: "enp5s0" }).vlan, { parent: "enp5s0" });
    assert.deepEqual(ce.newConnectionSettings("vlan", { name: "v" }).vlan, { parent: "" });
    const pppoe = ce.newConnectionSettings("pppoe", { name: "dsl" });
    assert.deepEqual([pppoe.pppoe, pppoe["802-3-ethernet"], pppoe.ppp, pppoe.connection.autoconnect], [{}, {}, {}, false]);
    const gsm = ce.newConnectionSettings("gsm", { name: "m" });
    assert.deepEqual([gsm.gsm, gsm.connection.autoconnect, gsm.ipv4.method], [{ "auto-config": true }, false, "auto"]);
});

test("bond monitoring keeps miimon and arp_interval exclusive and unknown options intact", () => {
    const arp = ce.applyBondMonitoring({ mode: "active-backup", miimon: "100", updelay: "200", primary: "enp5s0" }, "arp", { interval: "1000", targets: "192.0.2.1, 192.0.2.2" });
    assert.deepEqual(arp, { mode: "active-backup", primary: "enp5s0", miimon: "0", arp_interval: "1000", arp_ip_target: "192.0.2.1,192.0.2.2" });
    assert.equal(ce.bondMonitoring(arp), "arp");

    const mii = ce.applyBondMonitoring(arp, "mii", { interval: "", updelay: "", downdelay: "300" });
    assert.deepEqual(mii, { mode: "active-backup", primary: "enp5s0", miimon: "100", downdelay: "300" });
    assert.equal(ce.bondMonitoring({ arp_interval: "0" }), "mii");
    assert.equal(ce.bondMonitoring({}), "mii");

    assert.deepEqual(ce.applyBondMonitoring(arp, "arp", { interval: "", targets: "" }), { mode: "active-backup", primary: "enp5s0", miimon: "0" });
    assert.deepEqual(ce.applyBondMonitoring({ updelay: "200" }, "mii", { interval: "0", updelay: "200", downdelay: "300" }), { miimon: "0" });

    assert.equal(ce.isValidArpTargets("192.0.2.1, 192.0.2.2 192.0.2.3"), true);
    assert.equal(ce.isValidArpTargets(""), false);
    assert.equal(ce.isValidArpTargets("192.0.2.1, fe80::1"), false);
});

test("APN, PPP echo, VLAN names and hotspot rules", () => {
    assert.deepEqual(ce.applyApn({ "auto-config": true, pin: "1" }, " internet.t-mobile "), { "auto-config": false, pin: "1", apn: "internet.t-mobile" });
    assert.deepEqual(ce.applyApn({ "auto-config": false, apn: "x" }, ""), { "auto-config": true });
    const plain = { apn: "internet", pin: "1" };
    const cleared = ce.applyApn(plain, "", plain);
    assert.deepEqual(cleared, { "auto-config": true, pin: "1" });
    assert.equal(ce.settingsDiff({ gsm: plain }, { gsm: ce.applyApn(cleared, "internet", plain) }), null);
    assert.deepEqual(ce.applyApn(plain, "other", plain), { apn: "other", pin: "1" });
    assert.deepEqual(ce.applyApn({ "auto-config": true }, "internet", { "auto-config": true }), { "auto-config": false, apn: "internet" });
    assert.deepEqual(ce.applyApn({ "auto-config": true }, "internet", undefined), { "auto-config": false, apn: "internet" });
    assert.deepEqual(ce.applyApn(plain, " ", plain), { "auto-config": true, pin: "1" });
    const bare = { pin: "1" };
    assert.equal(ce.settingsDiff({ gsm: bare }, { gsm: ce.applyApn(ce.applyApn(bare, "a", bare), "", bare) }), null);
    assert.deepEqual(ce.applyApn({ apn: "x" }, "", { "auto-config": false, pin: "1" }), { "auto-config": false });
    assert.deepEqual(ce.applyApn(bare, "", undefined), { pin: "1", "auto-config": true });

    const on = ce.applyPppEcho({ mtu: 1400 }, true);
    assert.deepEqual(on, { mtu: 1400, "lcp-echo-interval": 30, "lcp-echo-failure": 5 });
    assert.equal(ce.pppEcho(on), true);
    assert.deepEqual(ce.applyPppEcho(on, false), { mtu: 1400 });
    assert.equal(ce.pppEcho({ "lcp-echo-interval": 0 }), false);

    assert.equal(ce.defaultVlanIfname("enp5s0", 100), "enp5s0.100");
    assert.equal(ce.defaultVlanIfname("enp5s0", 0), "enp5s0.0");
    assert.equal(ce.defaultVlanIfname("enp5s0f1np1", 4094), "");
    assert.equal(ce.defaultVlanIfname("", 100), "");
    assert.equal(ce.defaultVlanIfname("enp5s0", ""), "");
    assert.equal(ce.defaultVlanIfname("eth0", 4094), "eth0.4094");
    assert.equal(ce.defaultVlanIfname("eth0", 4095), "");
    assert.equal(ce.defaultVlanIfname("eth0", "12a"), "");

    assert.equal(ce.isValidHotspotAddress("10.42.0.1/24"), true);
    assert.equal(ce.isValidHotspotAddress("10.42.0.0/24"), false);
    assert.equal(ce.isValidHotspotAddress("10.42.0.255/24"), false);
    assert.equal(ce.isValidHotspotAddress("10.42.0.1/31"), false);
    assert.equal(ce.isValidHotspotAddress("10.42.0.1/7"), false);
    assert.equal(ce.isValidHotspotAddress("10.42.0.1"), false);

    const a = ce.hotspotChannels("a");
    assert.ok(a.includes(36) && a.includes(165) && !a.includes(14));
    assert.deepEqual(ce.hotspotChannels("bg"), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);
    assert.deepEqual(ce.hotspotChannels(""), []);
});

const enterpriseBase = {
    eap: "peap",
    phase2: "mschapv2",
    identity: "user",
    password: "secret",
    savePassword: true,
    anonymousIdentity: "",
    ca: "system",
    caCertPath: "",
    caCertPem: "",
    serverDomain: "radius.example.org",
    serverDomainSuffix: false,
    clientCertPath: "",
    privateKeyPath: "",
    privateKeyPassword: "",
    peapVersion: "",
    authFlags: 0,
    opensslCiphers: "",
    usernameSuffix: ""
};

const enterpriseState = over => Object.assign({}, enterpriseBase, over);

test("enterpriseConfig maps form state to EnterpriseConfig", () => {
    assert.equal(ce.enterpriseConfig(enterpriseState({ identity: "stine", usernameSuffix: "uni-hamburg.de" })).identity, "stine@uni-hamburg.de");
    assert.equal(ce.enterpriseConfig(enterpriseState({ identity: "stine@other.de", usernameSuffix: "uni-hamburg.de" })).identity, "stine@other.de");

    assert.equal(ce.enterpriseConfig(enterpriseState({ eap: "ttls", phase2: "eap-mschapv2" })).phase2, "eap-mschapv2");

    const ask = ce.enterpriseConfig(enterpriseState({ savePassword: false }));
    assert.equal(ask.askPassword, true);
    assert.equal("password" in ask, false);

    const tls13Off = ce.withFlags(0x8, 0x10, true);
    assert.equal(ce.enterpriseConfig(enterpriseState({ authFlags: tls13Off })).authFlags, 0x18);
    assert.equal(ce.withFlags(0x18 | 0x60, 0x60, false), 0x18);
    assert.equal(ce.withFlags(0, 0x80000000, true), 0x80000000);

    const pwd = ce.enterpriseConfig(enterpriseState({ eap: "pwd", ca: "file", caCertPath: "/ca.pem" }));
    assert.equal(pwd.ca, "none");
    assert.equal("phase2" in pwd, false);
    assert.equal("serverDomain" in pwd, false);
});

test("enterpriseConfigValid matrix", () => {
    const cases = [
        ["system CA without server", { serverDomain: "" }, {}, false],
        ["file CA with only an imported PEM", { ca: "file", caCertPem: "-----BEGIN CERTIFICATE-----" }, {}, true],
        ["file CA without path or PEM", { ca: "file" }, {}, false],
        ["TLS without client certificate", { eap: "tls", privateKeyPassword: "k" }, {}, false],
        ["TLS with client certificate", { eap: "tls", clientCertPath: "/c.p12", privateKeyPassword: "k" }, {}, true],
        ["TLS without key password", { eap: "tls", clientCertPath: "/c.pem", password: "" }, {}, true],
        ["ask password without password", { password: "", savePassword: false }, {}, true],
        ["missing password", { password: "" }, {}, false],
        ["missing username", { identity: "" }, {}, false],
        ["required suffix, wrong domain", { identity: "stine@other.de", usernameSuffix: "uni-hamburg.de" }, { usernameSuffix: "uni-hamburg.de", usernameSuffixRequired: true }, false],
        ["required suffix, appended", { identity: "stine", usernameSuffix: "uni-hamburg.de" }, { usernameSuffix: "uni-hamburg.de", usernameSuffixRequired: true }, true],
        ["PWD ignores CA and server", { eap: "pwd", serverDomain: "" }, {}, true]
    ];
    for (const [name, over, opts, expected] of cases)
        assert.equal(ce.enterpriseConfigValid(ce.enterpriseConfig(enterpriseState(over)), opts), expected, name);
});

test("enterpriseConfigValid counts stored certificate files as present", () => {
    const cases = [
        ["stored CA", { ca: "file" }, { storedFiles: { ca: true } }, true],
        ["file CA without stored flag", { ca: "file" }, { storedFiles: {} }, false],
        ["TLS with stored client certificate", { eap: "tls" }, { storedFiles: { clientCert: true } }, true],
        ["TLS with stored CA only", { eap: "tls" }, { storedFiles: { ca: true } }, false]
    ];
    for (const [name, over, opts, expected] of cases)
        assert.equal(ce.enterpriseConfigValid(ce.enterpriseConfig(enterpriseState(over)), opts), expected, name);
});
