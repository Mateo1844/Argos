// Windows stand-in for DMS's Theme: Claude's dark colours (warm greys, orange accent).
pragma Singleton
import QtQuick

QtObject {
    property color primary: "#D97757"      // Claude orange
    readonly property color systemAccent: dux.systemAccent   // Windows' own accent colour
    property color error: "#E8806E"
    property color surface: "#1F1E1D"
    property color surfaceContainer: "#262624"
    property color surfaceContainerHigh: "#30302E"
    property color surfaceContainerHighest: "#3A3A37"
    property color onSurface
    property color onSurfaceVariant
    property color outlineVariant: "#44433E"
    // ("on..." names are set here: in a QtObject they'd look like signal handlers)
    Component.onCompleted: {
        onSurface = "#F5F4EF";
        onSurfaceVariant = "#B8B5A9";
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
