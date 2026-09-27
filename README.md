# Notch

A macOS app that turns the MacBook camera notch into a live, interactive surface — in the spirit of the iPhone's Dynamic Island. Hover over the notch and it expands to show information; move away and it tucks back in.

Built from scratch as a hands-on way to learn Swift, SwiftUI and AppKit.

## Features

| Feature | Status |
|---|---|
| Black overlay that sits exactly on the hardware notch | ✅ Done |
| Hover to expand, debounced collapse, click-through when collapsed | ✅ Done |
| Works on any Mac: measures the notch per screen, falls back to a virtual pill on screens without one | ✅ Done |
| Follows display changes (resolution, monitors, clamshell) | ✅ Done |
| Battery level and charging / plugged-in state, live-updating | ✅ Done |
| Timer / Pomodoro: play/pause/reset in the notch, live countdown in the ears | ✅ Done |
| Timer completion notification (permission asked on first start) | ✅ Done |
| Module system: features plug into the notch through one protocol | ✅ Done |
| Activities: the notch briefly springs out when the charger is connected or a timer finishes | ✅ Done |
| Charging choreography: hand-drawn battery fills to your level in green, bolt pops in | ✅ Done |
| Reduce Motion support, ignoring quick cable reconnects | ✅ Done |
| Calendar: next event in the expanded notch (asks for access only when you click) | ✅ Done |
| Calendar: "8 min" countdown in the ears before a meeting, "Now" activity when it starts | ✅ Done |
| Stable code signing (permissions survive rebuilds) | ✅ Done |
| Launch at login and Quit, from a right-click menu on the expanded notch | ✅ Done |
| Settings window: show, hide and reorder features | ✅ Done |
| Look settings: width, corner roundness, accent color, ears on/off, with a live preview | ✅ Done |
| Behavior settings: hover delay, per-pop-up switches, animation speed | ✅ Done |
| Timer settings: remembered length, editable preset chips, notification and sound switches | ✅ Done |
| File shelf: drop files (or screenshot thumbnails) onto the notch; kept across launches | ✅ Done |
| Tabs: Home · Files; dragging a file onto the notch opens Files automatically | ✅ Done |
| Mirror: a live, mirrored camera view from a button beside the camera | ✅ Done |
| Customizable timer: a ruler page up to 2 hours (drag, flick, trackpad; hold for 15-second steps), hours display, large countdown with pause/cancel | ✅ Done |
| File shelf: Quick Look thumbnails, drag files back out, right-click Open / Show in Finder / Remove / Clear | ✅ Done |
| Now Playing from any app (browsers, web apps, Music, Spotify…): source app and live indicator in the ears, hidden while you're in the playing app | ✅ Done |
| Now Playing: player row with progress and ⏮ ⏯ ⏭ above the modules; activity on track change | ✅ Done |
| Now Playing with several apps: switch which player the row shows and controls | ✅ Done |
| Home widgets: a grid of Battery, Timer, Calendar and system stats in four sizes, columns following the notch width, no empty space | ✅ Done |
| System stats: CPU, GPU, memory and temperatures, sampled only while shown | ✅ Done |
| Edit Home: jiggle mode in the notch and a Settings tab to move, resize, remove and add widgets | ✅ Done |
| Calendar page: month strip, the selected day's events, open in Calendar, Join for calls; widget lists upcoming events | ✅ Done |
| Liquid Glass: glass controls and widget cards, a sliding glass pill for tabs and players, smoked-glass notch on screens without one | ✅ Done |
| Volume & brightness: the notch's own indicator replaces macOS's for the volume, mute and brightness keys | ✅ Done |
| App icon, and a one-command Release install to /Applications | ✅ Done |
| Distribution to other Macs: Developer ID signing and notarization (needs the paid Apple Developer Program) | 🗓 Optional |

## Requirements

- macOS 27 or later
- Xcode 27
- A MacBook with a notch for the full experience (other displays get a virtual notch)

## Installing

```bash
Tools/install.sh
```

Builds the Release configuration, verifies its signature, quits any running copy, replaces `/Applications/Notch.app`, and launches it. Run it again after making changes to update the installed app. Then right-click the expanded notch and turn on **Launch at Login** (once; it survives updates because the path stays the same).

Permissions (calendar, notifications) and saved data carry over between the installed app and builds run from Xcode, because they share the bundle ID and signing team. Don't run both at the same time — quit the installed copy before pressing ⌘R.

