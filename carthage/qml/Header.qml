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

    Plastic {
        anchors.fill: parent
        bottomColor: Qt.darker(header.pal.dockTop, Backend.theme.dark ? 1.12 : 1.04)
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: header.pal.dockHi
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: header.pal.dockSeam
    }
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

    Row {
        id: brand
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapM
        Accessible.ignored: true

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
            font.family: Ui.fontLabels
            font.weight: Font.Black
            font.pixelSize: Ui.textLead
            font.letterSpacing: 3.5
        }
    }

    QQC2.TextField {
        id: search
        anchors.centerIn: parent
        width: Math.min(360, header.width - 2 * Math.max(brand.width, modeSwitch.width) - 80)
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
        Accessible.name: "Search games"
        placeholderText: header.appRoot && header.appRoot.mode === "store" ? "Search Steam and Epic" : "Search games"
        onTextChanged: header.appRoot.search(text)
        Keys.onEscapePressed: {
            if (text) text = ""
            else header.appRoot.focusTray()
        }
        Keys.onDownPressed: header.appRoot.focusTray()
        Keys.onReturnPressed: header.appRoot.focusTray()

        background: Rectangle {
            radius: height / 2
            color: Backend.theme.dark ? Qt.darker(header.pal.dockBottom, 1.35) : Qt.darker(header.pal.dockTop, 1.06)
            border.width: search.activeFocus ? 2 : 1
            border.color: search.activeFocus ? Ui.focusColor : Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.5 : 0.14)
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
