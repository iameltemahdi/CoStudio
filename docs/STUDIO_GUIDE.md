# Studio guide

**Pick and carry a color.** In Overview, select a field swatch or open Color
Picker. The active HEX in the toolbar lets you copy the current value or jump
back to the picker. Use the color library to browse named colors. On Mac,
⌘1 through ⌘0 open workspaces in sidebar order; ⌘⇧C copies the active HEX.

**Create a palette.** In Palette Generator, choose a harmony and regenerate.
Lock swatches to keep them, edit the colors, and save to the library. In
Projects & Collections, group palettes under collections and collections under
projects. Use the backup commands to export a versioned `.costudiobackup`
package or merge a package into the local library. Keep a separate backup
before restoring if you want to preserve newer versions of matching library
entries. Backups include saved projects, collections, palettes, and imported
images. Preferences and unsaved drafts are outside the backup. Existing local
edits on a matching original image are preserved during restore.

**Make a gradient.** Add and edit stops, change the linear angle or switch to
radial, and copy or export CSS or SVG. In ASE and ACO palette exports, RGB
swatches are opaque because those swatch formats do not preserve alpha.

**Check contrast.** Set both colors and look at the text preview. The checker
uses WCAG 2.2 ratios: 4.5:1 and 3:1 for AA normal and large text, and 7:1 and
4.5:1 for AAA. Simulation is an approximation. CMYK values are generic estimates
and should not be used as a press profile.

**Work with an image.** Import an image or drop it in Image Studio. Use the
sampling view for pixel coordinates, a loupe, and palette extraction. Crop,
rotate, or test a color change, then export an edited copy. The source image
is never overwritten. JPEG cannot carry transparency; use PNG when you need
a transparent background. Subject isolation depends on Apple Vision, the
device, and whether a foreground subject can be detected. Processing works
on still RGB images; recoloring effects operate in sRGB. JPEG export flattens
transparent areas over white.

**AI upscaling.** No model is bundled or emulated in this version. The app
does not offer an ordinary resize under an AI label.
