// Stand-in for Quickshell's Region. "mask: Region {}" (no item) = clicks go
// through the window. With an item (DMS: only the chat and the docked bubble
// take clicks) it is ignored here: the whole window takes clicks.
import QtQuick

QtObject {
    property Item item: null
    default property list<QtObject> regions
}
