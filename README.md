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
| Shared module system and notch "activities" (e.g. charging animation) | ⏳ Next |
| Calendar — next event | 🗓 Planned |
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
                 │                          └── NSHostingView ──▶ ContentView (SwiftUI)
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

- **Timer.** `TimerState` stores an end date rather than counting ticks, so it can't drift and survives sleep. `TimerController` sleeps once until that date to finish. The view shows the countdown with a `TimelineView` aligned to whole seconds of remaining time, rounded up. While a timer is active it takes over the collapsed ears from the battery. Notification permission is requested the first time a timer starts, not at launch; when the timer finishes, `NotificationService` posts a "Time's up" banner (shown even while the app is active, via the notification-center delegate).

## Project structure

| File | Responsibility |
|---|---|
| `NotchApp.swift` | App entry point; hooks up the `AppDelegate`, opens no regular windows |
| `AppDelegate.swift` | Creates the panel and view model, installs mouse monitors, handles display changes |
| `NotchPanel.swift` | The borderless, transparent, always-on-top window |
| `NotchGeometry.swift` | Notch / collapsed / panel rectangles for a screen; hardware vs virtual notch |
| `NotchViewModel.swift` | Observable UI state: expanded/collapsed with debounced collapse, geometry, battery |
| `ContentView.swift` | SwiftUI drawing of the notch in both states, plus previews |
| `BatteryStatus.swift` | Pure battery value type and icon selection |
| `BatteryMonitor.swift` | IOKit power-source reading and change notifications |
| `TimerState.swift` | Pure countdown state machine (idle / running / paused), date-based so it survives sleep |
| `TimerController.swift` | Live timer: injectable clock, schedules a single wake-up at the end date, `onStart` / `onFinish` hooks |
| `NotificationService.swift` | Notification permission (requested in context) and the "Time's up" notification |
| `NotchTests/` | Swift Testing unit tests for the pure logic: timer, geometry, battery parsing |

## Known limitations

- Quitting requires Xcode or `pkill` until a proper quit control is added.
- The expanded size is fixed at 400×150.
- The timer length is fixed at 25 minutes.
- Tested on a 13" MacBook Air (M4) only.
