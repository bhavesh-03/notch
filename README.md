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
| Calendar: "in 8 min" in the ears and a "starting now" activity | ⏳ Next |
| File shelf — drag files onto the notch | 🗓 Planned |
| Music / Now Playing controls | 🗓 Planned |
| Launch at login, signing & notarization | 🗓 Planned |

## Requirements

- macOS 27 or later
- Xcode 27
- A MacBook with a notch for the full experience (other displays get a virtual notch)

## Building and running

1. Open `Notch.xcodeproj` in Xcode.
2. Select the **Notch** scheme and **My Mac** as the destination.
3. Press **⌘R**.

The app runs as an agent (`LSUIElement`): it has **no Dock icon and no menu bar menu**. To quit it, press **Stop (⌘.)** in Xcode, or from a terminal:

```bash
pkill -x Notch
```

## Running the tests

The logic (`TimerState`, `TimerController`, `NotchGeometry`, `BatteryStatus`) is covered by Swift Testing unit tests in `NotchTests/`. Run them with **⌘U** in Xcode, or:

```bash
xcodebuild test -project Notch.xcodeproj -scheme Notch -destination 'platform=macOS'
```

Tests run inside the app, so the notch briefly appears while they execute.

## How it works

```
NotchApp ──▶ AppDelegate ──creates──▶ NotchPanel (borderless NSPanel above the menu bar)
                 │                          └── NSHostingView ──▶ ContentView (SwiftUI, renders modules)
                 │                                                     ▲
                 ├── NSEvent mouse monitors ──▶ NotchViewModel ────────┘ (@Observable)
                 └── screen-change notifications       ├── NotchGeometry   (where the notch is)
                                                       ├── BatteryMonitor  (IOKit power sources)
                                                       └── TimerController (countdown)
```

- **The window.** `NotchPanel` is a transparent, borderless, non-activating `NSPanel` at `mainMenu + 3` window level, visible on every Space and over full-screen apps. SwiftUI content is hosted inside it via `NSHostingView`.
- **Finding the notch.** `NotchGeometry` computes the notch rectangle from `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` (using only their widths, anchored to `screen.frame`) and `safeAreaInsets.top`. Screens without a notch get a centered 180×24 virtual notch built through the same code path. The math lives in a pure initializer so it can be exercised without a real screen.
- **Hover and clicks.** The panel ignores mouse events while collapsed so the menu bar underneath stays usable. Global and local `mouseMoved` monitors hit-test the cursor against the collapsed notch (or the whole panel when expanded). Collapsing is debounced by 300 ms with a cancellable `Task`.
- **State.** `NotchViewModel` is the single source of truth for the view: expansion state, geometry and the battery monitor. AppKit code mutates it; SwiftUI re-renders automatically through `@Observable`.
- **Clicking without stealing focus.** The panel is non-activating, can become key, and uses `becomesKeyOnlyIfNeeded`, so clicking its buttons never takes keyboard focus away from the app you're working in.
- **Battery.** `BatteryMonitor` reads the internal battery through `IOPSCopyPowerSourcesInfo` and refreshes on `kIOPSNotifyAnyPowerSource`. `BatteryStatus` is a plain value type that parses the IOKit dictionary and picks the SF Symbol (bolt when charging, plug when on AC but not charging, e.g. during optimized charging).

