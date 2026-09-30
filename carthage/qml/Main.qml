// The window. Everything inside is App.qml, which dev mode reloads; changes here need a
// restart.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.ApplicationWindow {
    id: root
    visible: true
    color: Backend.theme.p.tray
    font.family: Ui.fontText  // standard controls (fields, menus) inherit the chosen font

    title: "Carthage"
    // Never larger than the free desktop area (a 1366×768 laptop, or 1080p at 125% scaling).
    width: Math.max(minimumWidth, Math.min(1180, Screen.desktopAvailableWidth - 40))
    height: Math.max(minimumHeight, Math.min(820, Screen.desktopAvailableHeight - 40))
    minimumWidth: 520
    minimumHeight: 480

    property int reloadCount: 0
    property string demoCommand: ""
    property Item searchField: null

    Binding {
        target: Backend.theme
        property: "hardware"
        value: Backend.settings.hardware
    }
    Binding {
        target: Backend.theme
        property: "cardColor"
        value: Backend.settings.cardColor
    }

    onReloadCountChanged: {
        contentLoader.source = ""
        contentLoader.source = Qt.resolvedUrl("App.qml")
    }
    onDemoCommandChanged: if (contentLoader.item) contentLoader.item.demo(JSON.parse(demoCommand))

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: if (root.searchField) root.searchField.forceActiveFocus()
    }
    Shortcut {
        sequences: [StandardKey.Quit]
        onActivated: Qt.quit()
    }
    Shortcut {
        sequences: [StandardKey.ZoomIn, "Ctrl+="]
        onActivated: Backend.settings.cardWidth = Math.min(240, Backend.settings.cardWidth + 18)
    }
    Shortcut {
        sequences: [StandardKey.ZoomOut]
        onActivated: Backend.settings.cardWidth = Math.max(114, Backend.settings.cardWidth - 18)
    }

    Loader {
        id: contentLoader
        anchors.fill: parent
        source: Qt.resolvedUrl("App.qml")
        focus: true
    }

    // App.qml calls Window.window.showPassiveNotification(text, "short" | "long", action, fn).
    function showPassiveNotification(message, timeout, actionText, callback) {
        toast.message = message
        toast.actionText = actionText || ""
        toast.callback = callback || null
        toastTimer.interval = timeout === "long" ? 7000 : 3500
        toastTimer.restart()
        toast.shown = true
    }
    Timer {
        id: toastTimer
        onTriggered: toast.shown = false
    }
    Item {
        id: toast
        property string message
        property string actionText
        property var callback: null
        property bool shown: false
        z: 1000
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 150 - height + (shown ? 0 : 16)
        width: Math.min(parent.width - 48, row.implicitWidth + 2 * Ui.gapL)
        height: 48
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Accessible.role: Accessible.AlertMessage
        Accessible.name: message
        PanelBackground { anchors.fill: parent; radius: Ui.radiusMedium; shadowOffset: 6; shadowBlur: 20 }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Ui.gapM
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width - 220)
                text: toast.message
                color: Backend.theme.p.panelText
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
                elide: Text.ElideRight
            }
            CButton {
                visible: toast.actionText !== ""
                anchors.verticalCenter: parent.verticalCenter
                kind: "primary"
                text: toast.actionText
                onClicked: {
                    toast.shown = false
                    if (toast.callback) toast.callback()
                }
            }
        }
    }
}
