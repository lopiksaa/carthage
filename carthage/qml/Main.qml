// The window. Everything inside is App.qml, which dev mode reloads; changes here need a
// restart.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.ApplicationWindow {
    id: root
    visible: true
    flags: Backend.testNoFocus ? (Qt.Window | Qt.WindowDoesNotAcceptFocus) : Qt.Window
    color: Backend.theme.p.tray
    font.family: Ui.fontText  // standard controls (fields, menus) inherit the chosen font

    title: "Carthage"
    // Never larger than the free desktop area (a 1366×768 laptop, or 1080p at 125% scaling).
    width: Math.max(minimumWidth, Math.min(1180, Screen.desktopAvailableWidth - 40))
    height: Math.max(minimumHeight, Math.min(820, Screen.desktopAvailableHeight - 40))
    minimumWidth: 520
    minimumHeight: 480

    property int reloadCount: 0
    property Item searchField: null

    // Carthage's own palette, set here so every control inherits it: otherwise Qt Quick
    // Controls take their colors from the system theme (on Windows, text selections came out
    // in the desktop's accent color).
    readonly property var chromePal: Backend.chromeColors(Backend.theme.dark)
    palette.window: chromePal.window
    palette.windowText: chromePal.windowText
    palette.base: chromePal.base
    palette.alternateBase: chromePal.alternateBase
    palette.text: chromePal.text
    palette.placeholderText: chromePal.placeholderText
    palette.button: chromePal.button
    palette.buttonText: chromePal.buttonText
    palette.highlight: chromePal.highlight
    palette.highlightedText: chromePal.highlightedText
    palette.toolTipBase: chromePal.toolTipBase
    palette.toolTipText: chromePal.toolTipText
    palette.link: chromePal.link
    palette.linkVisited: chromePal.linkVisited
    palette.accent: chromePal.accent
    palette.disabled.text: chromePal.disabled
    palette.disabled.windowText: chromePal.disabled
    palette.disabled.buttonText: chromePal.disabled

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
        Ui.openMenus = 0  // the old content's menus are gone, open or not
        contentLoader.source = ""
        contentLoader.source = Qt.resolvedUrl("App.qml")
    }

    Shortcut {
        sequences: [StandardKey.Find]
        enabled: root.searchField !== null  // App.qml may handle it itself
        onActivated: if (root.searchField) root.searchField.forceActiveFocus()
    }
    Shortcut {
        sequences: [StandardKey.Quit]
        onActivated: Qt.quit()
    }
    Shortcut {
        sequences: [StandardKey.ZoomIn, "Ctrl+="]
        onActivated: Backend.settings.cardWidth = Math.min(Ui.cardMax, Backend.settings.cardWidth + Ui.cardStep)
    }
    Shortcut {
        sequences: [StandardKey.ZoomOut]
        onActivated: Backend.settings.cardWidth = Math.max(Ui.cardMin, Backend.settings.cardWidth - Ui.cardStep)
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
        Behavior on opacity { NumberAnimation { duration: 160 * Backend.motion; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 200 * Backend.motion; easing.type: Easing.OutCubic } }
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
