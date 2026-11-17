# Dependencies and references

CoStudio does not vendor Swift packages, fonts, artwork, or model weights.
Its original source, icon, and documentation are distributed under the
repository’s [MIT license](../LICENSE).

- Apple provides SwiftUI, SwiftData, AppKit/UIKit, Core Graphics, Core Image,
  Image I/O, Vision, Uniform Type Identifiers, and XCTest with its SDKs.
  Their use is subject to the applicable Apple SDK terms.
- GitHub Actions uses `actions/checkout` for CI only. See its
  [MIT license](https://github.com/actions/checkout/blob/main/LICENSE).
- Color contrast uses [WCAG 2.2](https://www.w3.org/TR/WCAG22/) relative luminance
  and text contrast criteria. Named colors follow the
  [CSS Color specification](https://www.w3.org/TR/css-color-4/#named-colors).
- Foreground masking uses Apple’s
  [Vision foreground instance request](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest).
