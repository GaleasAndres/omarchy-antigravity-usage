import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/omarchy/agents/usage"

  // Dynamically resolve the absolute path to scripts/omarchy-agent-usage-agy
  readonly property string scriptPath: {
    var url = Qt.resolvedUrl("scripts/omarchy-agent-usage-agy").toString()
    if (url.indexOf("file://") === 0) return url.substring(7)
    return home + "/.config/omarchy/plugins/galeasandres.antigravity-usage/scripts/omarchy-agent-usage-agy"
  }

  property bool isUpdating: updateProcess.running
  property string lastUpdated: ""

  Process {
    id: updateProcess
    running: false

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.trim() !== "") console.warn("antigravity-usage:", text.trim())
      }
    }

    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.lastUpdated = new Date().toISOString()
      } else {
        console.warn("antigravity-usage: collector exited with code", exitCode)
      }
    }
  }

  function triggerUpdate(force) {
    if (updateProcess.running) return
    var cmd = [
      "bash", "-c",
      "script=\"$0\"; usage_dir=\"$1\"; shift 2; mkdir -p \"$usage_dir\" || exit 1; tmp=$(mktemp \"$usage_dir/.agy.XXXXXX\") || exit 1; if python3 \"$script\" \"$@\" > \"$tmp\" && [[ -s \"$tmp\" ]] && jq -e . >/dev/null 2>&1 < \"$tmp\"; then mv \"$tmp\" \"$usage_dir/agy.json\"; else rm -f \"$tmp\"; exit 1; fi",
      root.scriptPath,
      root.usageDir
    ]
    if (force === true) {
      cmd.push("--force")
    }
    updateProcess.command = cmd
    updateProcess.running = true
  }

  // Periodic refresh timer (every 10 minutes)
  Timer {
    interval: 600 * 1000
    running: true
    repeat: true
    onTriggered: root.triggerUpdate(false)
  }

  // Initial update on shell startup after short delay for keyring and network to stabilize
  Timer {
    id: startupTimer
    interval: 2000
    repeat: false
    onTriggered: root.triggerUpdate(true)
  }

  Component.onCompleted: startupTimer.start()

  IpcHandler {
    target: "antigravity"

    function refresh(): string {
      root.triggerUpdate(true)
      return "refresh triggered"
    }

    function status(): string {
      return JSON.stringify({
        running: updateProcess.running,
        lastUpdated: root.lastUpdated,
        scriptPath: root.scriptPath,
        usageDir: root.usageDir
      })
    }
  }
}
