pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.Common
import qs.Modules.Settings.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankDash.Wellbeing
import "../DankDash/Wellbeing/Wellbeing.js" as Wellbeing

Item {
    id: root

    property var parentModal: null
    property var days: []

    readonly property var limits: SettingsData.wellbeingAppLimits ?? {}
    readonly property var limitedApps: Object.keys(limits).filter(appId => Number(limits[appId]) > 0).sort((a, b) => WellbeingService.appName(a).localeCompare(WellbeingService.appName(b)))
    readonly property bool available: WellbeingService.available
    readonly property int revision: WellbeingService.revision
    readonly property int firstDayOfWeek: SettingsData.firstDayOfWeek >= 7 || SettingsData.firstDayOfWeek < 0 ? Qt.locale().firstDayOfWeek : SettingsData.firstDayOfWeek

    onAvailableChanged: refresh()
    onRevisionChanged: refresh()
    Component.onCompleted: refresh()

    function toggleLimit(appId) {
        WellbeingService.setAppLimit(appId, WellbeingService.appLimitMinutes(appId) > 0 ? 0 : WellbeingMetrics.defaultLimitMinutes);
    }

    function refresh() {
        if (!available)
            return;
        WellbeingService.summary(result => root.days = result);
    }

    ConfirmModal {
        id: clearConfirm
    }

    SettingsPage {
        SettingsCard {
            width: parent.width
            visible: root.available && SettingsData.wellbeingEnabled
            iconName: "show_chart"
            title: I18n.tr("Weekly screen time")
            settingKey: "wellbeingChart"
            tab: "wellbeing"
            tags: ["wellbeing", "screen time", "chart", "week"]

            WeeklyChart {
                height: WellbeingMetrics.chartHeight
                color: "transparent"
                pad: 0
                showTitle: false
                week: Wellbeing.weekDays(root.days, new Date(), root.firstDayOfWeek)
                limitSeconds: SettingsData.wellbeingDailyLimit * 60
            }
        }

        SettingsCard {
            width: parent.width
            visible: root.available && SettingsData.wellbeingEnabled
            iconName: "apps"
            title: I18n.tr("Most used apps")
            settingKey: "wellbeingApps"
            tab: "wellbeing"
            tags: ["wellbeing", "screen time", "apps", "usage"]

            AppUsageList {
                height: implicitHeight
                color: "transparent"
                pad: 0
                showTitle: false
                fillHeight: false
                days: root.days
                firstDayOfWeek: root.firstDayOfWeek
                onLimitRequested: appId => root.toggleLimit(appId)
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "digital_wellbeing"
            title: I18n.tr("Screen time")
            settingKey: "wellbeing"
            tab: "wellbeing"
            tags: ["wellbeing", "screen time", "usage", "limit"]

            SettingsToggleRow {
                settingKey: "wellbeingEnabled"
                tab: "wellbeing"
                tags: ["wellbeing", "screen time", "tracking"]
                text: I18n.tr("Track screen time")
                description: I18n.tr("Counts time in the focused app while the session is active. Stays on this device.")
                checked: SettingsData.wellbeingEnabled
                onToggled: checked => SettingsData.set("wellbeingEnabled", checked)
            }

            SettingsRow {
                settingKey: "wellbeingDailyLimit"
                tab: "wellbeing"
                tags: ["wellbeing", "screen time", "limit", "daily"]
                title: I18n.tr("Daily limit")
                subtitle: SettingsData.wellbeingDailyLimit > 0 ? I18n.tr("Notifies when today's screen time passes the limit") : I18n.tr("Off")

                DurationSteppers {
                    anchors.verticalCenter: parent.verticalCenter
                    minutes: SettingsData.wellbeingDailyLimit
                    onCommitted: next => SettingsData.set("wellbeingDailyLimit", next)
                }
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "timer"
            title: I18n.tr("App limits")
            settingKey: "wellbeingAppLimits"
            tab: "wellbeing"
            tags: ["wellbeing", "screen time", "limit", "app"]

            SettingsRow {
                visible: root.limitedApps.length === 0
                title: I18n.tr("No app limits")
                subtitle: I18n.tr("Pick an app from the list above or the dashboard tab")
            }

            Repeater {
                model: root.limitedApps

                SettingsRow {
                    id: limitRow

                    required property string modelData

                    settingKey: "wellbeingAppLimits:" + modelData
                    resetKeys: []
                    title: WellbeingService.appName(modelData)

                    leading: CcAppIcon {
                        appId: limitRow.modelData
                        iconSize: Theme.iconSizeLarge
                    }

                    DurationSteppers {
                        anchors.verticalCenter: parent.verticalCenter
                        minutes: WellbeingService.appLimitMinutes(limitRow.modelData)
                        onCommitted: next => WellbeingService.setAppLimit(limitRow.modelData, next)
                    }

                    DankActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "close"
                        iconColor: Theme.surfaceVariantText
                        Accessible.name: I18n.tr("Remove")
                        onClicked: WellbeingService.setAppLimit(limitRow.modelData, 0)
                    }
                }
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "history"
            title: I18n.tr("History")
            settingKey: "wellbeingHistory"
            tab: "wellbeing"
            tags: ["wellbeing", "screen time", "history", "clear"]

            SettingsRow {
                title: I18n.tr("Screen time history")
                subtitle: I18n.tr("Kept for %1 days on this device").arg(WellbeingMetrics.retentionDays)

                DankButton {
                    anchors.verticalCenter: parent.verticalCenter
                    buttonHeight: Theme.buttonHeightXS
                    text: I18n.tr("Clear")
                    backgroundColor: Theme.errorContainer
                    textColor: Theme.error
                    enabled: root.available
                    onClicked: clearConfirm.showWithOptions({
                        "title": I18n.tr("Clear History?"),
                        "message": I18n.tr("Deletes all stored screen time"),
                        "confirmText": I18n.tr("Clear"),
                        "confirmColor": Theme.error,
                        "onConfirm": () => {
                            WellbeingService.clearHistory();
                            root.days = [];
                        }
                    })
                }
            }
        }
    }
}
