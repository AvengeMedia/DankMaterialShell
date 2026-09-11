.pragma library

// A calendar date with no time and no timezone.
//
// Arithmetic runs through Date.UTC, which has no DST gaps, so day and month
// rollover is exact. Instances are immutable: every operation returns a new one.
// month is 0-based, matching Javascripts' Date behavior.

class DateOnly {
    constructor(year, month, day) {
        this.year = year;
        this.month = month;
        this.day = day;
    }

    addDays(days) {
        return _fromUtc(new Date(Date.UTC(this.year, this.month, this.day + days)));
    }

    addMonths(months) {
        const target = new Date(Date.UTC(this.year, this.month + months, 1));
        const lastDay = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();
        return new DateOnly(target.getUTCFullYear(), target.getUTCMonth(), Math.min(this.day, lastDay));
    }

    // 0 = Sunday, matching Date.getDay().
    dayOfWeek() {
        return new Date(Date.UTC(this.year, this.month, this.day)).getUTCDay();
    }

    daysUntil(other) {
        const from = Date.UTC(this.year, this.month, this.day);
        const to = Date.UTC(other.year, other.month, other.day);
        return Math.round((to - from) / 86400000);
    }

    equals(other) {
        if (!other)
            return false;
        return this.year === other.year && this.month === other.month && this.day === other.day;
    }

    // Local noon, so consumers that read local calendar fields land on this date
    // even on days where local midnight does not exist.
    toDate() {
        return new Date(this.year, this.month, this.day, 12);
    }
}

function _fromUtc(date) {
    return new DateOnly(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function of(year, month, day) {
    return new DateOnly(year, month, day);
}

function fromDate(date) {
    return new DateOnly(date.getFullYear(), date.getMonth(), date.getDate());
}

function firstOfMonth(year, month) {
    return new DateOnly(year, month, 1);
}

function lastOfMonth(year, month) {
    return _fromUtc(new Date(Date.UTC(year, month + 1, 0)));
}
