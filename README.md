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
| File shelf: drop files (or screenshot thumbnails) onto the notch; kept across launches | ✅ Done |
| File shelf: Quick Look thumbnails, drag files back out, right-click Open / Show in Finder / Remove / Clear | ✅ Done |
| Now Playing from any app (browsers, web apps, Music, Spotify…): source app and live indicator in the ears | ✅ Done |
| Now Playing: expanded player with controls, track-change activity | ⏳ Next |
| Distribution: Developer ID signing and notarization | 🗓 Planned |

## Requirements

- macOS 27 or later
- Xcode 27
- A MacBook with a notch for the full experience (other displays get a virtual notch)

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
- **Calendar.** Reading calendars needs two things: the sandbox entitlement `com.apple.security.personal-information.calendars` (build setting `ENABLE_RESOURCE_ACCESS_CALENDARS`) and an `NSCalendarsFullAccessUsageDescription` string, without which macOS silently denies the request. Access is requested only when you click "Show next event" in the expanded notch; if denied, the notch links to the Calendars privacy settings. `CalendarMonitor` refreshes on `EKEventStoreChanged`, so edits in Calendar appear immediately. From 10 minutes before a meeting until 5 minutes after it starts, the calendar claims the ears (priority 5: above the battery, below a running timer) with a live "8 min" countdown, and the notch springs out with the title when it starts. Because time passing isn't a state change SwiftUI can observe, `CalendarMonitor` schedules a single wake-up for the next moment the display should change (`CalendarEvent.nextBoundary`) instead of polling.
- **Charging animation.** The activity's battery is drawn by hand (`ChargingBattery`) because SF Symbols only come in 25% steps: its fill is a custom `BatteryFill` shape whose `animatableData` is the level, so it fills smoothly from empty to the current charge, then the bolt pops in with a bouncy spring. It's always green — at plug-in macOS usually reports "not charging yet" — and the ear icon afterwards shows the accurate state (bolt when charging, plug when on hold). `PlugInFilter` ignores a loose cable reconnecting within 2 seconds.
- **File shelf.** Dragging files toward the notch opens it early — over the whole expanded area, detected by file URLs or file promises on the drag pasteboard — so you never have to push against the top edge (which would trigger Mission Control). Dropped files are *referenced* through security-scoped bookmarks (entitlement `com.apple.security.files.bookmarks.app-scope`, declared in `Notch.entitlements` because there's no build setting for it) so access survives relaunches. Drops without a usable file, like a screenshot thumbnail's file promise, are *copied* into the app's `Application Support/Shelf` folder and deleted when removed. The shelf holds 6 items and shows "Shelf full" when a drop won't fit. Items show Quick Look thumbnails, can be dragged back out to any app, and have their own right-click menu (Open, Show in Finder, Remove, Clear Shelf). An owned copy is only deleted while it's still in the shelf's folder — if Finder moved it out during a drag, it's the user's file now.
- **Now Playing.** macOS has no public API for what *other* apps are playing, and since macOS 15.4 the private MediaRemote framework only answers Apple-signed processes. The app therefore launches Apple's `/usr/bin/perl` and has it load `libNowPlayingBridge.dylib` (an Objective-C target embedded in `Contents/Frameworks`, not linked into the app). Inside perl, the bridge polls `MRNowPlayingRequest` and writes a JSON line to stdout whenever the state changes, and reads `toggle` / `next` / `previous` from stdin; closing stdin ends it. This works from inside the App Sandbox, so no helper process is needed. `NowPlayingMonitor` owns the process, restarts it after 10 s if it dies, and claims the ears (priority 3) while something is playing. Because this relies on a private framework, the app can't be distributed through the Mac App Store.
- **Ear handovers.** When the owner of the collapsed ears changes, the old content blurs and shrinks away while the new content comes into focus (`NotchMotion.earContent`, about 0.85 s).
- **App menu.** Right-clicking the expanded notch opens a context menu with **Launch at Login** (`SMAppService.mainApp`; status re-read every time the notch expands, since it can be changed in System Settings) and **Quit Notch**. While any of the app's menus is open (`NSMenu` begin/end tracking notifications) the notch is held open, then the pointer is re-checked when the menu closes.
- **Motion.** Activity animation values live in `NotchMotion`: the old content leaves in 0.1 s, the shape springs open (bounce 0.38) or closed (bounce 0.25), and the new content blurs and scales into focus just after the shape starts moving, so two layouts never overlap.
- **Reduce Motion.** With the system setting on, activities open with a short bounce-free ease instead of a spring (`NotchViewModel` reads `NSWorkspace`, injected for tests) and the charging battery appears already full (`ChargingBattery` reads the SwiftUI environment).
- **Timer.** `TimerState` stores an end date rather than counting ticks, so it can't drift and survives sleep. `TimerController` sleeps once until that date to finish. The view shows the countdown with a `TimelineView` aligned to whole seconds of remaining time, rounded up. While a timer is active it outranks the battery for the collapsed ears (priority 10 vs 0). Notification permission is requested the first time a timer starts, not at launch; when the timer finishes, `NotificationService` posts a "Time's up" banner (shown even while the app is active, via the notification-center delegate).

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
├── Features/
│   ├── Battery/                BatteryStatus, PlugInFilter, BatteryMonitor (+NotchModule)
│   ├── Timer/                  TimerState, TimerController (+NotchModule)
│   ├── Calendar/               CalendarEvent, CalendarMonitor (+NotchModule)
│   ├── Shelf/                  ShelfStore (+NotchModule)
│   └── NowPlaying/             NowPlayingInfo, LineBuffer, NowPlayingBridgeProcess, NowPlayingMonitor (+NotchModule)
├── Services/
│   └── NotificationService.swift   Notification permission and posting
└── Resources/
    └── Assets.xcassets

NowPlayingBridge/           Objective-C dynamic library loaded into /usr/bin/perl (see "Now Playing")
NotchTests/                 Swift Testing suites, mirroring the structure above
Notch.entitlements          Entitlements with no build-setting equivalent (security-scoped bookmarks)
```

Each feature follows the same pattern: a pure value type with the logic (tested), an `@Observable` class that talks to the system, and a `Type+NotchModule.swift` file with its notch UI.

## Known limitations

- The right-click menu is only reachable once the notch is expanded (the collapsed notch lets clicks pass through to the menu bar).
- A login item registered from a debug build points at that build in DerivedData.
- Now Playing depends on private macOS behavior and may break in a future macOS release; the notch keeps working without it.
- The expanded size is fixed at 400×150.
- The timer length is fixed at 25 minutes.
- Tested on a 13" MacBook Air (M4) only.
