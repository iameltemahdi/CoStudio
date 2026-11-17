#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

plutil -lint -- CoStudio.xcodeproj/project.pbxproj CoStudio-Info.plist \
  CoStudio.entitlements Sources/CoStudio/Resources/PrivacyInfo.xcprivacy
git diff --check
git diff --cached --check

python3 - <<'PY'
import json
import pathlib
import xml.etree.ElementTree as ET

for catalog in pathlib.Path("Sources/CoStudio/Resources").rglob("Contents.json"):
    data = json.loads(catalog.read_text())
    for image in data.get("images", []):
        if "filename" in image and not (catalog.parent / image["filename"]).is_file():
            raise SystemExit(f"Missing image: {catalog.parent / image['filename']}")
ET.parse("CoStudio.xcodeproj/xcshareddata/xcschemes/CoStudio.xcscheme")
ET.parse("docs/assets/costudio-mark.svg")
PY
