import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: control
    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + (isCompact ? 16 : 20)
    color: "#18181b"
    radius: 10
    border.color: "#27272a"
    border.width: 1

    property real uiScale: 1.0
    property bool isCompact: false
    property int currentDayIndex: 0
    property bool isViewingToday: false
    property var currentDayData: null

    signal daySelected(int index)

    ButtonGroup {
        id: parityGroup
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: control.isCompact ? 8 : 10
        spacing: control.isCompact ? 8 : 10

        GridLayout {
            Layout.fillWidth: true
            columns: control.isCompact ? 1 : 2
            rowSpacing: 8
            columnSpacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: i18n.t("week")
                    color: "#a1a1aa"
                    font.pixelSize: Math.round(12 * control.uiScale)
                    verticalAlignment: Text.AlignVCenter
                }

                Button {
                    id: oddBtn
                    text: i18n.t("odd")
                    checkable: true
                    checked: scheduleManager.weekParity === "не чет"
                    ButtonGroup.group: parityGroup
                    Layout.fillWidth: control.isCompact
                    Layout.preferredHeight: Math.round(34 * control.uiScale)
                    Layout.preferredWidth: Math.round(70 * control.uiScale)
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
                            elide: Text.ElideRight
                            anchors.fill: parent
                            text: oddBtn.text
                            font.pixelSize: Math.round(12 * control.uiScale)
                            font.bold: oddBtn.checked
                            color: oddBtn.checked ? "#ffffff" : "#a1a1aa"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    background: Rectangle {
                        color: oddBtn.checked ? "#e11d48" : "#27272a"
                        radius: 17
                    }

                    onClicked: {
                        scheduleManager.setWeekParity("не чет")
                    }
                }

                Button {
                    id: evenBtn
                    text: i18n.t("even")
                    checkable: true
                    checked: scheduleManager.weekParity === "чет"
                    ButtonGroup.group: parityGroup
                    Layout.fillWidth: control.isCompact
                    Layout.preferredHeight: Math.round(34 * control.uiScale)
                    Layout.preferredWidth: Math.round(58 * control.uiScale)
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
                            elide: Text.ElideRight
                            anchors.fill: parent
                            text: evenBtn.text
                            font.pixelSize: Math.round(12 * control.uiScale)
                            font.bold: evenBtn.checked
                            color: evenBtn.checked ? "#ffffff" : "#a1a1aa"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    background: Rectangle {
                        color: evenBtn.checked ? "#e11d48" : "#27272a"
                        radius: 17
                    }

                    onClicked: {
                        scheduleManager.setWeekParity("чет")
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Button {
                    id: prevDayBtn
                    Layout.preferredWidth: Math.round(34 * control.uiScale)
                    Layout.preferredHeight: Math.round(34 * control.uiScale)
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
                            width: Math.round(16 * control.uiScale)
                            height: Math.round(16 * control.uiScale)
                            source: "../icons/chevron_left.svg"
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }
                    }

                    background: Rectangle {
                        color: prevDayBtn.pressed ? "#3f3f46" : "#27272a"
                        radius: 17
                    }

                    onClicked: {
                        if (control.currentDayIndex === 0) {
                            scheduleManager.setWeekParity(scheduleManager.oppositeWeekParity())
                            control.daySelected(6)
                        } else {
                            control.daySelected(control.currentDayIndex - 1)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Math.round(34 * control.uiScale)
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.minimumWidth: 0
                        text: control.currentDayData ? i18n.dayFull(control.currentDayIndex) : ""
                        font.bold: true
                        font.pixelSize: Math.round(13 * control.uiScale)
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.minimumWidth: 0
                        text: {
                            if (control.isViewingToday) return i18n.t("today")
                            if (control.currentDayIndex === 6 || !control.currentDayData || control.currentDayData.lessons.length === 0) {
                                return i18n.t("day_off")
                            }
                            return i18n.t("school_day")
                        }
                        font.pixelSize: Math.round(10 * control.uiScale)
                        color: control.isViewingToday ? "#4ade80" : (control.currentDayIndex === 6 || !control.currentDayData || control.currentDayData.lessons.length === 0 ? "#71717a" : "#9ca3af")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                Button {
                    id: nextDayBtn
                    Layout.preferredWidth: Math.round(34 * control.uiScale)
                    Layout.preferredHeight: Math.round(34 * control.uiScale)
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
                            width: Math.round(16 * control.uiScale)
                            height: Math.round(16 * control.uiScale)
                            source: "../icons/chevron_right.svg"
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }
                    }

                    background: Rectangle {
                        color: nextDayBtn.pressed ? "#3f3f46" : "#27272a"
                        radius: 17
                    }

                    onClicked: {
                        if (control.currentDayIndex === 6) {
                            scheduleManager.setWeekParity(scheduleManager.oppositeWeekParity())
                            control.daySelected(0)
                        } else {
                            control.daySelected(control.currentDayIndex + 1)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: control.isCompact ? 3 : 4

            Repeater {
                model: [0, 1, 2, 3, 4, 5, 6]

                Button {
                    id: dayBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Math.round(32 * control.uiScale)
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
                            elide: Text.ElideRight
                            anchors.fill: parent
                            text: i18n.dayShort(modelData)
                            font.bold: true
                            font.pixelSize: Math.round(11 * control.uiScale)
                            color: (control.currentDayIndex === modelData) ? "#ffffff" : "#a1a1aa"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    background: Rectangle {
                        color: (control.currentDayIndex === modelData) ? "#e11d48" : "#27272a"
                        radius: 16
                    }

                    onClicked: {
                        control.daySelected(modelData)
                    }
                }
            }
        }
    }
}
