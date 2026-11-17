# Privacy

CoStudio works offline. It has no accounts, ads, analytics, telemetry,
tracking, third-party SDKs, or network-backed tools. Apple Vision processes
image masks on the device. CoStudio does not send imported images, palettes,
projects, or preferences to a server.

| Data | Where it lives |
| --- | --- |
| Projects, collections, saved palettes | CoStudio’s local SwiftData store. CloudKit is disabled. |
| Original imported images | CoStudio’s application support folder. |
| Appearance, favorite colors, and pick history | The app’s local preferences. |
| Exported images, palettes, gradients, and backups | A location you choose in the platform’s file picker. |

Apple’s device backup settings and your selected file provider can apply to
these files separately. In particular, exporting to a cloud-backed folder may
sync that export according to the provider’s settings. Keep backup packages
private if they contain personal images. CoStudio writes to the system
clipboard when you explicitly copy; clipboard behavior is managed by the
operating system.

The macOS application is sandboxed and asks the operating system for access to
files you select. Review the bundled
[privacy manifest](Sources/CoStudio/Resources/PrivacyInfo.xcprivacy) for its
declared API use.
