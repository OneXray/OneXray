# OneXray App Icons

Shared Icon Composer artwork for Apple platform app icons.

These files live under `swift/App` so the iOS, macOS, and macOS system extension
projects can use the same source artwork.

## Packages

- `IconBlue.icon`: Icon Composer source document for the primary blue icon.
- `IconBlack.icon`, `IconGreen.icon`, `IconOrange.icon`, `IconPurple.icon`,
  `IconRed.icon`: Icon Composer source documents for the iOS alternate icons.

## Colors

- Blue: `#007AFF`
- Black: `#000000`
- Green: `#4CAF50`
- Orange: `#FF9800`
- Purple: `#9C27B0`
- Red: `#F44336`

Each `.icon` package includes its own `center-cutout.svg`. The center circle
must use the same color as that package's background so it masks the crossing
white strokes and creates the visual break in the middle of the mark.
