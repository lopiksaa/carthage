// The settings drawer behind the app. App.qml slides the content aside; the drawer stays put.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

FocusScope {
    id: drawer

    property Item appRoot
    readonly property var pal: Backend.theme.p
    signal closeRequested()

    function focusFirst() {
        flick.forceActiveFocus()
    }
    readonly property var sections: [
        { id: "library", title: "Library", icon: "view-grid-symbolic", blurb: "The tray and your games" },
        { id: "look", title: "Look & Feel", icon: "color-picker-symbolic", blurb: "Colors, card size, motion" },
        { id: "sound", title: "Sound", icon: "audio-volume-high-symbolic", blurb: "Clicks and clunks" },
        { id: "store", title: "Store", icon: "internet-services-symbolic", blurb: "Steam and Epic, other stores" },
        { id: "keys", title: "Accounts & Keys", icon: "lock-symbolic", blurb: "Keys for art, Steam and prices" },
        { id: "system", title: "System", icon: "configure-symbolic", blurb: "Cache, art, updates, about" },
    ]
    property string openSection: "library"

    width: 360
    Keys.onEscapePressed: closeRequested()

    Plastic { anchors.fill: parent }
    RecessedPanel {
        id: well
        anchors.fill: parent
        anchors.margins: 12
        anchors.leftMargin: 14
    }
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gapXS
        Repeater {
            model: 5
            Rectangle {
                width: 5
                height: 2
                radius: 1
                color: Qt.darker(drawer.pal.dockBottom, Backend.theme.dark ? 1.4 : 1.15)
            }
        }
    }

    readonly property real scrollY: flick.contentY
    function scrollToEnd() {
        flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    Flickable {
        id: flick
        anchors.fill: well
        anchors.margins: 2
        contentHeight: content.height + 2 * Ui.gapL
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: true
        QQC2.ScrollBar.vertical: CScrollBar { ink: Backend.theme.p.panelText }
        WheelAccel { flickable: flick; step: 90 }

        Column {
            id: content
            x: Ui.gapM
            y: Ui.gapM
            width: flick.width - 2 * Ui.gapM
            spacing: Ui.gapXS

            Repeater {
                model: drawer.sections
                delegate: Column {
                    id: fold
                    required property var modelData
                    readonly property bool open: drawer.openSection === modelData.id
                    width: content.width
                    spacing: 0

                    QQC2.AbstractButton {
                        id: head
                        width: parent.width
                        height: 54
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        Accessible.role: Accessible.Button
                        Accessible.name: fold.modelData.title + (fold.open ? ", open" : "")
                        onClicked: drawer.openSection = fold.open ? "" : fold.modelData.id
                        background: Rectangle {
                            radius: Ui.radiusMedium
                            color: fold.open ? Qt.alpha(drawer.pal.panelHover, 0.9)
                                 : head.hovered ? Qt.alpha(drawer.pal.panelHover, 0.6) : "transparent"
                            Rectangle {
                                visible: head.visualFocus
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 2
                                border.color: Ui.focusColor
                            }
                        }
                        contentItem: Item {
                            CIcon {
                                id: foldIcon
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                source: fold.modelData.icon
                                isMask: true
                                color: fold.open ? Backend.theme.accent.accent : drawer.pal.panelTextDim
                            }
                            Column {
                                anchors.left: foldIcon.right
                                anchors.leftMargin: 12
                                anchors.right: chevron.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    width: parent.width
                                    text: fold.modelData.title
                                    color: drawer.pal.panelText
                                    font.family: "Nunito"
                                    font.weight: Font.Black
                                    font.pixelSize: Ui.textBody
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: fold.modelData.blurb
                                    color: drawer.pal.panelTextDim
                                    font.family: "Nunito"
                                    font.pixelSize: Ui.textCaption
                                    elide: Text.ElideRight
                                }
                            }
                            CIcon {
                                id: chevron
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                source: "go-down-symbolic"
                                isMask: true
                                color: drawer.pal.panelTextDim
                                rotation: fold.open ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 160 * Backend.motion } }
                            }
                        }
                    }
                    Item {
                        width: parent.width
                        height: fold.open ? settings.height + Ui.gapM + Ui.gapL : 0
                        clip: true
                        visible: height > 0
                        Behavior on height { NumberAnimation { duration: 200 * Backend.motion; easing.type: Easing.OutCubic } }
                        SettingsContent {
                            id: settings
                            x: Ui.gapS
                            y: Ui.gapM
                            width: parent.width - 2 * Ui.gapS
                            appRoot: drawer.appRoot
                            section: fold.modelData.id
                        }
                    }
                }
            }
        }
    }
}
