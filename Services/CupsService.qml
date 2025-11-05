pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root
    
    property int refCount: 0

    property var printerNames: []
    property var printers: []
    property string selectedPrinter: ""
    
    property bool cupsAvailable: false
    property bool stateInitialized: false

    signal cupsStateUpdate

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    Component.onCompleted: {
        if (socketPath && socketPath.length > 0) {
            checkDMSCapabilities()
        }
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkDMSCapabilities()
            }
        }
    }
    
    Connections {
        target: DMSService
        enabled: DMSService.isConnected

        function onCupsStateUpdate(data) {
            console.log("CupsService: Subscription update received")
            updateState(data)
        }

        function onCapabilitiesChanged() {
            checkDMSCapabilities()
        }
    }
    
    function checkDMSCapabilities() {
        if (!DMSService.isConnected) {
            return
        }

        if (DMSService.capabilities.length === 0) {
            return
        }

        cupsAvailable = DMSService.capabilities.includes("cups")

        if (cupsAvailable && !stateInitialized) {
            stateInitialized = true
            getState()
        }
    }

    function getState() {
        if (!cupsAvailable) return

        DMSService.sendRequest("cups.getState", null, response => {
            if (response.result) {
                updateState(response.result)
            }
        })
    }

    function updateState(state) {
        printerNames = Object.keys(state.printers)
        if (printerNames.length > 0) {
            if (selectedPrinter.length > 0) {
                if (!printerNames.includes(selectedPrinter)) {
                    selectedPrinter = printerNames[0]
                }
            } else {
                selectedPrinter = printerNames[0]
            }
        }
        printers = state.printers
    }
    
    function getSelectedPrinter() {
        return selectedPrinter
    }
    
    function setSelectedPrinter(printerName) {
        if (printerNames.length > 0) {
            if (printerNames.includes(printerName)) {
                selectedPrinter = printerName
            } else {
                selectedPrinter = printerNames[0]
            }
        }
    }
    
    function getPrintersNum() {
        if (!cupsAvailable) return 0

        return printerNames.length
    }
    
    function getPrintersNames() {
        if (!cupsAvailable) return []
        
        return printerNames
    }
    
    function getTotalJobsNum() {
        if (!cupsAvailable) return 0

        var result = 0
        for (var i = 0; i < printerNames.length; i++) {
            var printerName = printerNames[i]
            if (printers[printerName] && printers[printerName].jobs) {
                result += printers[printerName].jobs.length
            }
        }
        return result
    }
    
    function getCurrentPrinterState() {
        if (!cupsAvailable || !selectedPrinter) return ""
        
        var printer = printers[selectedPrinter]
        return printer.state
    }

    function getCurrentPrinterStatePrettyShort() {
        if (!cupsAvailable || !selectedPrinter) return ""
        
        var printer = printers[selectedPrinter]
        return getPrinterStateTranslation(printer.state) + 
            " (" + getPrinterStateReasonTranslation(printer.stateReason) + ")"
    }

    function getCurrentPrinterStatePretty() {
        if (!cupsAvailable || !selectedPrinter) return ""
        
        var printer = printers[selectedPrinter]
        return getPrinterStateTranslation(printer.state) + 
            " (" + I18n.tr("Reason") + ": " + getPrinterStateReasonTranslation(printer.stateReason) + ")"
    }

    function getCurrentPrinterJobs() {
        if (!cupsAvailable || !selectedPrinter) return []
        
        return getJobs(selectedPrinter)
    }

    function getJobs(printerName) {
        if (!cupsAvailable) return ""

        var printer = printers[printerName]
        return printer.jobs
    }
    
    function getJobsNum(printerName) {
        if (!cupsAvailable) return 0

        var printer = printers[printerName]
        return printer.jobs.length
    }

    function pausePrinter(printerName) {
        if (!cupsAvailable) return

        const params = {
            printerName: printerName
        }

        DMSService.sendRequest("cups.pausePrinter", params, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to pause printer") + " - " + response.error)
            }
        })
    }

    function resumePrinter(printerName) {
        if (!cupsAvailable) return

        const params = {
            printerName: printerName
        }

        DMSService.sendRequest("cups.resumePrinter", params, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to resume printer") + " - " + response.error)
            }
        })
    }

    function cancelJob(jobid) {
        if (!cupsAvailable) return

        const params = {
            jobid: jobid
        }

        DMSService.sendRequest("cups.cancelJob", params, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to cancel selected job") + " - " + response.error)
            }
        })
    }

    function purgeJobs(printerName) {
        if (!cupsAvailable) return

        const params = {
            printerName: printerName
        }

        DMSService.sendRequest("cups.purgeJobs", params, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to cancel all jobs") + " - " + response.error)
            }
        })
    }
    
    readonly property var states: ({
        "idle": I18n.tr("Idle"),
        "processing": I18n.tr("Processing"),
        "stopped": I18n.tr("Stopped")
    })

    readonly property var reasonsGeneral: ({
        "none": I18n.tr("None"),
        "other": I18n.tr("Other")
    })

    readonly property var reasonsSupplies: ({
        "toner-low": I18n.tr("Toner Low"),
        "toner-empty": I18n.tr("Toner Empty"),
        "marker-supply-low": I18n.tr("Marker Supply Low"),
        "marker-supply-empty": I18n.tr("Marker Supply Empty"),
        "marker-waste-almost-full": I18n.tr("Marker Waste Almost Full"),
        "marker-waste-full": I18n.tr("Marker Waste Full")
    })

    readonly property var reasonsMedia: ({
        "media-low": I18n.tr("Media Low"),
        "media-empty": I18n.tr("Media Empty"),
        "media-needed": I18n.tr("Media Needed"),
        "media-jam": I18n.tr("Media Jam")
    })

    readonly property var reasonsParts: ({
        "cover-open": I18n.tr("Cover Open"),
        "door-open": I18n.tr("Door Open"),
        "interlock-open": I18n.tr("Interlock Open"),
        "output-tray-missing": I18n.tr("Output Tray Missing"),
        "output-area-almost-full": I18n.tr("Output Area Almost Full"),
        "output-area-full": I18n.tr("Output Area Full")
    })

    readonly property var reasonsErrors: ({
        "paused": I18n.tr("Paused"),
        "shutdown": I18n.tr("Shutdown"),
        "connecting-to-device": I18n.tr("Connecting to Device"),
        "timed-out": I18n.tr("Timed Out"),
        "stopping": I18n.tr("Stopping"),
        "stopped-partly": I18n.tr("Stopped Partly")
    })

    readonly property var reasonsService: ({
        "spool-area-full": I18n.tr("Spool Area Full"),
        "cups-missing-filter-warning": I18n.tr("CUPS Missing Filter Warning"),
        "cups-insecure-filter-warning": I18n.tr("CUPS Insecure Filter Warning")
    })

    readonly property var reasonsConnectivity: ({
        "offline-report": I18n.tr("Offline Report"),
        "moving-to-paused": I18n.tr("Moving to Paused")
    })

    readonly property var severitySuffixes: ({
        "-error": I18n.tr("Error"),
        "-warning": I18n.tr("Warning"),
        "-report": I18n.tr("Report")
    })

    function getPrinterStateTranslation(state) {
        return states[state] || state
    }

    function getPrinterStateReasonTranslation(reason) {
        let allReasons = Object.assign({},
            reasonsGeneral,
            reasonsSupplies,
            reasonsMedia,
            reasonsParts,
            reasonsErrors,
            reasonsService,
            reasonsConnectivity
        )
        
        let basReason = reason
        let suffix = ""
        
        for (let s in severitySuffixes) {
            if (reason.endsWith(s)) {
                basReason = reason.slice(0, -s.length)
                suffix = severitySuffixes[s]
                break
            }
        }
        
        let translation = allReasons[basReason] || basReason
        return suffix ? translation + " (" + suffix + ")" : translation
    }
}
