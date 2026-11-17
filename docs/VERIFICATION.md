# Local verification

Built and tested with Xcode 27.1 on an Apple silicon Mac running macOS 27.2.1.

| Destination | Result |
| --- | --- |
| macOS Debug | 25 tests passed: 22 unit tests and 3 UI tests. |
| macOS Release | Universal arm64 and x86_64 build succeeded. The local ad hoc signature verified; the app was not notarized. |
| iPad Pro 13-inch simulator, iPadOS 26.4.1 | 26 tests passed: 22 unit tests and 4 UI tests. |
| iPad mini simulator, iPadOS 26.4.1 | Portrait navigation smoke test passed. |
| Generic iPadOS device, Release | Build succeeded with code signing disabled. |

Unit tests cover color conversion and WCAG reference cases, harmony and
locked swatches, palette and gradient formats, SwiftData persistence and
backup validation, image sampling, edit history, and raster export.
UI tests select an overview swatch, open workspaces, check the dark
palette workspace, and import, rotate, and undo an edit to the bundled sample.
On macOS, an additional Vision smoke test checked the alpha mask and a
solid background fill on a photo.

The README screenshots were captured from the running Mac and iPad simulator
applications. Older deployment versions, physical iPad hardware,
Developer ID distribution, and the remote GitHub Actions run are pending.
See the [release checklist](RELEASE.md).
