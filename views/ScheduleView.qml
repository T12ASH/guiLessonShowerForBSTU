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
    property var updater: null

    signal requestOpenSettings()
    signal daySelected(int index)

    function stepDay(delta) {
            const next = control.currentDayIndex + delta
            if (next < 0) {
                scheduleManager.setWeekParity(scheduleManager.oppositeWeekParity())
                control.daySelected(6)
            } else if (next > 6) {
                scheduleManager.setWeekParity(scheduleManager.oppositeWeekParity())
                control.daySelected(0)
            } else {
                control.daySelected(next)
            }
    }

    Keys.onLeftPressed: control.stepDay(-1)
    Keys.onRightPressed: control.stepDay(1)

    onCurrentDayIndexChanged: {
        if (daySwipeView.initialized && !daySwipeView.isTeleporting) {
            const targetPage = currentDayIndex + 1
            if (daySwipeView.currentIndex !== targetPage) {
                daySwipeView.setCurrentIndex(targetPage)
            }
        }
    }

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

                Rectangle {
                    visible: control.updater && control.updater.updateReady
                    width: 8
                    height: 8
                    radius: 4
                    color: "#34d399"
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 2
                    anchors.rightMargin: 2
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

    SwipeView {
            id: daySwipeView
            visible: scheduleManager.hasSchedule
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12

            property bool initialized: false
            property bool isTeleporting: false

            function teleportAcrossWeek(newDayIndex, newPageIndex) {
                isTeleporting = true

                const nextParity = scheduleManager.oppositeWeekParity()
                scheduleManager.setWeekParity(nextParity)
                control.daySelected(newDayIndex)

                const lv = daySwipeView.contentItem
                const prevDur = lv ? lv.highlightMoveDuration : -1
                if (lv) {
                    lv.highlightMoveDuration = 0
                }
                daySwipeView.setCurrentIndex(newPageIndex)
                if (lv && lv.positionViewAtIndex) {
                    lv.positionViewAtIndex(newPageIndex, ListView.SnapPosition)
                }

                Qt.callLater(function() {
                    if (lv) {
                        lv.highlightMoveDuration = prevDur
                    }
                    isTeleporting = false
                })
            }

            function handleEdgeWrap() {
                if (!initialized || isTeleporting) return

                if (currentIndex === 8) {
                    teleportAcrossWeek(0, 1)
                } else if (currentIndex === 0) {
                    teleportAcrossWeek(6, 7)
                }
            }

            Component.onCompleted: {
                const lv = daySwipeView.contentItem
                const prevDur = lv ? lv.highlightMoveDuration : -1
                if (lv) lv.highlightMoveDuration = 0

                const startPage = control.currentDayIndex + 1
                currentIndex = startPage
                if (lv && lv.positionViewAtIndex) {
                    lv.positionViewAtIndex(startPage, ListView.SnapPosition)
                }

                Qt.callLater(function() {
                    if (lv) lv.highlightMoveDuration = prevDur
                    initialized = true
                })
            }

            onCurrentIndexChanged: {
                if (!initialized || isTeleporting) return

                if (currentIndex >= 1 && currentIndex <= 7) {
                    const targetDay = currentIndex - 1
                    if (control.currentDayIndex !== targetDay) {
                        control.daySelected(targetDay)
                    }
                } else if (contentItem && !contentItem.moving && !contentItem.dragging) {
                    handleEdgeWrap()
                }
            }

            Connections {
                target: daySwipeView.contentItem
                function onMovementEnded() {
                    daySwipeView.handleEdgeWrap()
                }
            }

            Repeater {
                model: 9

                Item {
                    id: dayPage
                    required property int index

                    readonly property bool isEdgePage: (index === 0 || index === 8)
                    readonly property int dayIdx: (index === 0) ? 6 : (index === 8 ? 0 : index - 1)
                    readonly property string pageParity: isEdgePage
                                                         ? scheduleManager.oppositeWeekParity()
                                                         : scheduleManager.weekParity

                    readonly property var lessonsList: {
                        const days = scheduleManager.scheduleDays
                        if (!isEdgePage) {
                            return (days && days.length > dayIdx) ? days[dayIdx].lessons : []
                        }
                        return scheduleManager.lessonsForDay(dayIdx, pageParity)
                    }

                    readonly property int todayWeekdayIndex: (control.currentTime.getDay() + 6) % 7
                    readonly property bool isPageToday: (dayIdx === todayWeekdayIndex)
                                                        && (pageParity === scheduleManager.calculateCurrentWeekParity())

                    ListView {
                        id: listView
                        visible: dayPage.lessonsList.length > 0
                        anchors.fill: parent
                        clip: true
                        spacing: 8
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        model: dayPage.lessonsList

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: LessonCard {
                            lessonData: modelData
                            uiScale: control.uiScale
                            isCompact: control.isCompact
                            isViewingToday: dayPage.isPageToday
                            currentTime: control.currentTime
                        }
                    }

                    Rectangle {
                        visible: dayPage.lessonsList.length === 0
                        anchors.fill: parent
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
            }
        }


}
