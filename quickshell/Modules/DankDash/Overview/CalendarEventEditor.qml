import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
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
    readonly property var _remLabels: [I18n.tr("No reminder"), I18n.tr("At start"), I18n.tr("5 min before"), I18n.tr("10 min before"), I18n.tr("15 min before"), I18n.tr("30 min before"), I18n.tr("1 hour before"), I18n.tr("1 day before")]
    readonly property var _remMins: [-1, 0, 5, 10, 15, 30, 60, 1440]

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
        const fmt = "HH:mm";
        fStart = Qt.formatTime(eventData.start, fmt);
        fEnd = Qt.formatTime(eventData.end, fmt);
        fLocation = eventData.location || "";
        fDescription = eventData.description || "";
        fCalendarId = eventData.calendarId || "";
        if (eventData.reminders && eventData.reminders.length > 0)
            fReminder = eventData.reminders[0].minutes;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.spacingL * 2, 400)
        height: Math.min(parent.height - Theme.spacingM, 300)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.color: Theme.outlineMedium
        border.width: 1

        MouseArea {
            anchors.fill: parent
        }

        DankFlickable {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            contentWidth: width
            contentHeight: form.implicitHeight
            clip: true

            Column {
                id: form
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    width: parent.width
                    text: root.eventData ? I18n.tr("Edit event") : I18n.tr("New event")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignLeft
                }

                DankTextField {
                    width: parent.width
                    labelText: I18n.tr("Title")
                    leftIconName: "title"
                    leftIconSize: Theme.iconSize - 6
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
                        circular: false
                        iconName: "chevron_left"
                        iconSize: 16
                        onClicked: {
                            let d = new Date(root.fDate);
                            d.setDate(d.getDate() - 1);
                            root.fDate = d;
                        }
                    }

                    StyledText {
                        width: parent.width - 72
                        text: Qt.formatDate(root.fDate, "ddd, MMM d yyyy")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        height: 32
                    }

                    DankActionButton {
                        circular: false
                        iconName: "chevron_right"
                        iconSize: 16
                        onClicked: {
                            let d = new Date(root.fDate);
                            d.setDate(d.getDate() + 1);
                            root.fDate = d;
                        }
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
                        leftIconSize: Theme.iconSize - 6
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
                    text: I18n.tr("Reminder")
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
                    labelText: I18n.tr("Location")
                    leftIconName: "place"
                    leftIconSize: Theme.iconSize - 6
                    placeholderText: I18n.tr("Add location")
                    text: root.fLocation
                    onTextChanged: root.fLocation = text
                }

                DankTextField {
                    width: parent.width
                    labelText: I18n.tr("Notes")
                    leftIconName: "notes"
                    leftIconSize: Theme.iconSize - 6
                    placeholderText: I18n.tr("Add notes")
                    text: root.fDescription
                    onTextChanged: root.fDescription = text
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

                    DankButton {
                        text: root.saving ? I18n.tr("Saving…") : I18n.tr("Save")
                        iconName: "check"
                        buttonHeight: 32
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        enabled: !root.saving
                        onClicked: root.save()
                    }

                    DankButton {
                        text: I18n.tr("Cancel")
                        buttonHeight: 32
                        onClicked: root.closeRequested()
                    }
                }
            }
        }
    }
}
