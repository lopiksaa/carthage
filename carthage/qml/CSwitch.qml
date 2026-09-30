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

    // The hover and focus highlight reaches past the row, so the text and switch line up
    // with the other settings while still having room inside the highlight.
    background: Item {
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -8
            anchors.rightMargin: -8
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
    }

    contentItem: Item {
        Column {
            id: labels
            anchors.left: parent.left
            anchors.right: track.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: sw.text
                color: sw.pal.panelText
                font.family: Ui.fontText
                font.weight: Font.Bold
                font.pixelSize: Ui.textBody
                elide: Text.ElideRight
            }
            Text {
                visible: sw.hint !== ""
                width: parent.width
                text: sw.hint
                color: sw.pal.panelTextDim
                font.family: Ui.fontText
                font.pixelSize: Ui.textCaption
                wrapMode: Text.Wrap
            }
        }
        Rectangle {
            id: track
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 22
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
    }
}
