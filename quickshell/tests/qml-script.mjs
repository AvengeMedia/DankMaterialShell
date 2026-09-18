import { readFileSync } from "node:fs";
import vm from "node:vm";

export function loadScript(url) {
    const context = vm.createContext({ console: { info() {}, warn() {} } });
    const source = readFileSync(url, "utf8").replace(/^\s*\.import "([^"]+)" as (\w+)\s*$/gm, (_, path, name) => {
        context[name] = loadScript(new URL(path, url));
        return "";
    }).replace(/^\.pragma.*$/gm, "");
    vm.runInContext(source, context);
    return context;
}
