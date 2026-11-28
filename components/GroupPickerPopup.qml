import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: control
    parent: Overlay.overlay
    modal: true
    dim: true
    x: parent ? (parent.width - width * zoom) / 2 : 0
    y: parent ? (parent.height - height * zoom) / 2 : 0
    width: Math.min(parent ? (parent.width - 24) / zoom : 360, 380)
    height: Math.min(parent ? (parent.height - 48) / zoom : 460, 480)
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
    readonly property real zoom: scheduleManager.uiScalePercent / 100
    scale: zoom
    transformOrigin: Popup.TopLeft
    property string selectedGroup: ""
    property string groupSearchQuery: ""
    signal groupSelected(string groupName)

    readonly property var filteredGroups: {
        var all = scheduleManager.availableGroups
        var q = groupSearchQuery.trim().toLowerCase()
        if (q === "") return all
        var res = []
        for (var i = 0; i < all.length; ++i) {
            if (all[i].toLowerCase().indexOf(q) !== -1) {
                res.push(all[i])
            }
        }
        return res
    }

    onOpened: {
        groupSearchQuery = ""
        groupSearchInput.text = ""
    }

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
                text: i18n.t("group")
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
                id: closeGroupPickerBtn
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
                    color: closeGroupPickerBtn.pressed ? "#3f3f46" : "#27272a"
                    radius: 16
                }
                onClicked: control.close()
            }
        }

        TextField {
            id: groupSearchInput
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            color: "#ffffff"
            selectedTextColor: "#ffffff"
            selectionColor: "#e11d48"
            palette.text: "#ffffff"
            font.pixelSize: Math.round(14 * control.uiScale)
            leftPadding: 12
            rightPadding: 12
            topPadding: 0
            bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter

            Text {
                text: i18n.t("group_placeholder")
                color: "#71717a"
                font: groupSearchInput.font
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                visible: !groupSearchInput.text && !groupSearchInput.inputMethodComposing
            }

            background: Rectangle {
                color: "#121214"
                radius: 8
                border.color: groupSearchInput.activeFocus ? "#e11d48" : "#2e2e38"
                border.width: 1.5
            }
            onTextChanged: {
                control.groupSearchQuery = text
            }
        }

        Button {
            id: useCustomGroupBtn
            visible: control.groupSearchQuery.trim() !== "" && control.filteredGroups.indexOf(control.groupSearchQuery.trim()) === -1
            Layout.fillWidth: true
            Layout.preferredHeight: 38
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
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: "+ " + control.groupSearchQuery.trim()
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: Math.round(13 * control.uiScale)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
            background: Rectangle {
                color: useCustomGroupBtn.pressed ? "#be123c" : "#e11d48"
                radius: 8
            }
            onClicked: {
                control.groupSelected(control.groupSearchQuery.trim())
                control.close()
            }
        }

        ColumnLayout {
            visible: scheduleManager.isLoadingMeta && scheduleManager.availableGroups.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: true
            }

            Text {
                Layout.fillWidth: true
                text: i18n.t("loading_groups")
                font.pixelSize: Math.round(13 * control.uiScale)
                color: "#a1a1aa"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        ListView {
            id: groupListView
            visible: scheduleManager.availableGroups.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: control.filteredGroups

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Button {
                id: grpItemBtn
                width: groupListView.width
                height: 42
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

                readonly property bool isSelected: modelData === control.selectedGroup

                contentItem: Item {
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: modelData
                            color: grpItemBtn.isSelected ? "#ffffff" : "#e4e4e7"
                            font.bold: grpItemBtn.isSelected
                            font.pixelSize: Math.round(14 * control.uiScale)
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Image {
                            visible: grpItemBtn.isSelected
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: "../icons/check.svg"
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                background: Rectangle {
                    color: grpItemBtn.isSelected ? "#e11d48" : (grpItemBtn.pressed ? "#27272a" : "#121214")
                    radius: 8
                    border.color: grpItemBtn.isSelected ? "#e11d48" : "#27272a"
                }

                onClicked: {
                    control.groupSelected(modelData)
                    control.close()
                }
            }
        }
    }
}
