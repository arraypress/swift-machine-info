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
- 🔒 **No serial numbers** — nothing here can single out one machine among identical ones, deliberately
- ⚡ **No processes launched** — everything is sysctl, IOKit and the frameworks, which is why it is milliseconds, not `system_profiler` seconds

## Measured

A full snapshot on an M3 Max: well under a second including process launch (533 ms for the whole CLI run, cold); the test suite budgets 1 s and passes in ~0.1 s warm. Eight tests assert the snapshot describes the real machine sensibly — a Mac with no cores or an empty root volume is a read gone wrong, not a strange machine.

## Requirements

macOS 14+, Swift 6. Mac-only by nature — the interesting parts (IOKit power sources, the device tree, NSScreen) exist nowhere else. `Machine.snapshot()` and the display section are main-actor-bound because NSScreen owns the display names.

## License

MIT — see LICENSE.
