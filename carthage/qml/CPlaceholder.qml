// A calm empty-state message (no games, no search results, the store loading or offline):
// an icon, one line, an optional explanation and an optional button. Replaces KDE's
// Kirigami.PlaceholderMessage.
import QtQuick

import Carthage
Column {
    id: ph

    property string iconName
    property string text
    property string explanation
    property string actionText
    signal action()

    readonly property var pal: Backend.theme.p
    spacing: Ui.gapM
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    CIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: ph.iconName !== ""
        width: 64
        height: 64
        source: ph.iconName
        color: ph.pal.trayTextDim
        opacity: 0.7
    }
    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: ph.text
        color: ph.pal.trayText
        font.family: "Nunito"
        font.weight: Font.Bold
        font.pixelSize: Ui.textTitle
        wrapMode: Text.Wrap
    }
    Text {
        visible: ph.explanation !== ""
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: ph.explanation
        color: ph.pal.trayTextDim
        font.family: "Nunito"
        font.pixelSize: Ui.textBody
        wrapMode: Text.Wrap
    }
    CButton {
        visible: ph.actionText !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        text: ph.actionText
        onClicked: ph.action()
    }
}
