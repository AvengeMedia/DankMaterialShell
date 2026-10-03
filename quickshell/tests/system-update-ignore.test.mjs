import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Services/SystemUpdateService.qml", import.meta.url), "utf8");
const declaration = source.match(/^    function isValidIgnoredName\([^)]*\) \{\n[\s\S]*?^    \}/m);
if (!declaration)
    throw new Error("isValidIgnoredName not found in SystemUpdateService.qml");
const scope = vm.createContext({});
vm.runInContext(declaration[0], scope);

test("portage atoms and other package names can be ignored", () => {
    for (const name of ["sys-apps/portage", "mail-client/thunderbird:0", "docker", "org.mozilla.firefox", "bash.x86_64", "gtk+"])
        assert.equal(scope.isValidIgnoredName(name), true, name);
});

test("names with spaces or shell punctuation are rejected", () => {
    for (const name of ["", "sys apps", "a;b", "$(reboot)", "sys-apps/portage;reboot", "sys-apps/*"])
        assert.equal(scope.isValidIgnoredName(name), false, name);
});

