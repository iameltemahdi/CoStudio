# Contributing

Build CoStudio from [the shared Xcode project](CoStudio.xcodeproj). An Apple
silicon Mac and Xcode 16.4 or newer with an iPad simulator runtime are
recommended. CoStudio does not require Swift packages or setup credentials.

1. Read the [code of conduct](CODE_OF_CONDUCT.md).
2. Open an issue for a user-facing proposal, or go straight to a small fix.
3. Make a focused change. Put color math, raster operations, and file formats
   in domain code so they can be exercised without UI automation.
4. Run the tests in the [development guide](docs/DEVELOPMENT.md). For visible
   changes, include a real screenshot and verify light, dark, and a narrow
   workspace where appropriate.
5. Open a pull request and describe the behavior a reviewer can verify.

Use synthetic image and library data for tests and screenshots. Please report
security concerns through the private process in [SECURITY.md](SECURITY.md).
By contributing, you agree to license your contributions under the
[MIT license](LICENSE).
