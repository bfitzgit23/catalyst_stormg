import QtQuick 2.0
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12

ColumnLayout {
    spacing: 0

    Item { Layout.fillWidth: true; Layout.preferredHeight: 20 }

    Image {
        source: "stormg.svg"
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 64
        Layout.preferredHeight: 64
        fillMode: Image.PreserveAspectFit
    }

    Item { Layout.fillWidth: true; Layout.preferredHeight: 10 }

    Text {
        text: "StormG"
        font.pixelSize: 16
        font.bold: true
        color: "#ffffff"
        Layout.alignment: Qt.AlignHCenter
    }

    Item { Layout.fillWidth: true; Layout.preferredHeight: 20 }
}
