import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card
    width: ListView.view ? ListView.view.width : parent.width
    implicitHeight: layout.implicitHeight + (isCompact ? 20 : 24)

    property var lessonData: null
    property real uiScale: 1.0
    property bool isCompact: false
    property bool isViewingToday: false
    property date currentTime: new Date()

    readonly property var statusInfo: {
        var timeStr = lessonData ? lessonData.time : ""
        if (!isViewingToday || !timeStr) {
            return { state: "normal", text: "", iconSource: "", badgeColor: "" }
        }

        var parts = timeStr.split("-")
        if (parts.length < 2) return { state: "normal", text: "", iconSource: "", badgeColor: "" }

        var startParts = parts[0].trim().split(":")
        var endParts = parts[1].trim().split(":")
        if (startParts.length < 2 || endParts.length < 2) return { state: "normal", text: "", iconSource: "", badgeColor: "" }

        var startSec = parseInt(startParts[0], 10) * 3600 + parseInt(startParts[1], 10) * 60
        var endSec = parseInt(endParts[0], 10) * 3600 + parseInt(endParts[1], 10) * 60

        var nowSec = currentTime.getHours() * 3600 +
                     currentTime.getMinutes() * 60 +
                     currentTime.getSeconds()

        if (nowSec >= startSec && nowSec < endSec) {
            var diffSec = endSec - nowSec
            var diffMin = Math.floor(diffSec / 60)
            var diffS = diffSec % 60
            var sStr = diffS < 10 ? "0" + diffS : diffS
            return {
                state: "current",
                text: i18n.t("lesson_in_progress") + diffMin + ":" + sStr,
                iconSource: "../icons/play_circle.svg",
                badgeColor: "#4ade80"
            }
        }

        if (nowSec < startSec && (startSec - nowSec) <= 15 * 60) {
            var untilSec = startSec - nowSec
            var untilMin = Math.floor(untilSec / 60)
            var untilS = untilSec % 60
            var uStr = untilS < 10 ? "0" + untilS : untilS
            return {
                state: "upcoming_soon",
                text: i18n.t("lesson_soon") + untilMin + ":" + uStr,
                iconSource: "../icons/hourglass.svg",
                badgeColor: "#fb923c"
            }
        }

        if (nowSec >= endSec) {
            return {
                state: "past",
                text: i18n.t("lesson_finished"),
                iconSource: "",
                badgeColor: "#9ca3af"
            }
        }

        return { state: "future", text: "", iconSource: "", badgeColor: "" }
    }

    opacity: statusInfo.state === "past" ? 0.5 : 1.0

    color: {
        if (statusInfo.state === "current") return "#13281c"
        if (statusInfo.state === "upcoming_soon") return "#2a1e10"
        if (statusInfo.state === "past") return "#16161a"
        return "#1c1c22"
    }
    radius: 10
    border.width: (statusInfo.state === "current" || statusInfo.state === "upcoming_soon") ? 2 : 1
    border.color: {
        if (statusInfo.state === "current") return "#22c55e"
        if (statusInfo.state === "upcoming_soon") return "#f59e0b"
        return "#2e2e38"
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: card.isCompact ? 10 : 12
        spacing: 6

        Rectangle {
            visible: card.statusInfo.text !== "" && card.statusInfo.state !== "past"
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            radius: 4
            color: card.statusInfo.state === "current" ? "#14532d" : "#7c2d12"

            RowLayout {
                anchors.centerIn: parent
                spacing: 5

                Image {
                    visible: card.statusInfo.iconSource !== ""
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    source: card.statusInfo.iconSource
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: card.statusInfo.text
                    font.bold: true
                    font.pixelSize: Math.round(11 * card.uiScale)
                    color: card.statusInfo.badgeColor
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: card.lessonData ? card.lessonData.time : ""
                font.bold: true
                font.pixelSize: Math.round(13 * card.uiScale)
                color: "#ffffff"
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                property string wType: card.lessonData ? card.lessonData.weekType : "all"
                color: wType === "all" ? "#27272a" : "#1e3a5f"
                radius: 4
                Layout.preferredHeight: 20
                Layout.preferredWidth: weekTypeLabel.contentWidth + 12

                Text {
                    id: weekTypeLabel
                    anchors.fill: parent
                    text: parent.wType === "all" ? i18n.t("all_weeks") : parent.wType
                    color: parent.wType === "all" ? "#a1a1aa" : "#60a5fa"
                    font.pixelSize: Math.round(10 * card.uiScale)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                property string rawType: card.lessonData ? card.lessonData.type : ""
                text: i18n.translateType(rawType)
                font.pixelSize: Math.round(11 * card.uiScale)
                font.bold: true
                color: "#93c5fd"
                visible: rawType !== ""
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            text: card.lessonData ? card.lessonData.name : ""
            font.bold: true
            font.pixelSize: Math.round(14 * card.uiScale)
            color: "#ffffff"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                property string teacherName: card.lessonData ? card.lessonData.teacher : ""
                text: teacherName
                font.pixelSize: Math.round(12 * card.uiScale)
                color: "#d4d4d8"
                visible: teacherName !== ""
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                property string roomName: card.lessonData ? card.lessonData.classRoom : ""
                text: i18n.formatRoom(roomName)
                font.pixelSize: Math.round(12 * card.uiScale)
                font.bold: true
                color: "#fde047"
                visible: roomName !== ""
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
