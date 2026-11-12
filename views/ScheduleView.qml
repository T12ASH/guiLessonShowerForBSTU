import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control
    anchors.fill: parent
    anchors.margins: isCompact ? 8 : 12
    spacing: isCompact ? 8 : 10
    focus: true

    property real uiScale: 1.0
    property bool isCompact: false
    property int currentDayIndex: 0
    property bool isViewingToday: false
    property var currentDayData: null
    property date currentTime: new Date()

    signal requestOpenSettings()
    signal daySelected(int index)

    Keys.onLeftPressed: control.daySelected((control.currentDayIndex - 1 + 7) % 7)
    Keys.onRightPressed: control.daySelected((control.currentDayIndex + 1) % 7)

    RowLayout {
        Layout.fillWidth: true
        spacing: control.isCompact ? 6 : 10

        Rectangle {
            Layout.preferredWidth: Math.round(36 * control.uiScale)
            Layout.preferredHeight: Math.round(36 * control.uiScale)
            radius: 8
            color: "#1c1c22"
            border.color: "#2e2e38"
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 3
                source: "../icons/app.svg"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            spacing: 1

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: i18n.t("title")
                font.bold: true
                font.pixelSize: Math.round(15 * control.uiScale)
                color: "#ffffff"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: scheduleManager.statusMessage !== "" ? scheduleManager.statusMessage : i18n.t("not_updated")
                font.pixelSize: Math.round(11 * control.uiScale)
                color: "#9ca3af"
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Button {
            id: refreshBtn
            Layout.preferredHeight: Math.round(36 * control.uiScale)
            Layout.preferredWidth: Math.round((control.isCompact ? 82 : 96) * control.uiScale)
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
                    text: scheduleManager.isRefreshing ? i18n.t("loading") : i18n.t("update")
                    font.bold: true
                    font.pixelSize: Math.round(12 * control.uiScale)
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            background: Rectangle {
                color: refreshBtn.pressed ? "#be123c" : "#e11d48"
                radius: 8
            }

            onClicked: {
                scheduleManager.refreshSchedule()
            }
        }

        Button {
            id: settingsBtn
            Layout.preferredWidth: Math.round(36 * control.uiScale)
            Layout.preferredHeight: Math.round(36 * control.uiScale)
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
                    width: Math.round(18 * control.uiScale)
                    height: Math.round(18 * control.uiScale)
                    source: "../icons/settings.svg"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }

            background: Rectangle {
                color: settingsBtn.pressed ? "#3f3f46" : "#27272a"
                radius: 8
                border.color: "#3f3f46"
            }

            onClicked: {
                control.requestOpenSettings()
            }
        }
    }

    DaySelectorBar {
        uiScale: control.uiScale
        isCompact: control.isCompact
        currentDayIndex: control.currentDayIndex
        isViewingToday: control.isViewingToday
        currentDayData: control.currentDayData
        onDaySelected: function(idx) {
            control.daySelected(idx)
        }
    }

    ScrollView {
        id: scrollView
        visible: control.currentDayData && control.currentDayData.lessons.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ListView {
            id: listView
            width: scrollView.availableWidth
            spacing: 8
            model: control.currentDayData ? control.currentDayData.lessons : []

            delegate: LessonCard {
                lessonData: modelData
                uiScale: control.uiScale
                isCompact: control.isCompact
                isViewingToday: control.isViewingToday
                currentTime: control.currentTime
            }
        }
    }

    Rectangle {
        visible: scheduleManager.hasSchedule && (!control.currentDayData || control.currentDayData.lessons.length === 0)
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: "#18181b"
        radius: 12
        border.color: "#27272a"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 26
                color: "#27272a"
                Layout.alignment: Qt.AlignHCenter

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: "../icons/dash.svg"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: i18n.t("day_off_title")
                font.bold: true
                font.pixelSize: Math.round(17 * control.uiScale)
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: i18n.t("no_lessons_day")
                color: "#a1a1aa"
                font.pixelSize: Math.round(13 * control.uiScale)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }
        }
    }
}
