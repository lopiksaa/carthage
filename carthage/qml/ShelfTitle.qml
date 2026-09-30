// A library shelf's title that folds the shelf open or shut: "FAVORITES  5  ⌄".
//   ShelfTitle { text: "Favorites"; count: 5; collapsed: …; onToggled: … }
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.AbstractButton {
    id: st

    property int count: 0
    property bool collapsed: false
    readonly property var pal: Backend.theme.p

    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    onClicked: toggled()
    Accessible.role: Accessible.Button
    Accessible.name: text + ", " + count + (collapsed ? ", folded" : ", open")
    Keys.onSpacePressed: toggled()

    contentItem: Row {
        spacing: Ui.gapS
        EngravedLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: st.text
        }
        Text {
            visible: st.count > 0
            anchors.verticalCenter: parent.verticalCenter
            text: st.count
            color: st.pal.trayTextDim
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textCaption
        }
        CIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            source: "go-down-symbolic"
            color: st.hovered ? st.pal.trayText : st.pal.trayTextDim
            rotation: st.collapsed ? -90 : 0
            Behavior on rotation { NumberAnimation { duration: 120 * Backend.motion; easing.type: Easing.OutCubic } }
        }
    }
    background: Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Ui.radiusSmall
        color: "transparent"
        border.width: st.visualFocus ? 2 : 0
        border.color: Ui.focusColor
    }
}
