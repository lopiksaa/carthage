// The top bar: wordmark, search and the Library | Store switch.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: header

    property Item appRoot
    property alias searchField: search

    readonly property var pal: Backend.theme.p

    height: 58

    readonly property bool glassy: Backend.theme.glassy
    readonly property var g: Backend.theme.glass

    // Glass: a tinted pane, a lit top line, a faint ring line along the bottom, a soft shadow.
    GlassSurface {
        visible: header.glassy
        anchors.fill: parent
        radius: 0
        sheen: "transparent"
        edges: false
        shadowY: 12
        shadowBlur: 30
        shadowSpread: -14
    }
    Rectangle {
        visible: header.glassy
        width: parent.width
        height: 1
        color: header.g.edge
    }
    Rectangle {
        visible: header.glassy
        width: parent.width
        anchors.bottom: parent.bottom
        height: 1
        color: header.g.ring
    }

    Plastic {
        visible: !header.glassy
        anchors.fill: parent
        bottomColor: Qt.darker(header.pal.dockTop, Backend.theme.dark ? 1.12 : 1.04)
    }
    Rectangle {
        visible: !header.glassy
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: header.pal.dockHi
    }
    Rectangle {
        visible: !header.glassy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: header.pal.dockSeam
    }
    Rectangle {
        visible: !header.glassy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.bottom
        height: 16
        gradient: Gradient {
            GradientStop { position: 0.0; color: header.pal.trayShade }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ≡ slides the sidebar out over the content (lists, sources, store pages, Settings), at the
    // right edge, the side the sidebar comes from. A dot on it says an update is waiting
    // (Settings has the same dot).
    CButton {
        id: burger
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 36
        kind: "ghost"
        tint: header.pal.dockText
        icon.name: "application-menu"
        Accessible.name: (header.appRoot && header.appRoot.sidebarOpen ? "Close" : "Open") + " the sidebar"
                         + (updateDot.visible ? ", an update is available" : "")
        QQC2.ToolTip.visible: tipWanted  // (not over the sidebar it just opened)
        QQC2.ToolTip.text: "Sidebar (Ctrl+B)"
        QQC2.ToolTip.delay: 500
        onClicked: header.appRoot.toggleSidebar()
        UpdateDot {
            id: updateDot
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5
        }
    }

    Row {
        id: brand
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapM
        // The logo takes you home: back to the library from anywhere (a game's view, the store,
        // settings…).
        Accessible.role: Accessible.Button
        Accessible.name: "Carthage: go to the library"
        opacity: brandHover.hovered ? 0.8 : 1
        HoverHandler { id: brandHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                // Already there: back to the top instead.
                if (header.appRoot.page === "library:all" && !header.appRoot.modalOpen) header.appRoot.backToTop()
                else header.appRoot.navigate("library:all")
                header.appRoot.sound("key")
            }
        }

        CIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 22
            source: "carthage"
            isMask: true
            color: header.pal.dockText
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: header.width >= 680
            text: "CARTHAGE"
            color: header.pal.dockText
            font.family: Ui.fontLabels
            font.weight: Font.Black
            font.pixelSize: Ui.textLead
            font.letterSpacing: 3.5
        }
    }

    QQC2.TextField {
        id: search
        objectName: "tourSearch"  // (the first-run tour points at it)
        readonly property bool compact: header.width < 680
        anchors.verticalCenter: parent.verticalCenter
        x: compact ? brand.x + brand.width + 12 : (header.width - width) / 2
        width: compact ? Math.max(48, modeSwitch.x - brand.x - brand.width - 24)
                       : Math.min(360, header.width - 2 * Math.max(brand.x + brand.width, header.width - modeSwitch.x) - 40)
        height: Ui.controlHeight
        leftPadding: 38
        rightPadding: clear.visible ? 34 : 14
        placeholderTextColor: header.pal.dockTextDim
        color: header.pal.dockText
        font.family: Ui.fontText
        font.weight: Font.DemiBold
        font.pixelSize: Ui.textBody
        selectionColor: Backend.theme.accent.accent
        selectedTextColor: "#ffffff"
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        Accessible.name: "Search your games and the stores"
        placeholderText: "Search your games and the stores"
        onTextChanged: header.appRoot.search(text)
        // Clicking in opens the search page straight away (it browses with no text too).
        onPressed: if (header.appRoot.page !== "search") header.appRoot.navigate("search")
        Keys.onEscapePressed: {
            if (text) text = ""
            else if (header.appRoot.page === "search") header.appRoot.navigateBack()
            else header.appRoot.focusTray()
        }
        Keys.onDownPressed: header.appRoot.focusTray()
        Keys.onReturnPressed: header.appRoot.focusTray()

        background: Rectangle {
            radius: height / 2
            // (By the plastic's own lightness, not the mode: white plastic in dark mode too.)
            readonly property bool palePlastic: Qt.color(header.pal.dockTop).hslLightness > 0.6
            color: header.glassy ? header.g.field
                 : palePlastic ? Qt.darker(header.pal.dockTop, 1.06) : Qt.darker(header.pal.dockBottom, 1.35)
            border.width: search.activeFocus ? 2 : 1
            border.color: search.activeFocus ? Ui.focusColor
                        : header.glassy ? header.g.ring : Qt.rgba(0, 0, 0, palePlastic ? 0.14 : 0.5)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: header.glassy ? Qt.rgba(0, 0, 0, 0.2) : Qt.rgba(0, 0, 0, parent.parent.palePlastic ? 0.06 : 0.25) }
                    GradientStop { position: header.glassy ? 0.12 : 0.35; color: "transparent" }
                }
            }
        }
        CIcon {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: "search-symbolic"
            isMask: true
            color: header.pal.dockTextDim
        }
        CButton {
            id: clear
            visible: search.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            kind: "ghost"
            tint: header.pal.dockTextDim
            icon.name: "edit-clear-symbolic"
            Accessible.name: "Clear search"
            focusPolicy: Qt.NoFocus
            onClicked: search.text = ""
        }
    }

    function libraryButtonCenter(item) {
        return modeSwitch.libraryPoint(item)
    }

    ModeSwitch {
        id: modeSwitch
        objectName: "tourStore"
        onLibraryHome: header.appRoot.navigate("library:all")
        anchors.right: burger.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: implicitHeight
        value: header.appRoot ? header.appRoot.mode : "library"
        onPicked: (v) => {
            header.appRoot.sound("hover")
            header.appRoot.setMode(v)
        }
    }
}