## Versions and releases

The app has a version (`MARKETING_VERSION` in the project, e.g. `1.1.0`, following [Semantic Versioning](https://semver.org)) and a build number (set by `Tools/install.sh` to the number of git commits). Both appear at the top of the right-click menu, e.g. **Notch 1.1.0 (72)**. Changes are recorded in [CHANGELOG.md](CHANGELOG.md) under **Unreleased** as they're made.

To release a version:

1. Set **Version** (`MARKETING_VERSION`) in the Notch target to the new number.
2. In `CHANGELOG.md`, rename **Unreleased** to that version and date.
3. Commit, then tag it: `git tag -a v1.1.0 -m "Notch 1.1.0" && git push --follow-tags`.
4. Run `Tools/install.sh`.

## Building and running

1. Open `Notch.xcodeproj` in Xcode.
2. Select the **Notch** scheme and **My Mac** as the destination.
3. Under **Signing & Capabilities**, set **Team** to your own (a free Personal Team works). Ad-hoc signed builds get a new identity every build, so macOS would ask for calendar access again after each rebuild.
4. Press **⌘R**.

The app runs as an agent (`LSUIElement`): it has **no Dock icon and no menu bar menu**. Hover over the notch and **right-click** it for **Launch at Login** and **Quit Notch**.

## Running the tests

The logic (`TimerState`, `TimerController`, `NotchGeometry`, `BatteryStatus`) is covered by Swift Testing unit tests in `NotchTests/`. Run them with **⌘U** in Xcode, or:

```bash
xcodebuild test -project Notch.xcodeproj -scheme Notch -destination 'platform=macOS'
```

Tests run inside the app, so the notch briefly appears while they execute.

## How it works

```
NotchApp ──▶ AppDelegate ──creates──▶ NotchPanel (borderless NSPanel above the menu bar)
                 │                          └── NSHostingView ──▶ NotchView (SwiftUI, renders modules)
                 │                                                     ▲
                 ├── NSEvent mouse monitors ──▶ NotchViewModel ────────┘ (@Observable)
                 └── screen-change notifications       ├── NotchGeometry   (where the notch is)
                                                       ├── BatteryMonitor  (IOKit power sources)
                                                       └── TimerController (countdown)
```

- **The window.** `NotchPanel` is a transparent, borderless, non-activating `NSPanel` at `mainMenu + 3` window level, visible on every Space and over full-screen apps. SwiftUI content is hosted inside it via `NSHostingView` (`NotchView`).
- **Finding the notch.** `NotchGeometry` computes the notch rectangle from `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` (using only their widths, anchored to `screen.frame`) and `safeAreaInsets.top`. Screens without a notch get a centered 180×24 virtual notch built through the same code path. The math lives in a pure initializer so it can be exercised without a real screen.
- **Hover and clicks.** The panel ignores mouse events while collapsed so the menu bar underneath stays usable. Global and local `mouseMoved` monitors hit-test the cursor against the collapsed notch (or the whole panel when expanded). Collapsing is debounced by 300 ms with a cancellable `Task`.
- **State.** `NotchViewModel` is the single source of truth for the view: expansion state, geometry and the battery monitor. AppKit code mutates it; SwiftUI re-renders automatically through `@Observable`.
- **Clicking without stealing focus.** The panel is non-activating, can become key, and uses `becomesKeyOnlyIfNeeded`, so clicking its buttons never takes keyboard focus away from the app you're working in.
- **Battery.** `BatteryMonitor` reads the internal battery through `IOPSCopyPowerSourcesInfo` and refreshes on `kIOPSNotifyAnyPowerSource`. `BatteryStatus` is a plain value type that parses the IOKit dictionary and picks the SF Symbol (bolt when charging, plug when on AC but not charging, e.g. during optimized charging).

- **Modules.** Each feature conforms to `NotchModule`: it reports an `earPriority` (how strongly it wants the collapsed ears right now, or `nil`) and provides content for each `NotchPlacement` (leading ear, trailing ear, pill on screens without a notch, expanded). The highest-priority module owns the ears; every module gets a section in the expanded view. Adding a feature means writing its model, conforming it in a `Type+NotchModule.swift` file, and listing it in `NotchViewModel.modules`.
- **Activities.** `NotchViewModel.presentation` is an enum — `.collapsed`, `.expanded`, or `.activity(module)` — so impossible combinations can't be represented. A module can briefly take over the notch with `showActivity(from:)`: the notch springs out to an activity shape laid out *around* the camera (content in ears on either side plus a detail row below), then collapses on its own after ~2.5 s. Hovering always wins: it turns an activity into the full expanded view. The battery triggers an activity on the plug-in *edge* (not-plugged → plugged), never at launch or when charging merely starts later; the timer triggers one when it finishes.
- **Calendar page.** Tapping the Calendar widget opens a `.page` tab (like the timer's): `CalendarMonth` supplies the month's days for a scrolling strip, and `CalendarEvent.events(on:in:)` / `busyDays(in:)` (pure, tested) pick the selected day's events and the dotted days from one query per month (`CalendarMonitor.events(from:to:)`, reloaded when Calendar's data changes). Events carry their calendar's color, location, and a call link found by `CallLink` (an `NSDataDetector` over the URL, location and notes, matched against Zoom, Meet, Teams, FaceTime and Webex hosts). Clicking an event opens `ical://ekevent/<id>` in Calendar. The monitor also keeps `upcoming` (the next week's events, all-day first) for the bigger widget sizes. Page and widget layouts take plain values (`CalendarPageContent`, `CalendarWidgetContent`) so they can be previewed with sample events.
- **Calendar.** Reading calendars needs an `NSCalendarsFullAccessUsageDescription` string (the `com.apple.security.personal-information.calendars` entitlement from `ENABLE_RESOURCE_ACCESS_CALENDARS` is kept for a hardened-runtime build), without which macOS silently denies the request. Access is requested only when you click "Show next event" in the expanded notch; if denied, the notch links to the Calendars privacy settings. `CalendarMonitor` refreshes on `EKEventStoreChanged`, so edits in Calendar appear immediately. From 10 minutes before a meeting until 5 minutes after it starts, the calendar claims the ears (priority 5: above the battery, below a running timer) with a live "8 min" countdown, and the notch springs out with the title when it starts. Because time passing isn't a state change SwiftUI can observe, `CalendarMonitor` schedules a single wake-up for the next moment the display should change (`CalendarEvent.nextBoundary`) instead of polling.
- **Charging animation.** The activity's battery is drawn by hand (`ChargingBattery`) because SF Symbols only come in 25% steps: its fill is a custom `BatteryFill` shape whose `animatableData` is the level, so it fills smoothly from empty to the current charge, then the bolt pops in with a bouncy spring. It's always green — at plug-in macOS usually reports "not charging yet" — and the ear icon afterwards shows the accurate state (bolt when charging, plug when on hold). `PlugInFilter` ignores a loose cable reconnecting within 2 seconds.
- **Tabs.** A module can declare a `tab` (title and symbol) to get its own page instead of a column on Home; `NotchView` builds the tab bar (in the space left of the camera) from whatever modules declare, so it knows nothing about specific features. A tab's `style` is `.tab` (labelled, left of the camera) or `.button` (icon only, right of it). A module can also declare `acceptsFileDrops`; a file drag onto the notch opens that tab from anywhere. The notch always reopens on Home, the media player row belongs to Home, and height changes between pages use their own slower, softer spring (`NotchMotion.pageResize`).
- **Mirror.** A button-style tab whose page shows the built-in camera through `AVCaptureVideoPreviewLayer` (hosted with `NSViewRepresentable`), mirrored with a SwiftUI `.scaleEffect(x: -1, y: 1)` on the view (not the capture connection, which only exists after the session is configured asynchronously). The session starts when the page appears and stops when it disappears, so the camera (and its green light) is only on while the mirror is open. Needs the camera entitlement (`ENABLE_RESOURCE_ACCESS_CAMERA`) and `NSCameraUsageDescription`. `SerialCaptureSession` confines the non-Sendable `AVCaptureSession` to one serial queue, which is what makes starting it off the main thread safe.
- **Settings.** `NotchSettings` is one `@Observable` object saved in `UserDefaults` (injected, so tests use a throwaway domain via `NotchSettings.ephemeral()`), rather than `@AppStorage`, which only views can use. Each module declares its `NotchFeature`; `NotchViewModel.modules` is `allModules` filtered and ordered by the user's choices, so a hidden feature leaves the ears, Home, the tabs and activities in one place. Saved orders are normalized on load: duplicates and unknown names are dropped and features added in later versions are appended. Hiding Now Playing stops its helper process. The window (`SettingsWindowController`) is an `NSTabViewController` with toolbar tabs hosting one grouped SwiftUI `Form` per tab, resizing to each tab like System Settings, because SwiftUI's `openSettings` only works from views inside a SwiftUI scene and the notch lives in our own panel; it activates the app first, since an agent app's windows would otherwise open behind the current app. **Look:** width and ears are instance properties of `NotchGeometry`, which the app delegate builds from the screen plus the settings and rebuilds (resizing the panel) when they change; corner radius and accent are read by the view directly. The accent reaches feature views through a custom environment value (`\.notchAccent`), set once at the top of `NotchView`. **Behavior:** a hover delay is a cancellable countdown (`pointerEntered` / `pointerLeft`) that repeated mouse-move events don't restart, and file drags skip; pop-ups are muted per feature, checked in `showActivity`; the animation speed is applied to every `NotchMotion` value with `Animation.speed(_:)`, which scales durations and delays alike so springs keep their shape. **Timer:** the ruler and Settings edit one saved length; `TimerController.onDurationChanged` and `NotchSettings.onTimerLengthChanged` each report only real changes, so a change makes one round trip and stops. A length chosen while a timer runs is held and applied when it finishes or is cancelled. Preset chips reach the timer page through an environment value and use `ViewThatFits` to drop chips when the row is short on space.
- **Volume & brightness.** `MediaKeyTap` installs a `CGEventTap` for system-defined events (the media keys), decodes them (`MediaKey`, tested), and swallows the ones the notch handles so macOS's indicator never appears: volume and mute through CoreAudio (`SystemVolume`), the built-in display's brightness through the private DisplayServices (`DisplayBrightness`, loaded with `dlsym`). Levels move in sixteenths, or sixty-fourths with ⇧⌥, snapped to the grid (`LevelStep`). Keys it can't act on pass through to macOS. The tap needs Accessibility permission, which a sandboxed app can't have, so since 1.2 the app isn't sandboxed; `SandboxMigration` moves the old container's settings and shelf copies over once at launch. `LevelIndicator` presents as an activity when the notch is closed, and as a bar along the bottom when it's open.
- **Liquid Glass.** Neutral controls use `glassControl(in:)` (`.glassEffect(.regular.interactive())`), and widget cards are glass inside a `GlassEffectContainer` with spacing below the card gap, so they blend while dragged but never merge at rest. Two lessons from testing: glass takes its color from what's behind it, and behind the notch is black, so tinted glass loses its tint; emphasized buttons (Done, Join, the chosen preset) therefore stay solid. And glass drawn by a container sits above sibling views, so the selected-tab and shown-player pills are single glass shapes *behind* their rows that slide to the selection with `matchedGeometryEffect`. The hardware notch stays solid black to blend into the camera housing; the virtual notch on screens without one is glass tinted 55% black so white content stays readable.
- **Home widgets.** Home is a grid of two rows and 4, 5 or 6 columns (Compact, Standard, Wide), so cells stay about 100 pt wide. The layout (`HomeLayout`, saved in `NotchSettings`) is an ordered list of widgets with sizes (Small 1×1, Wide 2×1, Tall 1×2, Large 2×2), not positions: `arranged(columns:)` packs them at the first spot each fits, filling each column top to bottom before moving right, so one layout suits every width and widgets that don't fit are kept for wider settings. `filled(columns:)` then removes empty space for display: unused columns are dropped and widgets grow into adjacent gaps (vertically first), drawn at their grown size while their saved size stays. Widgets whose feature is hidden are left out. **Editing** (`HomeLayoutEditor`, used both in the notch via right-click → Edit Home and in Settings → Home) shows saved sizes with empty cells outlined; gestures call pure `HomeLayout` operations: `move(_:toColumn:row:columns:visible:)` (over a widget the two trade places, over an empty cell it takes that spot in reading order, hidden widgets keep their place), `resize`, `remove` and `add`. While editing, the notch stays open through its own flag, independent of the right-click menu's hold.
- **System stats.** `SystemStatsReader` reads CPU ticks (`host_processor_info`), memory (`host_statistics64`, counted like Activity Monitor, plus `kern.memorystatus_vm_pressure_level`), GPU utilization (the `IOAccelerator` driver's `PerformanceStatistics`), and temperatures through the private `IOHIDEventSystemClient` (looked up with `dlsym`; the hottest `tdie` sensor for the CPU, the gas gauge for the battery). All of this worked even inside the sandbox; fan speeds would need the SMC. `SystemStatsMonitor` samples every 2 s off the main thread and only while a stats widget is on screen (widgets register as viewers), keeping a minute of history for the graphs. A test runs the real reader in the test host.
- **File shelf.** Dragging files toward the notch opens it early — over the whole expanded area, detected by file URLs or file promises on the drag pasteboard — so you never have to push against the top edge (which would trigger Mission Control). Dropped files are *referenced* through bookmarks, so they're found again after relaunches (security-scoped ones, from the sandboxed versions, still resolve). Drops without a usable file, like a screenshot thumbnail's file promise, are *copied* into `Application Support/com.vinzi.Notch/Shelf` and deleted when removed. The shelf lives in the Files tab and holds 12 items and shows "Shelf full" when a drop won't fit. Items show Quick Look thumbnails, can be dragged back out to any app, and have their own right-click menu (Open, Show in Finder, Remove, Clear Shelf). An owned copy is only deleted while it's still in the shelf's folder — if Finder moved it out during a drag, it's the user's file now. A drop is ignored when the shelf already holds the same file (compared by file-system identity, following symlinks) or a byte-identical copy of it, since dragging an item to Finder usually copies it.
- **Now Playing.** macOS has no public API for what *other* apps are playing, and since macOS 15.4 the private MediaRemote framework only answers Apple-signed processes. The app therefore launches Apple's `/usr/bin/perl` and has it load `libNowPlayingBridge.dylib` (an Objective-C target embedded in `Contents/Frameworks`, not linked into the app). Inside perl, the bridge lists every app registered with MediaRemote (`MRMediaRemoteGetNowPlayingClients`), asks each for its own state through an `MRNowPlayingRequest` aimed at that app's player path, and writes one JSON line (all players plus macOS's elected "now playing" app) whenever anything changes, and reads `toggle` / `next` / `previous` from stdin; closing stdin ends it. This worked even from inside the App Sandbox, so no helper process is needed. `NowPlayingMonitor` owns the process, restarts it after 10 s if it dies, and claims the ears (priority 3) while something is playing. While there's something to control, it also claims the expanded notch's *headline* row: a full-width player (source app, title, artist, live progress, ⏮ ⏯ ⏭) above the module columns. Album art isn't readable by third-party apps for most sources (web players in particular), so the player shows the source app's icon on a tile tinted with the icon's average color (Core Image `CIAreaAverage`, computed in sRGB). The notch grows 74 pt for it; the panel is sized for this tallest state and never resizes, so hover is tested against the visible shape rather than the panel. A new track while playing triggers an activity. While the playing app is frontmost (tracked with `NSWorkspace.didActivateApplicationNotification`), Now Playing gives up the ears and skips that activity, since the player is already on screen; the headline row stays. macOS reports the playing app, not the window or tab, so this is per app. **Several players:** the row shows the player the user picked in a switcher of app icons, or else the elected app if it's playing, else any that is; another app starting to play takes over again. Commands go by the route that was verified to work: the system command for the elected app; AppleScript for Spotify and Music otherwise (`NSAppleEventsUsageDescription`, plus `com.apple.security.automation.apple-events` for a hardened-runtime build); and for anything else, an Open button, because in testing MediaRemote's per-app commands to a non-elected web player were delivered to a different app. Music in a browser shows a music-note tile rather than the browser's icon, since macOS reports the browser, not the site, and doesn't share artwork. Because this relies on a private framework, the app can't be distributed through the Mac App Store.
- **Ear handovers.** When the owner of the collapsed ears changes, the old content blurs and shrinks away while the new content comes into focus (`NotchMotion.earContent`, about 0.85 s).
- **App menu.** Right-clicking the expanded notch opens a context menu with **Launch at Login** (`SMAppService.mainApp`; status re-read every time the notch expands, since it can be changed in System Settings) and **Quit Notch**. While any of the app's menus is open (`NSMenu` begin/end tracking notifications) the notch is held open, then the pointer is re-checked when the menu closes.
- **Motion.** Activity animation values live in `NotchMotion`: the old content leaves in 0.18 s, the shape springs open (0.75 s, bounce 0.45) or closed (0.65 s, bounce 0.32), and the new content blurs and scales into focus just after the shape starts moving, so two layouts never overlap.
- **Reduce Motion.** With the system setting on, activities open with a short bounce-free ease instead of a spring (`NotchViewModel` reads `NSWorkspace`, injected for tests) and the charging battery appears already full (`ChargingBattery` reads the SwiftUI environment).
- **Timer.** `TimerState` stores an end date rather than counting ticks, so it can't drift and survives sleep. `TimerController` sleeps once until that date to finish. The view shows the countdown with a `TimelineView` aligned to whole seconds of remaining time, rounded up. While a timer is active it outranks the battery for the collapsed ears (priority 10 vs 0). Notification permission is requested the first time a timer starts, not at launch; when the timer finishes, `NotificationService` posts a "Time's up" banner (shown even while the app is active, via the notification-center delegate). Tapping the timer on Home opens a full-width page with a duration ruler drawn by one `Canvas` that conforms to `Animatable`, so position, zoom and glow animate smoothly without hundreds of tick views. The ruler follows click-drag (with `predictedEndTranslation` for flicks) and trackpad scrolling through a local `NSEvent` monitor; holding for 0.5 s zooms in to 15-second steps. Zoom (visual) and step (precision) are kept separate, so a 15-second value survives zooming back out. The page is tall only while picking a time; the height change is animated *below* `.clipShape`, because `.animation(_:value:)` only animates modifiers above it.

## Project structure

Files are grouped **by feature**, not by layer. Folders are purely organizational in Swift — everything is one module — so moving a file never changes behavior.

```
Notch/
├── App/                    Entry point and app-level concerns
│   ├── NotchApp.swift          App entry; opens no regular windows
│   ├── AppDelegate.swift       Creates the panel and view model, mouse/screen/menu wiring
│   └── LaunchAtLogin.swift     Login item via SMAppService, behind a fakeable protocol
├── Shell/                  The notch itself: window, geometry, layout, module system
│   ├── NotchPanel.swift        Borderless, transparent, non-activating always-on-top panel
│   ├── NotchGeometry.swift     Notch / collapsed / activity / panel rects; hardware vs virtual notch
│   ├── NotchViewModel.swift    Presentation state (collapsed / expanded / activity), modules
│   ├── NotchModule.swift       The protocol features conform to, placements, ear ownership
│   ├── NotchMotion.swift       Activity animation and transition values
│   └── NotchView.swift         Draws the notch and lays out what the modules provide
├── Settings/               NotchFeature, NotchSettings, NotchLook, NotchBehavior, SettingsView, SettingsWindowController
├── Home/                   HomeLayout (widget kinds, sizes, packing, gap filling, edits), HomeGrid, HomeLayoutEditor
├── Features/
│   ├── Battery/                BatteryStatus, PlugInFilter, BatteryMonitor (+NotchModule)
│   ├── Timer/                  TimerState, TimerController (+NotchModule)
│   ├── Calendar/               CalendarEvent, CalendarMonitor (+NotchModule)
│   ├── Shelf/                  ShelfStore (+NotchModule): the Files tab
│   ├── Mirror/                 MirrorCamera (+NotchModule), SerialCaptureSession
│   ├── SystemStats/            SystemStatsSample, SystemStatsReader, SystemStatsMonitor (+NotchModule), widgets
│   └── NowPlaying/             NowPlayingInfo, LineBuffer, NowPlayingBridgeProcess, NowPlayingMonitor (+NotchModule)
├── Services/
│   └── NotificationService.swift   Notification permission and posting
└── Resources/
    └── Assets.xcassets

NowPlayingBridge/           Objective-C dynamic library loaded into /usr/bin/perl (see "Now Playing")
NotchTests/                 Swift Testing suites, mirroring the structure above
Tools/                      install.sh (Release build → /Applications) and MakeAppIcon.swift (draws the app icon)
CHANGELOG.md                What changed in each version
Notch.entitlements          Entitlements with no build-setting equivalent (Apple events, for a hardened-runtime build)
```

Each feature follows the same pattern: a pure value type with the logic (tested), an `@Observable` class that talks to the system, and a `Type+NotchModule.swift` file with its notch UI.

## Known limitations

- The right-click menu is only reachable once the notch is expanded (the collapsed notch lets clicks pass through to the menu bar).
- Builds are signed with a development certificate, so they run on this Mac; sharing the app with other Macs needs Developer ID signing and notarization.
- Now Playing depends on private macOS behavior and may break in a future macOS release; the notch keeps working without it.
- Tested on a 13" MacBook Air (M4) only.
