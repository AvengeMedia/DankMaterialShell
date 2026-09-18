import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash

Column {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var eventData: null
    property date initialDate: new Date()

    signal saved
    signal closeRequested

    property string fTitle: ""
    property bool fAllDay: false
    property date fDate: initialDate
    property string fStart: "10:00"
    property string fEnd: "11:00"
    property string fLocation: ""
    property string fDescription: ""
    property string fCalendarId: ""
    property int fReminder: -1
    property string errorText: ""
    property bool saving: false

    readonly property var _cals: CalendarService.writableCalendars()
    readonly property var _remLabels: [I18n.tr("No reminder"), I18n.tr("At start"), I18n.tr("%1 before", "calendar reminder option, %1 is a duration such as 15 minutes").arg(I18n.duration(300)), I18n.tr("%1 before", "calendar reminder option, %1 is a duration such as 15 minutes").arg(I18n.duration(600)), I18n.tr("%1 before", "calendar reminder option, %1 is a duration such as 15 minutes").arg(I18n.duration(900)), I18n.tr("%1 before", "calendar reminder option, %1 is a duration such as 15 minutes").arg(I18n.duration(1800)), I18n.tr("%1 before", "calendar reminder option, %1 is a duration such as 15 minutes").arg(I18n.duration(3600)), I18n.tr("%1 before", "calendar reminder option, %1 is a duration such as 15 minutes").arg(I18n.duration(86400))]
    readonly property var _remMins: [-1, 0, 5, 10, 15, 30, 60, 1440]

    spacing: Theme.spacingM

    function _parseTime(value) {
        const m = value.trim().match(/^(\d{1,2}):(\d{2})$/);
        if (!m)
            return null;
        const h = parseInt(m[1]);
        const min = parseInt(m[2]);
        if (h > 23 || min > 59)
            return null;
        return {
            "h": h,
            "m": min
        };
    }

    function _isoFromDateTime(dateObj, h, m) {
        const d = new Date(dateObj);
        d.setHours(h, m, 0, 0);
        return d.toISOString();
    }

    function _allDayIso(dateObj, dayOffset) {
        return new Date(Date.UTC(dateObj.getFullYear(), dateObj.getMonth(), dateObj.getDate() + dayOffset)).toISOString();
    }

    function _calendarName(id) {
        for (let i = 0; i < _cals.length; i++) {
            if (_cals[i].id === id)
                return _cals[i].name;
        }
        return _cals.length > 0 ? _cals[0].name : "";
    }

    function shiftDate(days) {
        const d = new Date(fDate);
        d.setDate(d.getDate() + days);
        fDate = d;
    }

    function save() {
        const title = fTitle.trim();
        if (!title) {
            errorText = I18n.tr("Title is required");
            return;
        }
        let calId = fCalendarId;
        if (!calId) {
            const def = CalendarService.defaultCalendar();
            calId = def ? def.id : "";
        }
        if (!calId) {
            errorText = I18n.tr("No writable calendar available");
            return;
        }
        let startIso, endIso;
        if (fAllDay) {
            startIso = _allDayIso(fDate, 0);
            endIso = _allDayIso(fDate, 1);
        } else {
            const s = _parseTime(fStart);
            const e = _parseTime(fEnd);
            if (!s || !e) {
                errorText = I18n.tr("Use HH:MM time format");
                return;
            }
            startIso = _isoFromDateTime(fDate, s.h, s.m);
            endIso = _isoFromDateTime(fDate, e.h, e.m);
            if (new Date(endIso).getTime() <= new Date(startIso).getTime()) {
                errorText = I18n.tr("End must be after start");
                return;
            }
        }
        const fields = {
            "calendarId": calId,
            "summary": title,
            "description": fDescription,
            "location": fLocation,
            "start": startIso,
            "end": endIso,
            "allDay": fAllDay,
            "reminders": fReminder >= 0 ? [
                {
                    "method": "popup",
                    "minutes": fReminder
                }
            ] : []
        };
        saving = true;
        errorText = "";
        const cb = response => {
            saving = false;
            if (response.error) {
                errorText = response.error;
                return;
            }
            root.saved();
        };
        if (eventData && eventData.id)
            CalendarService.updateEvent(eventData.id, fields, cb);
        else
            CalendarService.createEvent(fields, cb);
    }

    Component.onCompleted: {
        if (!eventData) {
            fCalendarId = CalendarService.defaultCalendar() ? CalendarService.defaultCalendar().id : "";
            return;
        }
        fTitle = eventData.title || "";
        fAllDay = !!eventData.allDay;
        fDate = eventData.start;
        fStart = Qt.formatTime(eventData.start, "HH:mm");
        fEnd = Qt.formatTime(eventData.end, "HH:mm");
        fLocation = eventData.location || "";
        fDescription = eventData.description || "";
        fCalendarId = eventData.calendarId || "";
        if (eventData.reminders && eventData.reminders.length > 0)
            fReminder = eventData.reminders[0].minutes;
    }

    DankFlickable {
        width: parent.width
        height: Math.min(DashMetrics.sheetFormHeight, form.implicitHeight)
        contentWidth: width
        contentHeight: form.implicitHeight
        clip: true

        Column {
            id: form
            width: parent.width
            spacing: Theme.spacingS

            DankTextField {
                width: parent.width
                labelText: I18n.tr("Title")
                leftIconName: "title"
                leftIconSize: Theme.iconSizeSmall
                placeholderText: I18n.tr("Event title")
                text: root.fTitle
                onTextChanged: root.fTitle = text
            }

            DankToggle {
                width: parent.width
                text: I18n.tr("All day")
                checked: root.fAllDay
                onToggled: checked => root.fAllDay = checked
            }

            Row {
                width: parent.width
                spacing: Theme.spacingXS

                DankActionButton {
                    id: prevDay
                    iconName: I18n.isRtl ? "chevron_right" : "chevron_left"
                    Accessible.name: I18n.tr("Previous")
                    iconSize: Theme.iconSizeSmall
                    onClicked: root.shiftDate(-1)
                }

                StyledText {
                    width: parent.width - prevDay.width - nextDay.width - parent.spacing * 2
                    text: Qt.formatDate(root.fDate, "ddd, MMM d yyyy")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    height: Theme.buttonHeightXS
                }

                DankActionButton {
                    id: nextDay
                    iconName: I18n.isRtl ? "chevron_left" : "chevron_right"
                    Accessible.name: I18n.tr("Next")
                    iconSize: Theme.iconSizeSmall
                    onClicked: root.shiftDate(1)
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS
                visible: !root.fAllDay

                DankTextField {
                    width: (parent.width - Theme.spacingS) / 2
                    labelText: I18n.tr("Start")
                    leftIconName: "schedule"
                    leftIconSize: Theme.iconSizeSmall
                    placeholderText: "HH:MM"
                    text: root.fStart
                    onTextChanged: root.fStart = text
                }

                DankTextField {
                    width: (parent.width - Theme.spacingS) / 2
                    labelText: I18n.tr("End")
                    placeholderText: "HH:MM"
                    text: root.fEnd
                    onTextChanged: root.fEnd = text
                }
            }

            DankDropdown {
                width: parent.width
                text: I18n.tr("Calendar")
                options: root._cals.map(c => c.name)
                currentValue: root._calendarName(root.fCalendarId)
                onValueChanged: value => {
                    for (let i = 0; i < root._cals.length; i++) {
                        if (root._cals[i].name === value) {
                            root.fCalendarId = root._cals[i].id;
                            return;
                        }
                    }
                }
            }

            DankDropdown {
                width: parent.width
                text: I18n.tr("Reminder", "noun, calendar event reminder time dropdown label")
                options: root._remLabels
                currentValue: root._remLabels[Math.max(0, root._remMins.indexOf(root.fReminder))]
                onValueChanged: value => {
                    const idx = root._remLabels.indexOf(value);
                    if (idx >= 0)
                        root.fReminder = root._remMins[idx];
                }
            }

            DankTextField {
                width: parent.width
                labelText: I18n.tr("Location", "calendar event venue field label", true)
                leftIconName: "place"
                leftIconSize: Theme.iconSizeSmall
                placeholderText: I18n.tr("Add location")
                text: root.fLocation
                onTextChanged: root.fLocation = text
            }

            DankTextField {
                width: parent.width
                labelText: I18n.tr("Notes", "noun, calendar event notes field label")
                leftIconName: "notes"
                leftIconSize: Theme.iconSizeSmall
                placeholderText: I18n.tr("Add notes")
                text: root.fDescription
                onTextChanged: root.fDescription = text
            }
        }
    }

    StyledText {
        width: parent.width
        text: root.errorText
        visible: root.errorText !== ""
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS
        layoutDirection: Qt.RightToLeft

        DankButton {
            text: root.saving ? I18n.tr("Saving...") : I18n.tr("Save")
            iconName: "check"
            buttonHeight: Theme.buttonHeightS
            backgroundColor: Theme.primary
            textColor: Theme.onPrimary
            enabled: !root.saving
            onClicked: root.save()
        }

        DankButton {
            text: I18n.tr("Cancel")
            buttonHeight: Theme.buttonHeightS
            onClicked: root.closeRequested()
        }
    }
}
