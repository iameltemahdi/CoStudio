#!/usr/bin/env bash
set -euo pipefail

# Prefer a booted iPad; otherwise use a device from the newest available runtime.
devices="$(xcrun simctl list devices available -j)"
python3 -c '
import json
import re
import sys
devices = json.load(sys.stdin)["devices"]
candidates = [
    (device.get("state") == "Booted", tuple(map(int, re.findall(r"\d+", runtime))),
     device["name"].startswith("iPad Pro"), device["udid"])
    for runtime, group in devices.items() if ".iOS-" in runtime
    for device in group if device.get("isAvailable") and device["name"].startswith("iPad")
]
if not candidates:
    sys.exit("No available iPad simulator. Install an iOS runtime in Xcode Settings → Components.")
print(max(candidates)[-1])
' <<< "$devices"
