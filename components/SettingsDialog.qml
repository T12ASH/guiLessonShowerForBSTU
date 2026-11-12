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

    signal requestGroupPicker()
    signal requestPeriodPicker()

    onOpened: {
        scheduleManager.onSettingsOpened()
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: i18n.t("language")
                font.bold: true
                font.pixelSize: Math.round(13 * control.uiScale)
                color: "#ffffff"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { code: "ru", label: "RU" },
                        { code: "en", label: "EN" },
                        { code: "de", label: "DE" },
                        { code: "fr", label: "FR" }
                    ]

                    Button {
                        id: langBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
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
                                text: modelData.label
                                font.bold: true
                                font.pixelSize: Math.round(12 * control.uiScale)
                                color: (i18n.lang === modelData.code) ? "#ffffff" : "#a1a1aa"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        background: Rectangle {
                            color: (i18n.lang === modelData.code) ? "#e11d48" : "#121214"
                            radius: 8
                            border.color: (i18n.lang === modelData.code) ? "#e11d48" : "#2e2e38"
                        }

                        onClicked: {
                            scheduleManager.setLanguage(modelData.code)
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
