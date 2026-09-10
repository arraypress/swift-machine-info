# Swift Machine Info

What this Mac is and how it is doing, as typed values.

```swift
import MachineInfo

let snapshot = await MainActor.run { Machine.snapshot() }
print(snapshot.hardware.chip)                 // Apple M3 Max
print(snapshot.hardware.productName ?? "-")   // MacBook Pro (14-inch, Nov 2023)
print(snapshot.battery?.percentage ?? 100)    // 60
```

## Features

- 🖥️ **Hardware** — model identifier, the marketing name from the device tree (Apple Silicon), chip, P/E core mix, memory
- 🧠 **Memory** — free, active, wired and compressed from the Mach host statistics, plus the kernel's pressure level where readable
- 💾 **Disks** — every browsable volume, with free space told two ways: plain, and counting what APFS could purge
- 🔋 **Battery** — charge, state, cycle count and health (full-charge against design capacity); desktops get `nil`, not zeros
- 🖥️ **Displays** — names from NSScreen, true panel pixels from the display mode (not the scaled logical size), scale, refresh
- 🌐 **Network** — running interfaces with addresses; the Wi-Fi name only when macOS shares it without a location permission
- 🌡️ **OS** — version, build, kernel, uptime, boot time, thermal state
- 🏃 **Running apps** — every launched application with its bundle identifier, pid, whether it is frontmost or hidden, and whether it is a Dock app, a menu-bar agent or a background process; the frontmost app; quit one politely or by force
- 🪟 **Windows** — the window server's list front to back, with the front document window picked out; titles only when macOS will give them
- 📦 **Storage** — free space for one path, plain and counting what APFS could purge, with the used figure
- 🔊 **Audio devices** — every input and output with its transport, the current default output, and a way to change it
- ☕ **Keep awake** — an IOKit power assertion held by a token, released when the token goes, so a crash cannot leave the Mac awake
- 🔒 **No serial numbers** — nothing here can single out one machine among identical ones, deliberately
- ⚡ **No processes launched** — everything is sysctl, IOKit and the frameworks, which is why it is milliseconds, not `system_profiler` seconds

## Running apps

```swift
let apps = await MainActor.run { RunningApps.current() }     // Dock apps, then agents, then background
apps.filter { $0.activationPolicy == .regular }.map(\.name)  // what a person calls "the apps"
await MainActor.run { RunningApps.frontmost()?.name }         // "Safari"
try await MainActor.run { try RunningApps.quit("com.apple.Safari") }          // asks; the app may say no
try await MainActor.run { try RunningApps.quit("Safari", force: true) }       // Force Quit, unsaved work and all
```

The workspace lists three times what the Dock shows — helpers and agents count — so `activationPolicy` is there to filter on. Finder, loginwindow and the calling process are refused outright: quitting them ends the session rather than an app.

## Windows

```swift
Windows.list()                     // front to back, desktop elements left out
await MainActor.run { Windows.front() }   // the frontmost app's first ordinary window
```

Titles are `nil` without the Screen Recording permission, not `""`. Measured on macOS 27 without it: of 24 windows on screen the only title returned was the window server's own menu bar; every application window's was withheld. Owner, pid, bounds and layer come back regardless.

## Storage

```swift
try Storage.free(at: "/")            // total, free, available for important usage, used
```

Two free figures on purpose: plain free space is what a "disk almost full" warning should use; the important-usage figure counts what the system would purge for something that matters, and is what a download should trust.

## Audio devices

```swift
AudioDevices.all()                   // inputs and outputs, with transport and sample rate
AudioDevices.output()                // where sound goes right now
try AudioDevices.setOutput(named: "AirPods")   // a prefix or substring will do if it names exactly one
```

Changing the default output is a user-visible action — the sound menu flips and whatever is playing moves — so say so before doing it on someone's behalf.

## Keeping the Mac awake

```swift
let token = try KeepAwake.begin(reason: "Uploading the archive")
defer { token.end() }
// …
try KeepAwake.while(reason: "Rendering") { render() }   // released on return or throw
```

The same power assertion `caffeinate` takes, without the subprocess and with a scope: the token releases when it is dropped, so a script that dies cannot leave the lid held open. By default only idle system sleep is prevented; pass `preventDisplaySleep: true` for something a person is watching.

## Measured

A full snapshot on an M3 Max: well under a second including process launch (533 ms for the whole CLI run, cold); the test suite budgets 1 s and passes in ~0.1 s warm. Thirty-seven tests assert the snapshot describes the real machine sensibly — a Mac with no cores or an empty root volume is a read gone wrong, not a strange machine.

## Requirements

macOS 14+, Swift 6. Mac-only by nature — the interesting parts (IOKit power sources, the device tree, NSScreen, the workspace, CoreAudio) exist nowhere else. `Machine.snapshot()`, the display section and the running-app readers are main-actor-bound because NSScreen and NSWorkspace own them.

## License

MIT — see LICENSE.
