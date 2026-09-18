import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const grid = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Modules/DankDash/utils/grid.js", import.meta.url), "utf8"), grid);
const cards = [{ id: "clock", w: 2, h: 1 }, { id: "weather", w: 1, h: 1 }, { id: "notifications", w: 3, h: 5 }, { id: "calendar", w: 3, h: 3 }, { id: "media", w: 3, h: 1 }];
const order = cards.map((card, i) => i);
const unit = { w: 1, h: 1 };
const plain = value => JSON.parse(JSON.stringify(value));

test("default card set packs into exactly the default board", () => {
    assert.equal(grid.packCells(cards, order, 6).rows, 5);
    assert.deepEqual(plain(grid.packCards(cards, order, 6, 600, 0, 100, false).slots[4]), { x: 0, y: 400, w: 300, h: 100, col: 0, row: 4, cols: 3, rows: 1 });
});

test("resize keeps the board within its rows", () => {
    assert.deepEqual(plain(grid.fitResize(cards, order, 6, 5, 4, { w: 3, h: 2 }, unit)), { w: 3, h: 1 });
    assert.deepEqual(plain(grid.fitResize(cards, order, 6, 5, 4, { w: 1, h: 1 }, unit)), { w: 1, h: 1 });
    assert.deepEqual(plain(grid.fitResize(cards, order, 6, 8, 4, { w: 3, h: 2 }, unit)), { w: 3, h: 2 });
});

test("resize on an overflowing board may shrink but not grow the overflow", () => {
    const over = cards.concat([{ id: "user", w: 3, h: 2 }]);
    const overOrder = over.map((card, i) => i);
    assert.equal(grid.packCells(over, overOrder, 6).rows, 7);
    assert.deepEqual(plain(grid.fitResize(over, overOrder, 6, 5, 5, { w: 3, h: 1 }, unit)), { w: 3, h: 1 });
    assert.deepEqual(plain(grid.fitResize(over, overOrder, 6, 5, 5, { w: 3, h: 3 }, unit)), { w: 3, h: 2 });
});

test("new cards shrink to free space or are rejected", () => {
    const partial = [{ id: "clock", w: 6, h: 4 }, { id: "user", w: 2, h: 1 }];
    assert.equal(grid.fitNewCard(cards, 6, 5, "user", { w: 3, h: 1 }, unit), null);
    assert.deepEqual(plain(grid.fitNewCard(partial, 6, 5, "weather", { w: 1, h: 2 }, unit)), { w: 1, h: 1 });
    assert.deepEqual(plain(grid.fitNewCard(partial, 6, 5, "media", { w: 2, h: 1 }, unit)), { w: 2, h: 1 });
    assert.equal(grid.fitNewCard(partial, 6, 5, "calendar", { w: 3, h: 3 }, { w: 3, h: 3 }), null);
    assert.deepEqual(plain(grid.fitNewCard(partial, 6, 5, "user", { w: 4, h: 3 }, unit)), { w: 4, h: 1 });
});

test("unavailable cards take no space", () => {
    const isAvailable = id => id !== "notifications";
    assert.equal(grid.packCells(cards, order, 6, isAvailable).cells[2], null);
    assert.deepEqual(plain(grid.fitNewCard(cards, 6, 5, "user", { w: 3, h: 3 }, unit, isAvailable)), { w: 3, h: 3 });
});
