import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// CavaProcess - Manages cava audio visualizer with dynamic sink detection
Item {
    id: root

    property bool active: false
    property list<real> points: []
    // Use a stable path based on user to avoid temp file accumulation
    readonly property string configPath: FileUtils.trimFileProtocol(Directories.cache) + "/cava_config.txt"
    readonly property string scriptPath: FileUtils.trimFileProtocol(Directories.scriptPath) + "/cava/generate_config.sh"

    // Generate config and start cava when active
    onActiveChanged: {
        if (active) {
            console.log("[CavaProcess] Activating, generating config at:", configPath)
            cavaProc.running = false
            configGen.running = true
        } else {
            cavaProc.running = false
            points = []
        }
    }

    // Cleanup on destruction
    Component.onDestruction: {
        cavaProc.running = false
    }

    Process {
        id: configGen
        running: false
        command: ["/usr/bin/bash", root.scriptPath, root.configPath]
        onExited: (code, status) => {
            console.log("[CavaProcess] Config generation exited with code:", code)
            if (code === 0 && root.active) {
                cavaProc.running = true
            }
        }
    }

    Process {
        id: cavaProc
        running: false
        command: ["cava", "-p", root.configPath]
        onRunningChanged: {
          console.log("[CavaProcess] Cava running:", running)
            if (!running) root.points = []
        }
        stdout: SplitParser {
            onRead: data => {
                root.points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }
}
