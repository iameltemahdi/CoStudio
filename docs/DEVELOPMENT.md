# Development

Open `CoStudio.xcodeproj`. The shared `CoStudio` scheme builds the same native
SwiftUI code for macOS and iPadOS. Xcode 16.4 or newer is required; repository
folders are tracked with Xcode buildable groups. If Xcode is installed but
Terminal selects the standalone command line tools, set the developer path
for the current shell:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

```sh
./scripts/check-repository.sh

xcodebuild -project CoStudio.xcodeproj -scheme CoStudio \
  -destination 'platform=macOS' -parallel-testing-enabled NO test

ipad="$(./scripts/select-ipad.sh)"
xcodebuild -project CoStudio.xcodeproj -scheme CoStudio \
  -destination "id=$ipad" -parallel-testing-enabled NO test

xcodebuild -project CoStudio.xcodeproj -scheme CoStudio -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Headless workers should run macOS unit tests with
`-only-testing:CoStudioTests`. For desktop UI automation, use a logged-in
graphical session. Configure the iPad simulator runtime through Xcode’s
Components settings before building and testing.

| Folder | Responsibility |
| --- | --- |
| `Sources/CoStudio/Studio` | Application lifecycle, sidebar, commands, settings, and design primitives. |
| `Sources/CoStudio/Color` | Bounded sRGB value type, conversions, analysis, and color tools. |
| `Sources/CoStudio/Library` | Palette and gradient recipes, exports, SwiftData models, and versioned backup. |
| `Sources/CoStudio/Imaging` | Local image catalog, raster processing, edit history, and native image workspace. |
| `Sources/CoStudio/Resources` | Asset catalog and privacy manifest. |
| `Tests` | Domain coverage and navigation tests. |

Add color fixtures with a known reference value and a useful tolerance.
Preserve original images and test transforms with synthetic rasters whose
pixel layout is known. Test file-format encodings separately from the system
save panel. Run `swift scripts/GenerateIcons.swift` from the project root
to regenerate the app icon. Run `swift scripts/GenerateSample.swift` to
regenerate the sample still life. Both use Core Graphics.
