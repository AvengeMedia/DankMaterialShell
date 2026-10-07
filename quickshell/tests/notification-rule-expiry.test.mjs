import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const expiry = loadScript(new URL("../Common/NotificationRuleExpiry.js", import.meta.url));

// The script runs inside a vm context, so returned objects live in another
// realm; clone them into plain host objects before deep comparisons
// (bar-content.test.mjs pattern).
const plain = value => JSON.parse(JSON.stringify(value));

test("rules without expiresAt never expire", () => {
    assert.equal(expiry.isRuleExpired({}, 1000), false);
    assert.equal(expiry.isRuleExpired(null, 1000), false);
    assert.equal(expiry.isRuleExpired({ expiresAt: 0 }, 1000), false);
    assert.equal(expiry.isRuleExpired({ action: "mute" }, Number.MAX_SAFE_INTEGER), false);
});

test("timed rules expire strictly after their timestamp", () => {
    const rule = { action: "mute", expiresAt: 5000 };
    assert.equal(expiry.isRuleExpired(rule, 4999), false);
    assert.equal(expiry.isRuleExpired(rule, 5000), false);
    assert.equal(expiry.isRuleExpired(rule, 5001), true);
});

test("hasTimedRule reports whether any rule carries an expiry", () => {
    assert.equal(expiry.hasTimedRule(null), false);
    assert.equal(expiry.hasTimedRule([]), false);
    assert.equal(expiry.hasTimedRule([{}, { action: "mute" }, { expiresAt: 0 }]), false);
    assert.equal(expiry.hasTimedRule([null, { expiresAt: 0 }, { expiresAt: 5000 }]), true);
    // Expired-but-unswept rules still count: they keep the sweeper alive
    // until they are dropped from the persisted list.
    assert.equal(expiry.hasTimedRule([{ expiresAt: 1 }]), true);
});
