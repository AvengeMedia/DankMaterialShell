import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Services/MuxService.qml", import.meta.url), "utf8");

function service() {
    const commands = [];
    const context = vm.createContext({
        SettingsData: { muxType: "herdr", muxSessionFilter: "" },
        Quickshell: { execDetached: args => commands.push(Array.from(args)) },
        Paths: { expandTilde: path => path.replace(/^~\//, "/home/test/") },
        Qt: { callLater: callback => callback() },
        listProcess: { running: false },
        terminal: "kitty",
        terminalFlags: { kitty: ["-e"] },
        tmuxAvailable: false,
        zellijAvailable: false,
        herdrAvailable: true,
        sessions: []
    });
    context.root = context;
    for (const name of ["muxType", "currentMuxAvailable", "displayName", "supportsRename"]) {
        const expression = source.match(new RegExp(`readonly property \\w+ ${name}: (.+)`))[1];
        Object.defineProperty(context, name, { get: () => vm.runInContext(expression, context) });
    }
    for (const match of source.matchAll(/^    function \w+\([^\n]*\) \{\n[\s\S]*?^    \}/gm))
        vm.runInContext(match[0], context);
    return { context, commands };
}

test("Herdr JSON accepts each envelope and name field, retaining stopped sessions", () => {
    const sessions = [
        { name: "running", running: true },
        { session: "active", active: true },
        { id: "status-running", status: "running" },
        { name: "status-active", status: "active" },
        { name: "stopped", running: false, status: "stopped" },
        { id: 42 },
        null, {}, { name: {} }
    ];
    const { context } = service();
    for (const payload of [sessions, { sessions }, { result: { sessions } }]) {
        context._parseHerdrSessions(JSON.stringify(payload));
        assert.deepEqual(JSON.parse(JSON.stringify(context.sessions)), [
            { name: "running", windows: "N/A", attached: true },
            { name: "active", windows: "N/A", attached: true },
            { name: "status-running", windows: "N/A", attached: true },
            { name: "status-active", windows: "N/A", attached: true },
            { name: "stopped", windows: "N/A", attached: false },
            { name: "42", windows: "N/A", attached: false }
        ]);
    }
    context.SettingsData.muxSessionFilter = " RUNNING, /^status-/ ";
    context._parseHerdrSessions(JSON.stringify(sessions));
    assert.deepEqual(Array.from(context.sessions, session => session.name), ["active", "stopped", "42"]);
    for (const payload of [[], {}, null, { sessions: {} }]) {
        context._parseHerdrSessions(JSON.stringify(payload));
        assert.equal(context.sessions.length, 0);
    }
    assert.throws(() => context._parseHerdrSessions("not JSON"));
});

test("Herdr availability gates JSON listing independently of other backends", () => {
    const { context } = service();
    assert.equal(context.displayName, "Herdr");
    context.refreshSessions();
    assert.deepEqual(Array.from(context.listProcess.command), ["herdr", "session", "list", "--json"]);
    assert.equal(context.listProcess.running, true);
    context.herdrAvailable = false;
    context.tmuxAvailable = true;
    context.zellijAvailable = true;
    context.sessions = [{ name: "stale" }];
    context.listProcess.running = false;
    context.refreshSessions();
    assert.equal(context.sessions.length, 0);
    assert.equal(context.listProcess.running, false);
});

test("Herdr actions use the terminal prefix, stop rather than delete, and refuse rename", () => {
    const { context, commands } = service();
    const name = "my session; echo nope";
    context.attachToSession(name);
    context.createSession(name);
    context.killSession(name);
    assert.equal(context.supportsRename, false);
    context.renameSession(name, "renamed");
    assert.deepEqual(commands, [
        ["kitty", "-e", "herdr", "session", "attach", name],
        ["kitty", "-e", "herdr", "--session", name],
        ["herdr", "session", "stop", name]
    ]);
    context.SettingsData.muxUseCustomCommand = true;
    context.SettingsData.muxCustomCommand = "~/mux-launch";
    context.attachToSession(name);
    context.createSession(name);
    assert.deepEqual(commands.slice(3), [
        ["/home/test/mux-launch", name],
        ["/home/test/mux-launch", name]
    ]);
});
