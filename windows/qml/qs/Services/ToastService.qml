// Windows stand-in: messages become tray notifications.
pragma Singleton
import QtQuick

QtObject {
    function showInfo(message, details) {
        dux.notify(message, details || "", false);
    }
    function showError(message, details) {
        dux.notify(message, details || "", true);
    }
    function showWarning(message, details) {
        dux.notify(message, details || "", true);
    }
}
