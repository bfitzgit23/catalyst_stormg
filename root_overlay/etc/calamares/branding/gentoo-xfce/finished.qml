import QtQuick 2.0
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12

Item {
    Layout.fillHeight: true
    Layout.fillWidth: true

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "✅"
            font.pixelSize: 48
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: qsTr("Installation Complete!")
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: qsTr("StormG has been installed successfully.\nYou may now reboot into your new system.")
            font.pixelSize: 14
            color: "#cccccc"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
