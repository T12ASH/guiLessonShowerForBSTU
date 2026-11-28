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
    width: Math.min(parent ? (parent.width - 24) / zoom : 360, 390)
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
    readonly property real zoom: scheduleManager.uiScalePercent / 100
    scale: zoom
    transformOrigin: Popup.TopLeft
    property var updater: null
    readonly property var activeUpdater: updater ? updater : (typeof appUpdater !== "undefined" ? appUpdater : null)
    readonly property bool isCritical: activeUpdater ? activeUpdater.hasCriticalError : false
    property bool actionTaken: false

    onAboutToShow: {
        actionTaken = false
    }

    onClosed: {
        if (!actionTaken && activeUpdater && activeUpdater.updateReady) {
            activeUpdater.postponeUpdate()
        }
    }

    background: Rectangle {
        color: "#18181b"
        radius: 16
        border.color: control.isCritical ? "#ef4444" : "#2e2e38"
        border.width: 1.5
    }

    contentItem: ColumnLayout {
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Image {
                Layout.preferredWidth: Math.round(22 * control.uiScale)
                Layout.preferredHeight: Math.round(22 * control.uiScale)
                source: "../icons/updater.svg"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }

            Text {
                text: control.isCritical ? i18n.t("critical_update_error_title") : i18n.t("update_ready_title")
                font.bold: true
                font.pixelSize: Math.round(16 * control.uiScale)
                color: control.isCritical ? "#f87171" : "#ffffff"
                Layout.fillWidth: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Button {
                id: dialogCloseBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                padding: 0
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
                onClicked: {
                    if (control.activeUpdater && control.activeUpdater.updateReady) {
                        control.activeUpdater.postponeUpdate()
                    }
                    control.actionTaken = true
                    control.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#27272a"
        }

        Rectangle {
            visible: !control.isCritical
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(38 * control.uiScale)
            radius: 8
            color: "#121214"
            border.color: "#2e2e38"
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: control.activeUpdater ? control.activeUpdater.currentVersion : ""
                    font.bold: true
                    font.pixelSize: Math.round(13 * control.uiScale)
                    color: "#a1a1aa"
                }

                Text {
                    text: "→"
                    font.bold: true
                    font.pixelSize: Math.round(13 * control.uiScale)
                    color: "#e11d48"
                }

                Text {
                    text: control.activeUpdater ? control.activeUpdater.newVersion : ""
                    font.bold: true
                    font.pixelSize: Math.round(14 * control.uiScale)
                    color: "#34d399"
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: control.isCritical ? i18n.t("critical_update_error_desc") : i18n.t("update_ready_desc")
            font.pixelSize: Math.round(12 * control.uiScale)
            color: control.isCritical ? "#fca5a5" : "#9ca3af"
            wrapMode: Text.WordWrap
        }

        Rectangle {
            visible: !control.isCritical && control.activeUpdater && control.activeUpdater.changelog !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(130, changelogText.implicitHeight + 16)
            radius: 8
            color: "#121214"
            border.color: "#27272a"
            border.width: 1
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: changelogText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Text {
                    id: changelogText
                    width: parent.width - 10
                    text: control.activeUpdater ? control.activeUpdater.changelog : ""
                    font.pixelSize: Math.round(11 * control.uiScale)
                    color: "#d4d4d8"
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            visible: !control.isCritical
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Button {
                id: clearCacheBtn
                Layout.preferredWidth: Math.round(76 * control.uiScale)
                Layout.preferredHeight: 40
                padding: 0
                contentItem: Item {
                    Text {
                        anchors.fill: parent
                        text: i18n.t("clear_cache")
                        font.pixelSize: Math.round(11 * control.uiScale)
                        color: "#ef4444"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                background: Rectangle {
                    color: clearCacheBtn.pressed ? "#27272a" : (clearCacheBtn.hovered ? "#1f1f23" : "transparent")
                    border.color: clearCacheBtn.pressed ? "#ef4444" : "#3f3f46"
                    border.width: 1
                    radius: 8
                }
                onClicked: {
                    control.actionTaken = true
                    if (control.activeUpdater) control.activeUpdater.cleanCache()
                    control.close()
                }
            }

            Button {
                id: postponeBtn
                Layout.preferredWidth: Math.round(86 * control.uiScale)
                Layout.preferredHeight: 40
                padding: 0
                contentItem: Item {
                    Text {
                        elide: Text.ElideRight
                        anchors.fill: parent
                        text: i18n.t("postpone")
                        font.pixelSize: Math.round(13 * control.uiScale)
                        color: "#a1a1aa"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                background: Rectangle {
                    color: postponeBtn.pressed ? "#3f3f46" : "#27272a"
                    radius: 8
                }
                onClicked: {
                    control.actionTaken = true
                    if (control.activeUpdater) control.activeUpdater.postponeUpdate()
                    control.close()
                }
            }

            Button {
                id: installBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                padding: 0
                contentItem: Item {
                    Text {
                        elide: Text.ElideRight
                        anchors.fill: parent
                        text: i18n.t("install_now")
                        font.bold: true
                        font.pixelSize: Math.round(13 * control.uiScale)
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                background: Rectangle {
                    color: installBtn.pressed ? "#be123c" : "#e11d48"
                    radius: 8
                }
                onClicked: {
                    control.actionTaken = true
                    if (control.activeUpdater) control.activeUpdater.installUpdate()
                    control.close()
                }
            }
        }

        RowLayout {
            visible: control.isCritical
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Button {
                id: resetFailuresBtn
                Layout.preferredWidth: Math.round(120 * control.uiScale)
                Layout.preferredHeight: 40
                padding: 0
                contentItem: Item {
                    Text {
                        anchors.fill: parent
                        text: i18n.t("reset_errors")
                        font.pixelSize: Math.round(12 * control.uiScale)
                        color: "#a1a1aa"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                background: Rectangle {
                    color: resetFailuresBtn.pressed ? "#3f3f46" : "#27272a"
                    radius: 8
                }
                onClicked: {
                    control.actionTaken = true
                    if (control.activeUpdater) control.activeUpdater.resetFailureCount()
                    control.close()
                }
            }

            Button {
                id: openReleasesBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                padding: 0
                contentItem: Item {
                    Text {
                        elide: Text.ElideRight
                        anchors.fill: parent
                        text: i18n.t("open_releases")
                        font.bold: true
                        font.pixelSize: Math.round(13 * control.uiScale)
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                background: Rectangle {
                    color: openReleasesBtn.pressed ? "#be123c" : "#e11d48"
                    radius: 8
                }
                onClicked: {
                    control.actionTaken = true
                    const url = (control.activeUpdater && control.activeUpdater.releasePage !== "")
                        ? control.activeUpdater.releasePage
                        : "https://github.com/T12ASH/guiLessonShowerForBSTU/releases"
                    Qt.openUrlExternally(url)
                    control.close()
                }
            }
        }
    }
}
