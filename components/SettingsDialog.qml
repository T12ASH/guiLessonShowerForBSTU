import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: control
    parent: Overlay.overlay
    modal: true
    dim: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(parent ? parent.width - 24 : 360, 380)
    padding: 18
    leftPadding: 18
    rightPadding: 18
    topPadding: 18
    bottomPadding: 18
    leftInset: 0
    rightInset: 0
    topInset: 0
    bottomInset: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property real uiScale: 1.0
    property string defaultGroup: "О-25-ИСТ-ииап-Б"
    property string selectedGroupDraft: ""
    property string selectedPeriodDraft: ""
    property var updater: null

    signal requestGroupPicker()
    signal requestPeriodPicker()

    onOpened: {
        scheduleManager.onSettingsOpened()
    }

    onClosed: {
        langPopup.close()
    }

    background: Rectangle {
        color: "#18181b"
        radius: 16
        border.color: "#2e2e38"
        border.width: 1.5
    }

    contentItem: ColumnLayout {
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Image {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                source: "../icons/settings.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                text: i18n.t("group_settings")
                font.bold: true
                font.pixelSize: Math.round(16 * control.uiScale)
                color: "#ffffff"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Button {
                id: dialogCloseBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                padding: 0
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                horizontalPadding: 0
                verticalPadding: 0
                leftInset: 0
                rightInset: 0
                topInset: 0
                bottomInset: 0

                contentItem: Item {
                    Image {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: "../icons/close.svg"
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }
                }

                background: Rectangle {
                    color: dialogCloseBtn.pressed ? "#3f3f46" : "#27272a"
                    radius: 16
                }

                onClicked: control.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#27272a"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: i18n.t("languages")
                font.bold: true
                font.pixelSize: Math.round(13 * control.uiScale)
                color: "#ffffff"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Button {
                id: langDropdownBtn
                Layout.preferredWidth: Math.round(92 * control.uiScale)
                Layout.preferredHeight: 38
                hoverEnabled: true
                padding: 0
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                horizontalPadding: 0
                verticalPadding: 0
                leftInset: 0
                rightInset: 0
                topInset: 0
                bottomInset: 0

                contentItem: Item {
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 6

                        Text {
                            text: (i18n.lang ? i18n.lang.toUpperCase() : "RU")
                            font.bold: true
                            font.pixelSize: Math.round(13 * control.uiScale)
                            color: "#ffffff"
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        Image {
                            Layout.preferredWidth: 12
                            Layout.preferredHeight: 12
                            source: "../icons/arrow_down.svg"
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                background: Rectangle {
                    color: "#121214"
                    radius: 8
                    border.color: (langDropdownBtn.pressed || langPopup.opened) ? "#e11d48" : (langDropdownBtn.hovered ? "#3f3f46" : "#2e2e38")
                    border.width: 1.5
                }

                onClicked: langPopup.open()

                Popup {
                    id: langPopup
                    parent: langDropdownBtn
                    x: langDropdownBtn.width - width
                    y: langDropdownBtn.height + 4
                    width: Math.round(150 * control.uiScale)
                    z: 100
                    padding: 6
                    modal: true
                    dim: false
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                    background: Rectangle {
                        color: "#18181b"
                        radius: 10
                        border.color: "#2e2e38"
                        border.width: 1.5
                    }

                    contentItem: ColumnLayout {
                        spacing: 4

                        Repeater {
                            model: [
                                { code: "ru", name: "Русский", short: "RU" },
                                { code: "en", name: "English", short: "EN" },
                                { code: "de", name: "Deutsch", short: "DE" },
                                { code: "fr", name: "Français", short: "FR" }
                            ]

                            Button {
                                id: langItemBtn
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                hoverEnabled: true
                                padding: 0
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                horizontalPadding: 0
                                verticalPadding: 0
                                leftInset: 0
                                rightInset: 0
                                topInset: 0
                                bottomInset: 0

                                contentItem: Item {
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Text {
                                            text: modelData.name
                                            font.bold: (i18n.lang === modelData.code)
                                            font.pixelSize: Math.round(13 * control.uiScale)
                                            color: (i18n.lang === modelData.code) ? "#ffffff" : "#a1a1aa"
                                            Layout.fillWidth: true
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Text {
                                            text: modelData.short
                                            font.bold: true
                                            font.pixelSize: Math.round(11 * control.uiScale)
                                            color: (i18n.lang === modelData.code) ? "#e11d48" : "#71717a"
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                background: Rectangle {
                                    color: langItemBtn.pressed ? "#27272a" : (langItemBtn.hovered ? "#222226" : (i18n.lang === modelData.code ? "#27272a" : "transparent"))
                                    radius: 6
                                }

                                onClicked: {
                                    scheduleManager.setLanguage(modelData.code)
                                    langPopup.close()
                                }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: i18n.t("group")
                font.bold: true
                font.pixelSize: Math.round(13 * control.uiScale)
                color: "#ffffff"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                elide: Text.ElideRight
            }

            Button {
                id: dialogGroupSelectorBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                padding: 0
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                horizontalPadding: 0
                verticalPadding: 0
                leftInset: 0
                rightInset: 0
                topInset: 0
                bottomInset: 0

                contentItem: Item {
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: control.selectedGroupDraft !== "" ? control.selectedGroupDraft : control.defaultGroup
                            color: "#ffffff"
                            font.pixelSize: Math.round(14 * control.uiScale)
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Image {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: "../icons/arrow_down.svg"
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                background: Rectangle {
                    color: "#121214"
                    radius: 8
                    border.color: dialogGroupSelectorBtn.pressed ? "#e11d48" : "#2e2e38"
                    border.width: 1.5
                }

                onClicked: control.requestGroupPicker()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: i18n.t("period")
                font.bold: true
                font.pixelSize: Math.round(13 * control.uiScale)
                color: "#ffffff"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                elide: Text.ElideRight
            }

            Button {
                id: dialogPeriodSelectorBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                padding: 0
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                horizontalPadding: 0
                verticalPadding: 0
                leftInset: 0
                rightInset: 0
                topInset: 0
                bottomInset: 0

                contentItem: Item {
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: control.selectedPeriodDraft !== ""
                                  ? scheduleManager.periodLabel(control.selectedPeriodDraft)
                                  : i18n.t("period_placeholder")
                            color: control.selectedPeriodDraft !== "" ? "#ffffff" : "#71717a"
                            font.pixelSize: Math.round(13 * control.uiScale)
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Image {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: "../icons/arrow_down.svg"
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                background: Rectangle {
                    color: "#121214"
                    radius: 8
                    border.color: dialogPeriodSelectorBtn.pressed ? "#e11d48" : "#2e2e38"
                    border.width: 1.5
                }

                onClicked: control.requestPeriodPicker()
            }
        }

        // App update section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Image {
                    Layout.preferredWidth: Math.round(18 * control.uiScale)
                    Layout.preferredHeight: Math.round(18 * control.uiScale)
                    source: "../icons/updater.svg"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }

                Text {
                    text: i18n.t("app_update")
                    font.bold: true
                    font.pixelSize: Math.round(13 * control.uiScale)
                    color: "#ffffff"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: control.updater ? control.updater.currentVersion : ""
                    font.pixelSize: Math.round(12 * control.uiScale)
                    color: "#a1a1aa"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 8
                color: "#121214"
                border.color: (control.updater && control.updater.updateReady) ? "#34d399" : "#2e2e38"
                border.width: 1.5
                implicitHeight: updateCardCol.implicitHeight + 16

                ColumnLayout {
                    id: updateCardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!control.updater) return ""
                                if (control.updater.isChecking) return i18n.t("checking_updates")
                                if (control.updater.isDownloading) return i18n.t("downloading_update") + " (" + Math.round(control.updater.downloadProgress * 100) + "%)"
                                if (control.updater.updateReady) return i18n.t("new_version_available") + control.updater.newVersion
                                if (control.updater.hasCriticalError) return i18n.t("critical_update_error")
                                if (control.updater.statusMessage === "Update cache cleared.") return i18n.t("cache_cleared")
                                if (control.updater.statusMessage === "Application is up-to-date.") return i18n.t("up_to_date")
                                if (control.updater.statusMessage !== "") return control.updater.statusMessage
                                return i18n.t("up_to_date")
                            }
                            font.pixelSize: Math.round(12 * control.uiScale)
                            color: {
                                if (!control.updater) return "#a1a1aa"
                                if (control.updater.updateReady) return "#34d399"
                                if (control.updater.hasCriticalError) return "#f87171"
                                return "#a1a1aa"
                            }
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        visible: control.updater && control.updater.hasCriticalError
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            id: criticalOpenReleasesBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            padding: 0
                            contentItem: Item {
                                Text {
                                    anchors.fill: parent
                                    text: i18n.t("open_releases")
                                    font.bold: true
                                    font.pixelSize: Math.round(12 * control.uiScale)
                                    color: "#ffffff"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            background: Rectangle {
                                color: criticalOpenReleasesBtn.pressed ? "#be123c" : "#e11d48"
                                radius: 6
                            }
                            onClicked: {
                                const url = (control.updater && control.updater.releasePage !== "")
                                    ? control.updater.releasePage
                                    : "https://github.com/T12ASH/guiLessonShowerForBSTU/releases"
                                Qt.openUrlExternally(url)
                            }
                        }

                        Button {
                            id: criticalResetBtn
                            Layout.preferredWidth: Math.round(110 * control.uiScale)
                            Layout.preferredHeight: 32
                            padding: 0
                            contentItem: Item {
                                Text {
                                    anchors.fill: parent
                                    text: i18n.t("reset_errors")
                                    font.pixelSize: Math.round(11 * control.uiScale)
                                    color: "#a1a1aa"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            background: Rectangle {
                                color: criticalResetBtn.pressed ? "#3f3f46" : "#27272a"
                                radius: 6
                            }
                            onClicked: {
                                if (control.updater) control.updater.resetFailureCount()
                            }
                        }
                    }

                    ProgressBar {
                        visible: control.updater && control.updater.isDownloading
                        Layout.fillWidth: true
                        from: 0.0
                        to: 1.0
                        value: control.updater ? control.updater.downloadProgress : 0.0
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            id: checkOrInstallBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            padding: 0
                            enabled: control.updater && !control.updater.isChecking && !control.updater.isDownloading

                            contentItem: Item {
                                Text {
                                    anchors.fill: parent
                                    text: {
                                        if (!control.updater) return ""
                                        if (control.updater.updateReady) return i18n.t("install_now")
                                        if (control.updater.isChecking) return i18n.t("loading")
                                        return i18n.t("check_updates")
                                    }
                                    font.bold: true
                                    font.pixelSize: Math.round(12 * control.uiScale)
                                    color: "#ffffff"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            background: Rectangle {
                                color: {
                                    if (control.updater && control.updater.updateReady) {
                                        return checkOrInstallBtn.pressed ? "#059669" : "#10b981"
                                    }
                                    return checkOrInstallBtn.pressed ? "#3f3f46" : "#27272a"
                                }
                                radius: 6
                            }

                            onClicked: {
                                if (!control.updater) return
                                if (control.updater.updateReady) {
                                    control.updater.installUpdate()
                                } else {
                                    control.updater.checkForUpdates()
                                }
                            }
                        }

                        Button {
                            id: clearUpdateCacheBtn
                            Layout.preferredWidth: Math.round(100 * control.uiScale)
                            Layout.preferredHeight: 36
                            padding: 0
                            enabled: control.updater && !control.updater.isDownloading && (control.updater.hasCache || control.updater.updateReady || control.updater.updateFilePath !== "")

                            contentItem: Item {
                                Text {
                                    anchors.fill: parent
                                    text: i18n.t("clear_cache")
                                    font.pixelSize: Math.round(11 * control.uiScale)
                                    color: clearUpdateCacheBtn.enabled ? "#ef4444" : "#52525b"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            background: Rectangle {
                                color: clearUpdateCacheBtn.pressed ? "#27272a" : "transparent"
                                border.color: clearUpdateCacheBtn.enabled ? "#7f1d1d" : "#27272a"
                                border.width: 1
                                radius: 6
                            }

                            onClicked: {
                                if (control.updater) {
                                    control.updater.cleanCache()
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#27272a"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.minimumWidth: 0
                            text: i18n.t("receive_test_versions")
                            font.pixelSize: Math.round(12 * control.uiScale)
                            color: "#d4d4d8"
                            wrapMode: Text.WordWrap
                            verticalAlignment: Text.AlignVCenter

                            MouseArea {
                                anchors.fill: parent
                                enabled: control.updater !== null && control.updater !== undefined
                                onClicked: {
                                    control.updater.setReceiveTestVersions(!receiveTestSwitch.checked)
                                }
                            }
                        }

                        Switch {
                            id: receiveTestSwitch
                            Layout.preferredWidth: Math.round(42 * control.uiScale)
                            Layout.preferredHeight: Math.round(24 * control.uiScale)
                            Layout.minimumWidth: Layout.preferredWidth
                            Layout.maximumWidth: Layout.preferredWidth
                            Layout.alignment: Qt.AlignVCenter
                            padding: 0
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            horizontalPadding: 0
                            verticalPadding: 0
                            leftInset: 0
                            rightInset: 0
                            topInset: 0
                            bottomInset: 0
                            spacing: 0
                            checked: control.updater ? control.updater.receiveTestVersions : false
                            enabled: control.updater !== null && control.updater !== undefined
                            hoverEnabled: true

                            indicator: Rectangle {
                                x: 0
                                y: 0
                                width: receiveTestSwitch.width
                                height: receiveTestSwitch.height
                                radius: height / 2
                                color: receiveTestSwitch.checked ? "#e11d48" : "#27272a"
                                border.color: receiveTestSwitch.checked
                                              ? "#fb7185"
                                              : (receiveTestSwitch.hovered ? "#52525b" : "#3f3f46")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    x: receiveTestSwitch.checked ? parent.width - width - 3 : 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.height - 6
                                    height: width
                                    radius: width / 2
                                    color: receiveTestSwitch.checked ? "#ffffff" : "#a1a1aa"

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }
                                }
                            }

                            contentItem: Item {
                                implicitWidth: 0
                                implicitHeight: 0
                            }

                            onToggled: {
                                if (control.updater) {
                                    control.updater.setReceiveTestVersions(checked)
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { icon: "../icons/telegram.svg", url: "https://t.me/NischevoTeam" },
                    { icon: "../icons/github.svg", url: "https://github.com/T12ASH/guiLessonShowerForBSTU" },
                    { icon: "../icons/codeberg.svg", url: "https://codeberg.org/overlord_zpyxkhtnvorplimbex/cliLessonShowerForBSTU" }
                ]

                Button {
                    id: linkBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    hoverEnabled: true
                    padding: 0
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    horizontalPadding: 0
                    verticalPadding: 0
                    leftInset: 0
                    rightInset: 0
                    topInset: 0
                    bottomInset: 0

                    contentItem: Item {
                        Image {
                            anchors.centerIn: parent
                            width: Math.round(20 * control.uiScale)
                            height: Math.round(20 * control.uiScale)
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }
                    }

                    background: Rectangle {
                        color: linkBtn.pressed ? "#27272a" : (linkBtn.hovered ? "#1f1f23" : "#121214")
                        radius: 8
                        border.color: linkBtn.pressed ? "#e11d48" : (linkBtn.hovered ? "#3f3f46" : "#2e2e38")
                        border.width: 1.5
                    }

                    onClicked: {
                        Qt.openUrlExternally(modelData.url)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Button {
                id: dialogCancelBtn
                Layout.preferredWidth: Math.round(96 * control.uiScale)
                Layout.preferredHeight: 44
                padding: 0
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                horizontalPadding: 0
                verticalPadding: 0
                leftInset: 0
                rightInset: 0
                topInset: 0
                bottomInset: 0

                contentItem: Item {
                    Text {
                        anchors.fill: parent
                        text: i18n.t("cancel")
                        font.pixelSize: Math.round(14 * control.uiScale)
                        color: "#a1a1aa"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                background: Rectangle {
                    color: dialogCancelBtn.pressed ? "#3f3f46" : "#27272a"
                    radius: 8
                }

                onClicked: control.close()
            }

            Button {
                id: dialogSaveBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                padding: 0
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                horizontalPadding: 0
                verticalPadding: 0
                leftInset: 0
                rightInset: 0
                topInset: 0
                bottomInset: 0
                enabled: !scheduleManager.isRefreshing

                contentItem: Item {
                    Text {
                        anchors.fill: parent
                        text: scheduleManager.isRefreshing ? i18n.t("loading") : i18n.t("save")
                        font.bold: true
                        font.pixelSize: Math.round(14 * control.uiScale)
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                background: Rectangle {
                    color: dialogSaveBtn.pressed ? "#be123c" : "#e11d48"
                    radius: 8
                }

                onClicked: {
                    var grp = control.selectedGroupDraft.trim()
                    var per = control.selectedPeriodDraft.trim()
                    if (grp !== "") scheduleManager.setGroup(grp)
                    if (per !== "") scheduleManager.setPeriod(per)
                    scheduleManager.refreshSchedule()
                    control.close()
                }
            }
        }
    }
}
