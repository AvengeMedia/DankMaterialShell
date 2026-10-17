import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const ctx = loadScript(new URL("../Services/SysmonDevices.js", import.meta.url));
const count = (...locs) => ctx.memoryChannelCount(locs.map(locator => ({ locator })));

test("Gigabyte/ASUS DIMM_xN (this machine's four slots)", () => {
    assert.equal(count("DIMM_A2", "DIMM_B2"), 2);
    assert.equal(count("DIMM_A1", "DIMM_A2", "DIMM_B1", "DIMM_B2"), 2);
    assert.equal(count("DIMM_A1", "DIMM_B1", "DIMM_C1", "DIMM_D1"), 4);
});

test("Intel/Dell ChannelA-DIMM0 and laptop SODIMM forms", () => {
    assert.equal(count("ChannelA-DIMM0", "ChannelB-DIMM0"), 2);
    assert.equal(count("Controller0-ChannelA-DIMM0", "Controller1-ChannelA-DIMM0"), 2);
    assert.equal(count("ChannelA-DIMM0"), 1);
    assert.equal(count("SODIMM_A", "SODIMM_B"), 2);
    assert.equal(count("A1_DIMM0", "A2_DIMM0", "B1_DIMM0", "B2_DIMM0"), 2);
    assert.equal(count("A1_SODIMM", "B1_SODIMM"), 2);
});

test("server style P0 CHANNEL A keeps sockets apart", () => {
    assert.equal(count("P0 CHANNEL A", "P0 CHANNEL B"), 2);
    assert.equal(count("P0 CHANNEL A", "P1 CHANNEL A"), 2);
    assert.equal(count("P0 CHANNEL A", "P0 CHANNEL B", "P0 CHANNEL C", "P0 CHANNEL D"), 4);
});

test("single DIMM, and two DIMMs on one channel, are single", () => {
    assert.equal(count("DIMM_A1"), 1);
    assert.equal(count("DIMM_A1", "DIMM_A2"), 1);
});

test("unrecognized locators give null, never a guess", () => {
    assert.equal(count("BANK 0", "BANK 1"), null);
    assert.equal(count("DIMM0", "DIMM1"), null);
    assert.equal(count("DIMM_A1", "Slot 2"), null);
    assert.equal(count("Unknown"), null);
    assert.equal(count(""), null);
    assert.equal(ctx.memoryChannelCount([]), null);
    assert.equal(ctx.memoryChannelCount(null), null);
});
