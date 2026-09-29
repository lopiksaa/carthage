// A settings row: label on the left, a rounded switch on the right. The whole row toggles.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.AbstractButton {
    id: sw

    property string hint: ""
    readonly property var pal: Backend.theme.p

    checkable: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: Math.max(40, labels.implicitHeight + 2 * Ui.gapS)
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked

    background: Rectangle {
        radius: Ui.radiusMedium
        color: sw.hovered ? Qt.alpha(sw.pal.panelHover, 0.7) : "transparent"
        Rectangle {
            visible: sw.visualFocus
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: Ui.focusColor
        }
    }

    contentItem: Item {
        Column {
            id: labels
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: track.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: sw.text
                color: sw.pal.panelText
                font.family: "Nunito"
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
                elide: Text.ElideRight
            }
            Text {
                visible: sw.hint !== ""
                width: parent.width
                text: sw.hint
                color: sw.pal.panelTextDim
                font.family: "Nunito"
                font.pixelSize: Ui.textCaption
                wrapMode: Text.Wrap
            }
        }
        Item {
            id: track
            readonly property bool classic: Backend.theme.skin === "classic"
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: classic ? 40 : 58
            height: classic ? 22 : 26

            Rectangle {
                visible: track.classic
                anchors.fill: parent
                radius: height / 2
                color: sw.checked ? Backend.theme.accent.accent : sw.pal.panelBorder
                Behavior on color { ColorAnimation { duration: 100 * Backend.motion } }
                Rectangle {
                    x: sw.checked ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: "#ffffff"
                    Behavior on x { NumberAnimation { duration: 100 * Backend.motion; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                visible: !track.classic
                anchors.fill: parent
                radius: 7
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#0d0d10" }
                    GradientStop { position: 1.0; color: "#1d1c22" }
                }
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.6)
                Rectangle {
                    x: sw.checked ? 8 : parent.width - 15
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: sw.checked ? Backend.theme.led.green : "#2a2930"
                    Behavior on x { NumberAnimation { duration: 90 * Backend.motion } }
                }
                Rectangle {
                    x: sw.checked ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: parent.height - 6
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#5f5e68" }
                        GradientStop { position: 1.0; color: "#3a3941" }
                    }
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.6)
                    Behavior on x { NumberAnimation { duration: 110 * Backend.motion; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater { model: 4; Rectangle { width: 1.5; height: 9; color: Qt.rgba(0, 0, 0, 0.45) } }
                    }
                }
            }
        }
    }
}
