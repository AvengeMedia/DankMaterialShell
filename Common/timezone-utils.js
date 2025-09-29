// Import moment.js and moment-timezone
.import "moment.js" as MomentJS
.import "moment-timezone.js" as MomentTimezone

function getTimeInTimezone(timezone, use24Hour) {
    try {
        // Check if moment is available in global scope
        if (typeof moment !== 'undefined') {
            const format = use24Hour ? "HH:mm" : "h:mm A"
            return moment().tz(timezone).format(format)
        } else {
            return "moment.js not available"
        }
    } catch (e) {
        return "invalid timezone"
    }
}

function isMomentAvailable() {
    return typeof moment !== 'undefined'
}