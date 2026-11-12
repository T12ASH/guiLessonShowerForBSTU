import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: control
    anchors.fill: parent
    color: "#121214"

    property real uiScale: 1.0
    property string defaultGroup: "О-25-ИСТ-ииап-Б"
    property string selectedGroupDraft: ""
    property string selectedPeriodDraft: ""

    signal requestGroupPicker()
    signal requestPeriodPicker()
    signal requestRetry()
    signal requestDownload(string group, string period)

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 28, 360)
        spacing: 14

        Rectangle {
            Layout.preferredWidth: Math.round(68 * control.uiScale)
            Layout.preferredHeight: Math.round(68 * control.uiScale)
            radius: 16
            color: "#1c1c22"
            border.color: "#2e2e38"
            Layout.alignment: Qt.AlignHCenter
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 8
                source: "../icons/app.svg"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: i18n.t("title")
                font.bold: true
                font.pixelSize: Math.round(20 * control.uiScale)
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: i18n.t("first_launch_prompt")
                font.pixelSize: Math.round(13 * control.uiScale)
                color: "#a1a1aa"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#27272a"
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        ColumnLayout {
            visible: scheduleManager.isLoadingMeta && scheduleManager.availableGroups.length === 0
            Layout.fillWidth: true
            spacing: 12

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: true
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: i18n.t("loading_groups")
                font.pixelSize: Math.round(13 * control.uiScale)
                color: "#a1a1aa"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        ColumnLayout {
            visible: !scheduleManager.isLoadingMeta && scheduleManager.availableGroups.length === 0
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: Math.round(44 * control.uiScale)
                Layout.preferredHeight: Math.round(44 * control.uiScale)
                radius: 22
                color: "#27272a"
                Layout.alignment: Qt.AlignHCenter

                Image {
                    anchors.centerIn: parent
                    width: Math.round(18 * control.uiScale)
                    height: Math.round(18 * control.uiScale)
                    source: "../icons/close.svg"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: i18n.t("network_error_title")
                font.bold: true
                font.pixelSize: Math.round(15 * control.uiScale)
                color: "#f87171"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: i18n.t("network_error_desc")
                font.pixelSize: Math.round(12 * control.uiScale)
                color: "#a1a1aa"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Button {
                id: initialRetryBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.topMargin: 4
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
                        text: i18n.t("retry")
                        font.bold: true
                        font.pixelSize: Math.round(14 * control.uiScale)
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                background: Rectangle {
                    color: initialRetryBtn.pressed ? "#be123c" : "#e11d48"
                    radius: 8
                }

                onClicked: control.requestRetry()
            }
        }

        ColumnLayout {
            visible: scheduleManager.availableGroups.length > 0
            Layout.fillWidth: true
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    text: i18n.t("group")
                    font.bold: true
                    font.pixelSize: Math.round(13 * control.uiScale)
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                Button {
                    id: initialGroupSelectorBtn
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
                        color: "#1c1c22"
                        radius: 8
                        border.color: initialGroupSelectorBtn.pressed ? "#e11d48" : "#2e2e38"
                        border.width: 1.5
                    }

                    onClicked: control.requestGroupPicker()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    text: i18n.t("period")
                    font.bold: true
                    font.pixelSize: Math.round(13 * control.uiScale)
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                Button {
                    id: initialPeriodSelectorBtn
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
                        color: "#1c1c22"
                        radius: 8
                        border.color: initialPeriodSelectorBtn.pressed ? "#e11d48" : "#2e2e38"
                        border.width: 1.5
                    }

                    onClicked: control.requestPeriodPicker()
                }
            }

            Button {
                id: startBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Layout.topMargin: 6
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
                        text: scheduleManager.isRefreshing ? i18n.t("loading") : i18n.t("download_schedule")
                        font.bold: true
                        font.pixelSize: Math.round(15 * control.uiScale)
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                background: Rectangle {
                    color: startBtn.pressed ? "#be123c" : "#e11d48"
                    radius: 10
                }

                onClicked: {
                    var grp = control.selectedGroupDraft.trim()
                    if (grp === "") {
                        grp = control.defaultGroup
                    }
                    var per = control.selectedPeriodDraft.trim()
                    if (per === "") {
                        per = scheduleManager.period
                    }
                    control.requestDownload(grp, per)
                }
            }

            Text {
                visible: scheduleManager.statusMessage !== ""
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: scheduleManager.statusMessage
                color: "#f87171"
                font.pixelSize: Math.round(12 * control.uiScale)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
