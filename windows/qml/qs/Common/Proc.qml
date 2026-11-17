// Windows stand-in for DMS's Proc: runs commands through the Python app.
pragma Singleton
import QtQuick

QtObject {
    function runCommand(id, command, callback, debounceMs) {
        dux.runCommand(id, command, callback || null);
    }
}
