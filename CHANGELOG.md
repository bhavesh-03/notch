# Changelog

All notable changes to Notch. Versions follow [Semantic Versioning](https://semver.org): new features bump the minor version, fixes bump the patch version.

## Unreleased (planned as 1.1.0)

### Added
- **Tabs** in the expanded notch: **Home** and **Files**. The file shelf moved into the Files tab and now holds 12 files; dragging a file onto the notch opens Files automatically from any tab.
- The app's version and build number are shown at the top of the right-click menu.
- **Customizable timer:** tap the timer on Home to open a full-width page with a minute ruler (up to 2 hours) that follows click-drag, flicks and trackpad scrolling, snaps to whole minutes, and makes the tick under the pointer glow. Click and hold for half a second to zoom in and pick 15-second steps. Times of an hour or more show hours (1:30:00) everywhere. While running, the page shows a large countdown with pause and cancel.
- **Mirror:** a camera button (right of the camera housing) opens a live, mirrored camera view in the notch. The camera runs only while the mirror is open; nothing is recorded or saved.

### Changed
- Page height changes (switching tabs, the player row appearing or leaving) use a slower, softer spring.

### Fixed
- Dragging a file out of the shelf and dropping it back no longer adds it twice; the shelf recognizes the same file, including a copy Finder made of it.

## 1.0.0 — 2026-09-27

First version, installed to /Applications.

- The notch overlay: sits on the hardware notch (or a virtual one on other screens), expands on hover, lets clicks through when collapsed, follows display changes.
- **Battery:** level and charging state in the ears; a charging animation with a filling battery when power is connected.
- **Timer:** a 25-minute Pomodoro with play/pause/reset, live countdown in the ears, and a notification when it finishes.
- **Calendar:** the next event; a countdown in the ears from 10 minutes before a meeting and a "Now" pop-up when it starts.
- **File shelf:** drop files or screenshot thumbnails onto the notch; drag them back out; kept across launches.
- **Now Playing** from any app (browsers, web apps, Music, Spotify): the source app in the ears, a player with progress and controls, and a pop-up on track changes.
- Launch at Login and Quit from a right-click menu; Reduce Motion support; app icon.
