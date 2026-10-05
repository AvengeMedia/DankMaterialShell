import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Services/HyprlandService.qml", import.meta.url), "utf8");
const slice = name => source.match(new RegExp(`^ {4}function ${name}\\([^)]*\\) \\{\\n[\\s\\S]*?^ {4}\\}$`, "m"))[0];

function hyprland(id, name) {
    const Hyprland = {
        focusedWorkspace: { id, name },
        dispatch(command) {
            const [, wsId, fullName] = command.match(/^renameworkspace (\S+) (.*)$/);
            assert.equal(Number(wsId), Hyprland.focusedWorkspace.id);
            Hyprland.focusedWorkspace.name = fullName;
        }
    };
    const context = vm.createContext({ Hyprland, luaConfigActive: false });
    vm.runInContext(slice("renameWorkspace") + "\n" + slice("focusedWorkspaceName"), context);
    return context;
}

test("prefill hides the id prefix that rename adds, so renaming twice does not stack it", () => {
    const shell = hyprland(3, "3");
    assert.equal(shell.focusedWorkspaceName(), "");
    shell.renameWorkspace("web");
    assert.equal(shell.focusedWorkspaceName(), "web");
    shell.renameWorkspace(shell.focusedWorkspaceName() + " 2");
    assert.equal(shell.Hyprland.focusedWorkspace.name, "3 web 2");
});

test("names set outside DMS come through unchanged", () => {
    assert.equal(hyprland(4, "mail").focusedWorkspaceName(), "mail");
    assert.equal(hyprland(-98, "special:magic").focusedWorkspaceName(), "special:magic");
});
