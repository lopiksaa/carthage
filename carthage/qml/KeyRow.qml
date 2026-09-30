// One API key: a field, Save (which checks the key first) and a link to get one.
import QtQuick
import Carthage
import QtQuick.Controls as QQC2

Column {
    id: row

    property string service
    property string title
    property string purpose
    property string getUrl
    property string getText: "Get a free key"
    property bool required: false

    readonly property var pal: Backend.theme.p
    readonly property bool saved: Backend.keys.has[service] === true
    readonly property string status: Backend.keys.status[service] || ""
    readonly property string message: Backend.keys.message[service] || ""
    property bool editing: false

    spacing: Ui.gapS

    Flow { // the badge wraps under a long title instead of running off the edge
        width: parent.width
        spacing: Ui.gapS
        Text {
            text: row.title
            color: row.pal.panelText
            font.family: Ui.fontText
            font.weight: Font.Bold
            font.pixelSize: Ui.textBody
        }
        Rectangle {
            width: needText.implicitWidth + 2 * Ui.gapS
            height: needText.implicitHeight + 4
            radius: height / 2
            color: row.required ? Backend.theme.accent.accent : "transparent"
            border.width: row.required ? 0 : 1
            border.color: row.pal.panelBorder
            Text {
                id: needText
                anchors.centerIn: parent
                text: row.required ? "Required" : "Optional"
                color: row.required ? "#ffffff" : row.pal.panelTextDim
                font.family: Ui.fontText
                font.weight: Font.Black
                font.pixelSize: Ui.textCaption
            }
        }
    }
    Text {
        width: parent.width
        text: row.purpose
        color: row.pal.panelTextDim
        font.family: Ui.fontText
        font.pixelSize: Ui.textCaption
        wrapMode: Text.Wrap
    }

    Row {
        visible: row.saved && !row.editing
        width: parent.width
        spacing: Ui.gapS
        Rectangle {
            height: Ui.controlHeight
            width: parent.width - change.width - remove.width - 16
            radius: Ui.radiusMedium
            color: Qt.alpha(Backend.theme.led.green, 0.14)
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: Ui.gapS
                CIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    source: "checkmark-symbolic"
                    isMask: true
                    color: row.pal.panelText
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Saved"
                    color: row.pal.panelText
                    font.family: Ui.fontText
                    font.weight: Font.Bold
                    font.pixelSize: Ui.textBody
                }
            }
        }
        CButton {
            id: change
            text: "Change"
            onClicked: {
                row.editing = true
                field.text = ""
                field.forceActiveFocus()
            }
        }
        CButton {
            id: remove
            kind: "danger"
            icon.name: "edit-delete-symbolic"
            Accessible.name: "Remove " + row.title
            onClicked: Backend.keys.remove(row.service)
        }
    }

    Row {
        visible: !row.saved || row.editing
        width: parent.width
        spacing: Ui.gapS
        QQC2.TextField {
            id: field
            width: parent.width - save.width - 8
            height: Ui.controlHeight
            leftPadding: 12
            rightPadding: 12
            echoMode: TextInput.Password
            placeholderText: "Paste your key"
            placeholderTextColor: row.pal.panelTextDim
            color: row.pal.panelText
            font.family: "DM Mono"
            font.pixelSize: Ui.textBody
            selectByMouse: true
            enabled: row.status !== "checking"
            Accessible.name: row.title
            onAccepted: save.clicked()
            background: Rectangle {
                radius: Ui.radiusMedium
                color: row.pal.panelHover
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? Backend.theme.accent.accent : row.pal.panelBorder
            }
        }
        CButton {
            id: save
            kind: "primary"
            text: row.status === "checking" ? "Checking…" : "Save"
            enabled: field.text.trim() !== "" && row.status !== "checking"
            onClicked: Backend.keys.save(row.service, field.text)
        }
    }

    Text {
        visible: row.message !== "" && row.status !== "checking"
        width: parent.width
        text: row.message
        color: row.status === "error" ? row.pal.dangerText : row.pal.panelTextDim
        font.family: Ui.fontText
        font.weight: Font.DemiBold
        font.pixelSize: Ui.textCaption
        wrapMode: Text.Wrap
    }

    Text {
        visible: !row.saved || row.editing
        text: row.getText + " ↗"
        color: Backend.theme.accent.accent
        font.family: Ui.fontText
        font.weight: Font.Bold
        font.pixelSize: Ui.textBody
        Accessible.role: Accessible.Link
        Accessible.name: row.getText
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Backend.openUrl(row.getUrl) }
    }

    // The key only lives in the keyring, so the field is cleared.
    Connections {
        target: Backend.keys
        function onChanged() {
            if (row.status === "ok" || (row.saved && row.status !== "checking" && row.status !== "error")) {
                row.editing = false
                field.text = ""
            }
        }
    }
}
