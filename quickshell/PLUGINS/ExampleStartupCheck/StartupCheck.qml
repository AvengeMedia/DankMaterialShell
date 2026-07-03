import QtQuick
import qs.Common

QtObject {
    // Optional async dependency gate. Receives a done(result) callback:
    //   done(null)                       -> allow activation
    //   done("short message")            -> block with a title only
    //   done({ title, details })         -> block with an expandable details body
    // A synchronous variant (no argument, return the result) is also supported.
    function check(done) {
        Proc.runCommand("exampleStartupCheck.depCheck", ["sh", "-c", "command -v boregard"], (stdout, exitCode) => {
            if (exitCode === 0) {
                done(null);
                return;
            }
            done({
                "title": I18n.tr("boregard is required"),
                "details": I18n.tr("The 'boregard' tool is not installed or not on your PATH.\n\nInstall it from https://danklinux.com, then re-enable this plugin.")
            });
        });
    }
}
