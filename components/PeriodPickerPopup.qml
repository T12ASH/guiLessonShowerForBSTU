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
    height: Math.min(parent ? parent.height - 48 : 420, 440)
    padding: 16
    leftPadding: 16
    rightPadding: 16
    topPadding: 16
    bottomPadding: 16
    leftInset: 0
    rightInset: 0
    topInset: 0
    bottomInset: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property real uiScale: 1.0
    property string selectedPeriod: ""
    signal periodSelected(string periodCode)

    background: Rectangle {
        color: "#18181b"
        radius: 16
        border.color: "#2e2e38"
        border.width: 1.5
    }

    contentItem: ColumnLayout {
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: i18n.t("period")
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
                id: closePeriodPickerBtn
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
                    color: closePeriodPickerBtn.pressed ? "#3f3f46" : "#27272a"
                    radius: 16
                }
                onClicked: control.close()
            }
        }

        ListView {
            id: periodListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: scheduleManager.availablePeriods

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Button {
                id: perItemBtn
                width: periodListView.width
                height: 48
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

                readonly property bool isSelected: modelData.value === control.selectedPeriod

                contentItem: Item {
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 5
                        anchors.bottomMargin: 5
                        spacing: 1

                        Text {
                            text: modelData.label
                            color: perItemBtn.isSelected ? "#ffffff" : "#e4e4e7"
                            font.bold: true
                            font.pixelSize: Math.round(13 * control.uiScale)
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.value
                            color: perItemBtn.isSelected ? "#fecdd3" : "#a1a1aa"
                            font.pixelSize: Math.round(11 * control.uiScale)
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                        }
                    }
                }

                background: Rectangle {
                    color: perItemBtn.isSelected ? "#e11d48" : (perItemBtn.pressed ? "#27272a" : "#121214")
                    radius: 8
                    border.color: perItemBtn.isSelected ? "#e11d48" : "#27272a"
                }

                onClicked: {
                    control.periodSelected(modelData.value)
                    scheduleManager.fetchGroupsForPeriod(modelData.value)
                    control.close()
                }
            }
        }
    }
}
