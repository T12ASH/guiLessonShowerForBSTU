import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "Translations.js" as Translations

ApplicationWindow {
    id: root
    visible: true
    readonly property bool isMobile: Qt.platform.os === "android" || Qt.platform.os === "ios"
    width: isMobile ? Screen.width : Math.min(480, Screen.desktopAvailableWidth > 0 ?
        Screen.desktopAvailableWidth : 480)
    height: isMobile ? Screen.height : Math.min(720, Screen.desktopAvailableHeight > 0 ?
        Screen.desktopAvailableHeight : 720)
    minimumWidth: isMobile ? 0 : 260
    minimumHeight: isMobile ? 0 : 420
    title: i18n.t("title")
    color: "#121214"
    palette.window: "#121214"
    palette.windowText: "#ffffff"
    palette.base: "#18181b"
    palette.text: "#ffffff"
    palette.placeholderText: "#71717a"
    palette.button: "#27272a"
    palette.buttonText: "#ffffff"

    readonly property real zoom: scheduleManager.uiScalePercent / 100
    readonly property real logicalWidth: root.width / root.zoom

    readonly property bool isCompact: root.logicalWidth < 430
    readonly property real uiScale: Math.min(1.0, Math.max(0.80, root.logicalWidth / 390.0))

    readonly property string defaultGroup: "О-25-ИСТ-ииап-Б"

    property string selectedGroupDraft: scheduleManager.group !== "" ? scheduleManager.group : defaultGroup
    property string selectedPeriodDraft: scheduleManager.period

    property date currentTime: new Date()

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentTime = new Date()
        }
    }

    readonly property int realTodayIndex: {
        var jsDay = root.currentTime.getDay()
        return (jsDay === 0) ? 6 : (jsDay - 1)
    }

    property int currentDayIndex: root.realTodayIndex
    readonly property bool isViewingToday: (root.currentDayIndex === root.realTodayIndex && scheduleManager.weekParity === scheduleManager.calculateCurrentWeekParity())

    readonly property var currentDayData: {
        if (scheduleManager.scheduleDays.length > root.currentDayIndex) {
            return scheduleManager.scheduleDays[root.currentDayIndex]
        }
        return null
    }

    ScheduleManager {
        id: scheduleManager
    }

    Updater {
        id: appUpdater

        onUpdateReadyChanged: {
            if (appUpdater.updateReady) {
                updateDialog.open()
            }
        }

        onCriticalErrorThresholdReached: {
            updateDialog.open()
        }
    }

    Component.onCompleted: {
        if (!scheduleManager.hasSchedule) {
            scheduleManager.onSettingsOpened()
        }
        appUpdater.checkForUpdates()
    }

    QtObject {
        id: i18n
        readonly property string lang: (scheduleManager && scheduleManager.language) ? scheduleManager.language : "ru"

        function t(key) { return Translations.t(lang, key) }
        function dayShort(idx) { return Translations.dayShort(lang, idx) }
        function dayFull(idx) { return Translations.dayFull(lang, idx) }
        function translateType(rawType) { return Translations.translateType(lang, rawType) }
        function formatRoom(room) { return Translations.formatRoom(lang, room) }
    }

    Item {
        id: scaledRoot
        width: parent.width / root.zoom
        height: parent.height / root.zoom
        scale: root.zoom
        transformOrigin: Item.TopLeft

        SetupScreen {
            id: setupScreen
            visible: !scheduleManager.hasSchedule
            uiScale: root.uiScale
            defaultGroup: root.defaultGroup
            selectedGroupDraft: root.selectedGroupDraft
            selectedPeriodDraft: root.selectedPeriodDraft

            onRequestGroupPicker: groupPickerPopup.open()
            onRequestPeriodPicker: periodPickerPopup.open()
            onRequestRetry: scheduleManager.onSettingsOpened()
            onRequestDownload: function(grp, per) {
                root.selectedGroupDraft = grp
                root.selectedPeriodDraft = per
                scheduleManager.setGroup(grp)
                scheduleManager.setPeriod(per)
                scheduleManager.refreshSchedule()
            }
        }

        ScheduleView {
            id: scheduleView
            visible: scheduleManager.hasSchedule
            uiScale: root.uiScale
            isCompact: root.isCompact
            currentDayIndex: root.currentDayIndex
            isViewingToday: root.isViewingToday
            currentDayData: root.currentDayData
            currentTime: root.currentTime
            updater: appUpdater

            onDaySelected: function(idx) {
                root.currentDayIndex = idx
            }
            onRequestOpenSettings: {
                root.selectedGroupDraft = scheduleManager.group !== "" ? scheduleManager.group : root.defaultGroup
                root.selectedPeriodDraft = scheduleManager.period
                settingsDialog.open()
            }
        }
    }

    GroupPickerPopup {
        id: groupPickerPopup
        z: 10
        uiScale: root.uiScale
        selectedGroup: root.selectedGroupDraft
        onGroupSelected: function(grpName) {
            root.selectedGroupDraft = grpName
        }
    }

    PeriodPickerPopup {
        id: periodPickerPopup
        z: 10
        uiScale: root.uiScale
        selectedPeriod: root.selectedPeriodDraft
        onPeriodSelected: function(periodCode) {
            root.selectedPeriodDraft = periodCode
        }
    }

    SettingsDialog {
        id: settingsDialog
        uiScale: root.uiScale
        defaultGroup: root.defaultGroup
        selectedGroupDraft: root.selectedGroupDraft
        selectedPeriodDraft: root.selectedPeriodDraft
        updater: appUpdater

        onRequestGroupPicker: groupPickerPopup.open()
        onRequestPeriodPicker: periodPickerPopup.open()
    }

    UpdateDialog {
        id: updateDialog
        z: 20
        uiScale: root.uiScale
        updater: appUpdater
    }

    ScaleConfirmPopup {
        id: scaleConfirmPopup
        z: 30
    }
}