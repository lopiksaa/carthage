// The window. Everything inside lives in App.qml, which dev mode reloads live; changes to
// this file need a restart. Plain Qt (no KDE libraries), so it runs the same on Windows.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.ApplicationWindow {
    id: root
    visible: true
    color: Backend.theme.p.tray

    title: "Carthage"
    // Opens at 1180×820, or smaller on a screen that can't fit that (a 1366×768 laptop, or
    // 1080p at 125% scaling): never taller or wider than the free desktop area.
    width: Math.max(minimumWidth, Math.min(1180, Screen.desktopAvailableWidth - 40))
    height: Math.max(minimumHeight, Math.min(820, Screen.desktopAvailableHeight - 40))
    minimumWidth: 520
    minimumHeight: 480

    // Bumped by Python when a QML file changes (dev mode).
    property int reloadCount: 0
    // Set by the demo harness (GC_DEMO); forwarded to App.qml.
    property string demoCommand: ""
    property Item searchField: null

    // The hardware edition (black by default, or a colored plastic) comes from settings.
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
    Binding {
        target: Backend.theme
        property: "skin"
        // Only Classic ships for now; Plastic and Hi-Fi stay in the code, held back.
        value: "classic"
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

    // Short notices ("Hidden · Undo", "Starting…"), bottom-centre above the dock.
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
                font.family: "Nunito"
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
