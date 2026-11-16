// Round colored circle with the logo inside. Used in the bar, the chat
// header and the empty chat screen.
// logoPath points to a white copy of DuxAI/assets/logo.svg (made by the
// backend); without a logo a sparkle icon is shown.
import QtQuick
import qs.DCommon.Widgets

Rectangle {
    id: circle

    property real size: 26
    property color accent: "#D97757"
    property string logoPath: ""
    property bool hasLogo: false

    width: size
    height: size
    radius: size / 2
    color: accent

    Image {
        id: logo
        anchors.centerIn: parent
        width: circle.size * 0.62
        height: width
        source: circle.hasLogo ? "file://" + circle.logoPath : ""
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: status === Image.Ready
    }
    DIcon {
        anchors.centerIn: parent
        visible: logo.status !== Image.Ready
        name: "auto_awesome"
        size: circle.size * 0.62
        filled: true
        color: "white"
    }
}
