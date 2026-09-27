// The top bar: the same plastic as the dock, so the window reads as one piece of hardware
// framing the tray. Wordmark left, search in the middle, menu button right.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Item {
    id: header

    property Item appRoot
    property alias searchField: search

    readonly property var pal: Backend.theme.p
    readonly property bool hifi: Backend.theme.skin === "hifi"

    height: 58

    // Plastic body, lit from above.
    Plastic {
        anchors.fill: parent
        bottomColor: Qt.darker(header.pal.dockTop, Backend.theme.dark ? 1.12 : 1.04)
    }
    Rectangle { // top edge catching the light
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: header.pal.dockHi
    }
    Rectangle { // seam against the tray
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: header.pal.dockSeam
    }
    // The bar sits above the tray, so it casts a soft shadow onto it (light from above).
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.bottom
        height: 16
        gradient: Gradient {
            GradientStop { position: 0.0; color: header.pal.trayShade }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Wordmark with a tiny cartridge glyph.
    Row {
        id: brand
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapM
        Accessible.ignored: true

        // The Carthage glyph (assets/icons/carthage-symbolic.svg): a cartridge with its tab,
        // label window and arrow, tinted like the wordmark.
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
            text: "CARTHAGE"
            color: header.pal.dockText
            // Hi-Fi: condensed capitals, widely spaced, as on a faceplate.
            font.family: header.hifi ? "Barlow Condensed" : "Nunito"
            font.weight: header.hifi ? Font.Bold : Font.Black
            font.pixelSize: header.hifi ? Ui.textTitle : Ui.textLead
            font.letterSpacing: header.hifi ? 6 : 3.5
        }
    }

    // Search: a backlit display set into the plastic (LCD) or the faceplate (VFD); in
    // Classic, an inset pill.
    QQC2.TextField {
        id: search
        anchors.centerIn: parent
        width: Math.min(360, header.width - 2 * Math.max(brand.width, modeSwitch.width) - 80)
        height: Ui.controlHeight
        leftPadding: 38
        rightPadding: clear.visible ? 34 : 14
        placeholderTextColor: searchDisplay.inkDim
        color: searchDisplay.ink
        font.family: searchDisplay.fontFamily
        font.weight: searchDisplay.bare ? Font.DemiBold : Font.Normal
        font.pixelSize: searchDisplay.bare ? Ui.textBody : searchDisplay.fontPx(15)
        font.letterSpacing: searchDisplay.bare ? 0 : 0.6
        font.capitalization: searchDisplay.bare ? Font.MixedCase : Font.AllUppercase
        selectionColor: header.hifi ? "#2a6d60" : searchDisplay.bare ? Backend.theme.accent.accent : "#6d8a33"
        selectedTextColor: searchDisplay.bare ? "#ffffff" : searchDisplay.ink
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        Accessible.name: "Search games"
        placeholderText: header.appRoot && header.appRoot.mode === "store" ? "Search Steam and Epic" : "Search games"
        onTextChanged: header.appRoot.search(text)
        Keys.onEscapePressed: {
            if (text) text = ""
            else header.appRoot.focusTray()
        }
        Keys.onDownPressed: header.appRoot.focusTray()
        Keys.onReturnPressed: header.appRoot.focusTray()

        background: Display {
            id: searchDisplay
            focused: search.activeFocus && !bare
            Rectangle {
                visible: searchDisplay.bare
                anchors.fill: parent
                radius: height / 2
                color: Backend.theme.dark ? Qt.darker(header.pal.dockBottom, 1.35) : Qt.darker(header.pal.dockTop, 1.06)
                border.width: search.activeFocus ? 2 : 1
                border.color: search.activeFocus ? Ui.focusColor : Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.5 : 0.14)
                // Inset: a shade along the inner top edge.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.25 : 0.06) }
                        GradientStop { position: 0.35; color: "transparent" }
                    }
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
            color: searchDisplay.inkDim
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
            tint: searchDisplay.inkDim
            icon.name: "edit-clear-symbolic"
            Accessible.name: "Clear search"
            focusPolicy: Qt.NoFocus
            onClicked: search.text = ""
        }
    }

    // Where the Library half of the switch is (cartridges fly into it from the store).
    function libraryButtonCenter(item) {
        return modeSwitch.libraryPoint(item)
    }

    // Library | Store.
    ModeSwitch {
        id: modeSwitch
        anchors.right: parent.right
        anchors.rightMargin: 20  // the same as the wordmark's on the left
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
