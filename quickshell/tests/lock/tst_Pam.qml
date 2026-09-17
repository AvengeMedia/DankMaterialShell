import QtQuick
import QtTest
import Quickshell.Services.Pam
import qs.Common
import qs.Services
import "../../Modules/Lock" as Lock

TestCase {
    id: tests
    name: "FingerprintLifecycle"

    Component {
        id: factory
        Lock.Pam {}
    }

    function init() {
        SettingsData.enableFprint = true;
        SettingsData.enableU2f = false;
        SettingsData.u2fMode = "and";
        SettingsData.lockFingerprintReady = true;
        SettingsData.lockPamExternallyManaged = false;
        SettingsData.lockPamPath = "";
        SettingsData.lockPamInlineFprint = false;
        SettingsData.maxFprintTries = 2;
        SessionService.preparingForSleep = false;
        IdleService.monitorsOff = false;
    }

    function lockedPam() {
        const pam = createTemporaryObject(factory, tests);
        verify(pam !== null);
        pam.lockSecured = true;
        tryCompare(pam.fprint, "active", true);
        compare(pam.fprint.starts, 1);
        return pam;
    }

    function test_pendingRetryCancelled_data() {
        return [
            {
                tag: "disabled",
                setting: "enableFprint",
                value: false
            },
            {
                tag: "unavailable",
                setting: "lockFingerprintReady",
                value: false
            },
            {
                tag: "managedPam",
                setting: "lockPamExternallyManaged",
                value: true
            },
            {
                tag: "inlineFingerprint",
                setting: "lockPamInlineFprint",
                value: true
            }
        ];
    }

    function test_pendingRetryCancelled(data) {
        SettingsData.lockPamPath = "/test/custom";
        const pam = lockedPam();
        pam.fprint.finish(PamResult.Error);
        verify(pam.fprint.retrying);
        SettingsData[data.setting] = data.value;
        verify(!pam.fprint.retrying);
        verify(!pam.fprint.active);
        wait(1700);
        compare(pam.fprint.starts, 1);
        compare(pam.fprint.status, "disabled");
    }

    function test_disabledContextIgnoresLateSuccess() {
        const pam = lockedPam();
        SettingsData.enableFprint = false;
        pam.fprint.finish(PamResult.Success);
        verify(!pam.unlockInProgress);
        verify(!pam.u2fPending);
    }

    function test_unlockCancelsPendingRetry() {
        const pam = lockedPam();
        pam.fprint.finish(PamResult.Error);
        pam.lockSecured = false;
        verify(!pam.fprint.retrying);
        wait(1700);
        compare(pam.fprint.starts, 1);
    }

    function test_passwordSuccessCancelsRetryBeforeSecondFactor() {
        const pam = lockedPam();
        SettingsData.enableU2f = true;
        pam.fprint.finish(PamResult.Error);
        pam.passwd.start();
        pam.passwd.finish(PamResult.Success);
        verify(pam.u2fPending);
        verify(pam.u2f.active);
        verify(!pam.fprint.retrying);
        compare(pam.fprint.status, "paused");
        wait(1700);
        compare(pam.fprint.starts, 1);
    }

    function test_passwordRemainsUsableWhileFingerprintActive() {
        const pam = lockedPam();
        pam.passwd.start();
        verify(pam.fprint.active);
        pam.passwd.finish(PamResult.Success);
        verify(pam.unlockInProgress);
        verify(!pam.fprint.active);
        verify(!pam.fprint.retrying);
    }

    function test_u2fCancellationResumesWithoutResettingBadScans() {
        const pam = lockedPam();
        SettingsData.enableU2f = true;
        pam.fprint.finish(PamResult.MaxTries);
        compare(pam.fprint.tries, 1);
        pam.u2f.startForSecondFactor();
        verify(!pam.fprint.retrying);
        pam.cancelU2fPending();
        compare(pam.fprint.tries, 1);
        verify(pam.fprint.active);
    }

    function exhaustBadScans(pam) {
        pam.fprint.finish(PamResult.MaxTries);
        verify(pam.fprint.active);
        pam.fprint.finish(PamResult.MaxTries);
        compare(pam.fprint.tries, SettingsData.maxFprintTries);
        compare(pam.fprint.status, "max");
        verify(!pam.fprint.active);
    }

    function test_badScanLimitSurvivesU2fCancelAndRecovery() {
        const pam = lockedPam();
        exhaustBadScans(pam);
        SettingsData.enableU2f = true;
        pam.u2f.startForSecondFactor();
        pam.cancelU2fPending();
        SettingsData.enableFprint = false;
        SettingsData.enableFprint = true;
        SessionService.lidOpened();
        SessionService.sessionResumed();
        pam.retryFprintOnActivity();
        wait(1700);
        compare(pam.fprint.tries, SettingsData.maxFprintTries);
        compare(pam.fprint.starts, 2);
        compare(pam.fprint.status, "max");
    }

    // max-tries=1 in the PAM profile makes one finished session equal one wrong
    // finger, so the setting is spent scan for scan and each scan costs a fresh
    // PAM session and device claim.
    function test_wrongScanBudgetIsSpentScanForScan() {
        SettingsData.maxFprintTries = 5;
        const pam = lockedPam();
        for (let i = 1; i < SettingsData.maxFprintTries; i++) {
            pam.fprint.finish(PamResult.MaxTries);
            compare(pam.fprint.tries, i);
            compare(pam.fprint.starts, i + 1);
            compare(pam.fprint.status, "active");
        }
        pam.fprint.finish(PamResult.MaxTries);
        compare(pam.fprint.tries, SettingsData.maxFprintTries);
        compare(pam.fprint.starts, SettingsData.maxFprintTries);
        compare(pam.fprint.status, "max");
        verify(!pam.fprint.active);
    }

    function test_newLockResetsBadScanLimit() {
        const pam = lockedPam();
        exhaustBadScans(pam);
        pam.lockSecured = false;
        pam.lockSecured = true;
        tryCompare(pam.fprint, "active", true);
        compare(pam.fprint.tries, 0);
        compare(pam.fprint.errorTries, 0);
    }

    function test_failedPamResultCountsBadScan() {
        const pam = lockedPam();
        pam.fprint.finish(PamResult.Failed);
        compare(pam.fprint.tries, 1);
        compare(pam.fprint.errorTries, 0);
        compare(pam.fprintState, "fail");
        verify(!pam.fprint.retrying);
        compare(pam.fprint.starts, 2);
        compare(pam.fprint.status, "active");
    }

    function test_settledSessionExpiryRenewsWithoutError() {
        const pam = lockedPam();
        pam.fprint.finish(PamResult.MaxTries);
        compare(pam.fprint.tries, 1);
        pam.fprint.deliverMessage();
        pam.fprint.attemptStartedAt = Date.now() - (pam.fprint.sessionTimeoutMs + 1000);
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.errorTries, 0);
        compare(pam.fprint.tries, 1);
        compare(pam.fprintState, "fail");
        verify(!pam.fprint.retrying);
        compare(pam.fprint.starts, 3);
        compare(pam.fprint.status, "active");
    }

    function test_earlyErrorStillSpendsErrorBudget() {
        const pam = lockedPam();
        verify(!pam.fprint.attemptSettled());
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.errorTries, 1);
        compare(pam.fprintState, "error");
        verify(pam.fprint.retrying);
        compare(pam.fprint.starts, 1);
    }

    function test_retryingStatusDoesNotClaimActiveScanner() {
        const pam = lockedPam();
        compare(pam.fprint.status, "active");
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.status, "retrying");
        verify(!pam.fprint.active);
        compare(pam.fprint.tries, 0);
        compare(pam.fprintState, "error");
        tryCompare(pam.fprint, "status", "active", 2200);
        compare(pam.fprintState, "");
    }

    function test_errorLimitRecovery_data() {
        return [
            {
                tag: "lid"
            },
            {
                tag: "resume"
            },
            {
                tag: "activity"
            }
        ];
    }

    function test_errorLimitRecovery(data) {
        const pam = lockedPam();
        pam.fprint.errorTries = pam.fprint.maxErrorTries - 1;
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.status, "stopped");
        verify(!pam.fprint.retrying);
        if (data.tag === "lid")
            SessionService.lidOpened();
        else if (data.tag === "resume")
            SessionService.sessionResumed();
        else
            pam.retryFprintOnActivity();
        compare(pam.fprint.errorTries, 0);
        compare(pam.fprint.starts, 2);
        compare(pam.fprint.status, "active");
        compare(pam.fprintState, "");
    }

    function test_backoffIsCutShortByLidOpen() {
        const pam = lockedPam();
        pam.fprint.errorTries = 5;
        pam.fprint.finish(PamResult.Error);
        verify(pam.fprint.retrying);
        SessionService.lidOpened();
        compare(pam.fprint.errorTries, 0);
        compare(pam.fprint.starts, 2);
        compare(pam.fprint.status, "active");
    }

    function test_activityDoesNotPostponePendingRecovery() {
        const pam = lockedPam();
        pam.fprint.finish(PamResult.Error);
        pam.retryFprintOnActivity();
        compare(pam.fprint.errorTries, 1);
        for (let i = 0; i < 4; i++) {
            wait(450);
            pam.retryFprintOnActivity();
        }
        compare(pam.fprint.starts, 2);
    }

    // A verify still running when the machine suspends leaves fprintd holding
    // the device, so the reader must not stay claimed once the screen is off.
    function test_blankScreenReleasesReaderAndWakeRearmsIt() {
        const pam = lockedPam();
        IdleService.monitorsOff = true;
        verify(!pam.fprint.active);
        verify(!pam.fprint.retrying);
        compare(pam.fprint.status, "paused");
        wait(1700);
        compare(pam.fprint.starts, 1);
        IdleService.monitorsOff = false;
        tryCompare(pam.fprint, "starts", 2);
        compare(pam.fprint.status, "active");
    }

    function test_blankScreenCancelsPendingRetry() {
        const pam = lockedPam();
        pam.fprint.finish(PamResult.Error);
        verify(pam.fprint.retrying);
        IdleService.monitorsOff = true;
        verify(!pam.fprint.retrying);
        wait(1700);
        compare(pam.fprint.starts, 1);
    }

    function test_suspendStopsScanAndResumeRestartsIt() {
        const pam = lockedPam();
        SessionService.preparingForSleep = true;
        verify(!pam.fprint.active);
        verify(!pam.fprint.retrying);
        compare(pam.fprint.status, "paused");
        SessionService.preparingForSleep = false;
        SessionService.sessionResumed();
        compare(pam.fprint.starts, 2);
        compare(pam.fprint.status, "active");
    }

    function test_failedStartUsesBackoff() {
        const pam = lockedPam();
        pam.fprint.stop();
        pam.fprint.startSucceeds = false;
        pam.fprint.checkAvail();
        compare(pam.fprint.errorTries, 1);
        verify(pam.fprint.retrying);
        compare(pam.fprintState, "error");
    }

    function test_readinessRecoversExhaustedDeviceErrors_data() {
        return [{tag: "enable", setting: "enableFprint"}, {tag: "device", setting: "lockFingerprintReady"}];
    }

    function test_readinessRecoversExhaustedDeviceErrors(data) {
        const pam = lockedPam();
        pam.fprint.errorTries = pam.fprint.maxErrorTries - 1;
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.status, "stopped");
        SettingsData[data.setting] = false;
        SettingsData[data.setting] = true;
        compare(pam.fprint.errorTries, 0);
        compare(pam.fprint.starts, 2);
    }

    function test_activityPreservesBackoffAfterRepeatedErrors() {
        const pam = lockedPam();
        pam.fprint.errorTries = 1;
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.errorTries, 2);
        compare(pam.fprint.retryInterval, pam.fprint.daemonIdleExitMs + 5000);
        pam.retryFprintOnActivity();
        compare(pam.fprint.errorTries, 2);
        verify(pam.fprint.retrying);
        wait(2000);
        compare(pam.fprint.starts, 1);
    }

    function test_backoffLetsDaemonIdleExitOnSecondRetry() {
        const pam = lockedPam();
        const expected = [1500, 1500, 35000, 60000, 60000];
        for (let n = 0; n < expected.length; n++) {
            pam.fprint.errorTries = n;
            compare(pam.fprint.retryInterval, expected[n], "errorTries=" + n);
        }
        // a wedged device only returns once fprintd exits and starts fresh
        pam.fprint.errorTries = 2;
        verify(pam.fprint.retryInterval > pam.fprint.daemonIdleExitMs);
    }

    function test_synchronousStartFailureSchedulesOneRetry() {
        const pam = lockedPam();
        pam.fprint.stop();
        pam.fprint.startFailsSynchronously = true;
        pam.fprint.checkAvail();
        compare(pam.fprint.errorTries, 1);
        verify(pam.fprint.retrying);
        compare(pam.fprint.starts, 1);
    }

    // pam_fprintd's timeout runs from the verify, so a claim that drags on must
    // not age a fault into looking like an expiry.
    function test_sessionAgeIsMeasuredFromTheVerifyNotTheClaim() {
        const pam = lockedPam();
        compare(pam.fprint.attemptStartedAt, 0);
        verify(!pam.fprint.attemptSettled());
        pam.fprint.deliverMessage();
        verify(pam.fprint.attemptStartedAt > 0);
    }

    function test_errorBeforeAnyVerifyIsAlwaysAFault() {
        const pam = lockedPam();
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.errorTries, 1);
        compare(pam.fprintState, "error");
        verify(pam.fprint.retrying);
        compare(pam.fprint.starts, 1);
    }

    function test_faultBeforeTimeoutStillSpendsErrorBudget() {
        const pam = lockedPam();
        pam.fprint.deliverMessage();
        // halfway to the PAM timeout is a device fault, not an expiry
        pam.fprint.attemptStartedAt = Date.now() - pam.fprint.sessionTimeoutMs / 2;
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.errorTries, 1);
        compare(pam.fprintState, "error");
        verify(pam.fprint.retrying);
        compare(pam.fprint.starts, 1);
    }

    // VerifyStart is asynchronous: pam_fprintd arms its deadline before the call
    // and the message lands afterwards, so an ordinary expiry reads a little short
    // of the timeout here and must still renew rather than back off.
    function test_expiryShortenedByVerifyStartStillRenews() {
        const pam = lockedPam();
        pam.fprint.deliverMessage();
        pam.fprint.attemptStartedAt = Date.now() - (pam.fprint.sessionTimeoutMs - 900);
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.errorTries, 0);
        compare(pam.fprint.starts, 2);
        compare(pam.fprintState, "");
    }

    function test_faultJustBeforeTimeoutStillSpendsErrorBudget() {
        const pam = lockedPam();
        pam.fprint.deliverMessage();
        pam.fprint.attemptStartedAt = Date.now() - (pam.fprint.sessionTimeoutMs - pam.fprint.verifyStartSlackMs - 1000);
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprint.errorTries, 1);
        verify(pam.fprint.retrying);
        compare(pam.fprint.starts, 1);
    }

    function test_synchronousStartFailureAtErrorLimitCountsOnce() {
        const pam = lockedPam();
        pam.fprint.stop();
        pam.fprint.errorTries = pam.fprint.maxErrorTries - 1;
        pam.fprint.startFailsSynchronously = true;
        pam.fprint.checkAvail();
        compare(pam.fprint.errorTries, pam.fprint.maxErrorTries);
        compare(pam.fprint.status, "stopped");
        verify(!pam.fprint.retrying);
    }

    function test_backoffMessageFlashesOnceAndExpires() {
        const pam = lockedPam();
        pam.fprint.errorTries = 3;
        let flashes = 0;
        pam.flashMsg.connect(() => flashes++);
        pam.fprint.finish(PamResult.Error);
        compare(pam.fprintState, "error");
        compare(flashes, 0);
        tryCompare(pam, "fprintState", "", 5000);
        verify(pam.fprint.retrying);
    }

}
