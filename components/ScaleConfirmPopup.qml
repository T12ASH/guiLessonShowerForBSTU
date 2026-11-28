import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: control
    parent: Overlay.overlay
    modal: true
    dim: false
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? parent.height - height - 24 : 0
    width: Math.min(parent ? parent.width - 32 : 320, 340)
    padding: 16
    closePolicy: Popup.CloseOnEscape

    onClosed: scheduleManager.revertUiScale()

    Connections {
        target: scheduleManager
        function onPreviewSecondsLeftChanged() {
            if (scheduleManager.previewSecondsLeft > 0 && !control.opened)
                control.open()
                else if (scheduleManager.previewSecondsLeft === 0 && control.opened)
                    control.close()
        }
    }

    background: Rectangle {
        color: "#18181b"
        radius: 16
        border.color: "#2e2e38"
        border.width: 1.5
    }

    component ActionButton: Button {
        id: btn
        property color fillColor: "#27272a"
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        contentItem: Text {
            elide: Text.ElideRight
            text: btn.text
            color: "#ffffff"
            font.pixelSize: 15
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: btn.pressed ? Qt.darker(btn.fillColor, 1.2) : btn.fillColor
            radius: 10
        }
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: i18n.t("scale_confirm_title")
            font.pixelSize: 17
            font.bold: true
            color: "#ffffff"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Text {
            text: i18n.t("scale_auto_revert") + scheduleManager.previewSecondsLeft + " " + i18n.t("sec_short")
            font.pixelSize: 13
            color: "#a1a1aa"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ActionButton {
                text: i18n.t("scale_revert")
                onClicked: scheduleManager.revertUiScale()
            }
            ActionButton {
                text: i18n.t("scale_keep")
                fillColor: "#e11d48"
                onClicked: scheduleManager.confirmUiScale()
            }
        }
    }
}
