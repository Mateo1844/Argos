// Material Symbols icon by name, like DMS's DIcon (font: windows/fonts/DuxIcons.ttf).
import QtQuick
import qs.Common

Text {
    property string name: ""
    property real size: 24
    property bool filled: false

    text: dux.icon(name)
    font.family: dux.iconFont
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0 })
    color: Theme.onSurface
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
