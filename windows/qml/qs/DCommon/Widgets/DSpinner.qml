import QtQuick
import qs.Common

DIcon {
    name: "progress_activity"
    color: Theme.primary
    RotationAnimation on rotation {
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 900
    }
}
