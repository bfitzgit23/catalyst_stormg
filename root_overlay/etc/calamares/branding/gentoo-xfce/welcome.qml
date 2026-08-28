import QtQuick 2.0
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12

Item {
    Layout.fillHeight: true
    Layout.fillWidth: true

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Image {
            source: "stormg.svg"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 180
            Layout.preferredHeight: 180
            fillMode: Image.PreserveAspectFit
        }

        Text {
            text: qsTr("Welcome to StormG")
            font.pixelSize: 28
            font.bold: true
            color: "#ffffff"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: qsTr("Gentoo Linux made calm.\nThis installer will guide you through the process.")
            font.pixelSize: 14
            color: "#cccccc"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
