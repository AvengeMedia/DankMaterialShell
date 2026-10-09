import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Services/NotificationService.qml", import.meta.url), "utf8");

function service(notifications) {
    const context = vm.createContext({ notifications });
    for (const [, name, parameters, body] of source.matchAll(/^    function (\w+)\(([^)]*)\)(?:: \w+)? \{([\s\S]*?)^    \}/gm))
        if (["invokeLastNotification", "dismissNotification"].includes(name))
            vm.runInContext(`function ${name}(${parameters}) {${body}}`, context);
    return context;
}

function wrapper(log, name, identifiers) {
    return {
        popup: true,
        notification: { dismiss: () => log.push(`dismiss ${name}`) },
        actions: identifiers.map(id => ({ identifier: id, invoke: () => log.push(`${name} ${id}`) }))
    };
}

test("invokeLast runs the default action of the newest notification and dismisses it", () => {
    for (const [identifiers, expected] of [[["edit", "default"], "default"], [["edit", "open"], "edit"]]) {
        const log = [];
        const newest = wrapper(log, "newest", identifiers);
        const s = service([wrapper(log, "older", ["default"]), newest]);
        assert.equal(s.invokeLastNotification(), true);
        assert.deepEqual(log, [`newest ${expected}`, "dismiss newest"]);
        assert.equal(newest.popup, false);
    }
});

test("invokeLast does nothing when the newest notification has no action", () => {
    for (const count of [0, 1]) {
        const log = [];
        const s = service(count ? [wrapper(log, "plain", [])] : []);
        assert.equal(s.invokeLastNotification(), false);
        assert.deepEqual(log, []);
    }
});
