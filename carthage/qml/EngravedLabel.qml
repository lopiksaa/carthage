// A label cut into the plastic, lit from the top-left.
import QtQuick
import Carthage

Item {
    id: label

    property string text
    property int pixelSize: Ui.textLead
    readonly property var pal: Backend.theme.p

    implicitWidth: cut.implicitWidth
    implicitHeight: cut.implicitHeight + 1
    Accessible.role: Accessible.Heading
    Accessible.name: text

    Text {
        x: 1
        y: 1
        text: cut.text
        font: cut.font
        color: label.pal.engraveHi
    }
    Text {
        id: cut
        text: label.text.toUpperCase()
        color: label.pal.trayTextDim
        font.family: "Nunito"
        font.weight: Font.Black
        font.pixelSize: label.pixelSize
        font.letterSpacing: label.pixelSize >= Ui.textTitle ? 3 : 2
    }
}