- **Modules.** Each feature conforms to `NotchModule`: it reports an `earPriority` (how strongly it wants the collapsed ears right now, or `nil`) and provides content for each `NotchPlacement` (leading ear, trailing ear, pill on screens without a notch, expanded). The highest-priority module owns the ears; every module gets a section in the expanded view. Adding a feature means writing its model, conforming it in a `Type+NotchModule.swift` file, and listing it in `NotchViewModel.modules`.
- **Activities.** `NotchViewModel.presentation` is an enum — `.collapsed`, `.expanded`, or `.activity(module)` — so impossible combinations can't be represented. A module can briefly take over the notch with `showActivity(from:)`: the notch springs out to an activity shape laid out *around* the camera (content in ears on either side plus a detail row below), then collapses on its own after ~2.5 s. Hovering always wins: it turns an activity into the full expanded view. The battery triggers an activity on the plug-in *edge* (not-plugged → plugged), never at launch or when charging merely starts later; the timer triggers one when it finishes.
- **Calendar.** Reading calendars needs two things: the sandbox entitlement `com.apple.security.personal-information.calendars` (build setting `ENABLE_RESOURCE_ACCESS_CALENDARS`) and an `NSCalendarsFullAccessUsageDescription` string, without which macOS silently denies the request. Access is requested only when you click "Show next event" in the expanded notch; if denied, the notch links to the Calendars privacy settings. `CalendarMonitor` refreshes on `EKEventStoreChanged`, so edits in Calendar appear immediately.
- **Charging animation.** The activity's battery is drawn by hand (`ChargingBattery`) because SF Symbols only come in 25% steps: its fill is a custom `BatteryFill` shape whose `animatableData` is the level, so it fills smoothly from empty to the current charge, then the bolt pops in with a bouncy spring. It's always green — at plug-in macOS usually reports "not charging yet" — and the ear icon afterwards shows the accurate state (bolt when charging, plug when on hold). `PlugInFilter` ignores a loose cable reconnecting within 2 seconds.
- **Reduce Motion.** With the system setting on, activities open with a short bounce-free ease instead of a spring (`NotchViewModel` reads `NSWorkspace`, injected for tests) and the charging battery appears already full (`ChargingBattery` reads the SwiftUI environment).
- **Timer.** `TimerState` stores an end date rather than counting ticks, so it can't drift and survives sleep. `TimerController` sleeps once until that date to finish. The view shows the countdown with a `TimelineView` aligned to whole seconds of remaining time, rounded up. While a timer is active it outranks the battery for the collapsed ears (priority 10 vs 0). Notification permission is requested the first time a timer starts, not at launch; when the timer finishes, `NotificationService` posts a "Time's up" banner (shown even while the app is active, via the notification-center delegate).

## Project structure

| File | Responsibility |
|---|---|
| `NotchApp.swift` | App entry point; hooks up the `AppDelegate`, opens no regular windows |
| `AppDelegate.swift` | Creates the panel and view model, installs mouse monitors, handles display changes |
| `NotchPanel.swift` | The borderless, transparent, always-on-top window |
| `NotchGeometry.swift` | Notch / collapsed / panel rectangles for a screen; hardware vs virtual notch |
| `NotchViewModel.swift` | Observable UI state: expanded/collapsed with debounced collapse, geometry, battery |
| `ContentView.swift` | Draws the notch shape and lays out whatever the modules provide; knows nothing about specific features |
| `NotchModule.swift` | The `NotchModule` protocol, `NotchPlacement`, and ear-ownership selection |
| `BatteryMonitor+NotchModule.swift` | Battery's notch UI: ear icon / percentage, expanded section |
| `TimerController+NotchModule.swift` | Timer's notch UI: ear countdown, expanded controls |
| `BatteryStatus.swift` | Pure battery value type and icon selection |
| `BatteryMonitor.swift` | IOKit power-source reading and change notifications |
| `CalendarEvent.swift` | Pure event value and next-event selection (in progress or upcoming, skips all-day) |
| `CalendarMonitor.swift` | EventKit access, querying, and change notifications |
| `CalendarMonitor+NotchModule.swift` | Calendar's notch UI: access button, denied state, next event |
| `PlugInFilter.swift` | Decides whether a plug-in deserves the charging activity (ignores reconnects within 2 s) |
| `TimerState.swift` | Pure countdown state machine (idle / running / paused), date-based so it survives sleep |
| `TimerController.swift` | Live timer: injectable clock, schedules a single wake-up at the end date, `onStart` / `onFinish` hooks |
| `NotificationService.swift` | Notification permission (requested in context) and the "Time's up" notification |
| `NotchTests/` | Swift Testing unit tests for the pure logic: timer, geometry, battery parsing |

## Known limitations

- Quitting requires Xcode or `pkill` until a proper quit control is added.
- The expanded size is fixed at 400×150.
- The timer length is fixed at 25 minutes.
- Tested on a 13" MacBook Air (M4) only.
