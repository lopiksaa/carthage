// The window. Everything inside is App.qml, which dev mode reloads; changes here need a
// restart.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.ApplicationWindow {
    id: root
    visible: !Backend.testPlacedShow
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

    // While the window is being resized: a cover with the logo, in the background's own colours.
    // Behind it everything is laid out again, and the web-drawn ground hides and pauses (read
    // by the window while the web engine resized it, it could break and stay white). The cover
    // comes at once; once the size holds still the ground comes back, then the cover fades.
    Item {
        id: resizeCover
        property bool armed: false  // (not for the window's own first sizing)
        readonly property var colours: Backend.theme.glassy ? Backend.theme.groundNow : []
        function sized() {
            if (!armed || root.visibility === Window.Minimized || root.visibility === Window.Hidden) return
            fadeOut.stop()
            reveal.stop()
            opacity = 1
            Ui.resizing = true
            settle.restart()
        }
        z: 900
        anchors.fill: parent
        opacity: 0
        visible: opacity > 0.01
        Timer { id: settle; interval: 250; onTriggered: { Ui.resizing = false; reveal.restart() } }
        Timer { id: reveal; interval: 150; onTriggered: fadeOut.start() }  // (the ground draws first)
        NumberAnimation { id: fadeOut; target: resizeCover; property: "opacity"; to: 0; duration: 260 * Backend.motion; easing.type: Easing.OutCubic }
        Timer { interval: 1500; running: true; onTriggered: resizeCover.armed = true }
        Connections {
            target: root
            function onWidthChanged() { resizeCover.sized() }
            function onHeightChanged() { resizeCover.sized() }
        }
        Rectangle {
            anchors.fill: parent
            color: Backend.theme.glassy ? Backend.theme.glass.bg : Backend.theme.p.tray
            gradient: resizeCover.colours.length === 4 ? coverGradient : null
            Gradient {
                id: coverGradient
                GradientStop { position: 0; color: Qt.tint(resizeCover.colours[0], Qt.alpha(resizeCover.colours[1], 0.5)) }
                GradientStop { position: 1; color: Qt.tint(resizeCover.colours[3], Qt.alpha(resizeCover.colours[2], 0.5)) }
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: Ui.gapL
            CIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 36
                source: "carthage"
                isMask: true
                color: Backend.theme.p.trayText
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CARTHAGE"
                color: Backend.theme.p.trayText
                font.family: Ui.fontLabels
                font.weight: Font.Black
                font.pixelSize: Ui.textTitle
                font.letterSpacing: 6
            }
        }
        // (nothing behind it takes the pointer while it shows)
        MouseArea { anchors.fill: parent; enabled: resizeCover.visible; hoverEnabled: true }
    }

    // App.qml calls Window.window.showPassiveNotification(text, "short" | "long", action, fn).
    function showPassiveNotification(message, timeout, actionText, callback) {
        toast.message = message
        toast.actionText = actionText || ""
        toast.callback = callback || null
        // "sticky": it stays until its button or its ✕ (an update waiting for Restart Now)
        toast.sticky = timeout === "sticky"
        toastTimer.interval = timeout === "long" ? 7000 : 3500
        if (toast.sticky) toastTimer.stop()
        else toastTimer.restart()
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
        property bool sticky: false
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
                width: Math.min(implicitWidth, root.width - (toast.sticky ? 264 : 220))
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
            CButton {
                visible: toast.sticky
                anchors.verticalCenter: parent.verticalCenter
                kind: "plain"
                icon.name: "window-close-symbolic"
                Accessible.name: "Dismiss"
                onClicked: toast.shown = false
            }
        }
    }
}
