// Windows stand-in for DMS's Theme: a fixed dark Material-style palette.
pragma Singleton
import QtQuick

QtObject {
    property color primary: "#D0BCFF"
    property color error: "#F2B8B5"
    property color surface: "#1C1B1F"
    property color surfaceContainer: "#211F26"
    property color surfaceContainerHigh: "#2B2930"
    property color surfaceContainerHighest: "#36343B"
    property color onSurface
    property color onSurfaceVariant
    property color outlineVariant: "#49454F"
    // ("on..." names are set here: in a QtObject they'd look like signal handlers)
    Component.onCompleted: {
        onSurface = "#E6E1E5";
        onSurfaceVariant = "#CAC4D0";
    }

    property real fontSizeSmall: 12
    property real fontSizeMedium: 14
    property real fontSizeLarge: 16
    property real cornerRadius: 12
    property real windowRadius: 16
    property real spacingXS: 4
    property real spacingS: 8
    property real spacingM: 12

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
