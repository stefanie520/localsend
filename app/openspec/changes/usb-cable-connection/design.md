## Context

LocalSend discovers and communicates with nearby devices exclusively over LAN (UDP multicast + HTTP subnet scan). When LAN fails — due to AP isolation, firewalls, VPNs, or cross-subnet routing — there is no fallback. USB cable offers a physically reliable alternative that bypasses all network issues.

The target scenario is **Windows PC ↔ Android phone** via USB cable. The existing codebase uses ADB-like patterns for device discovery (isolated tasks, stream-based results, Refena state management), but has no USB-related code.

The key technical constraint is that both sides must be able to discover each other and communicate bidirectionally over the single USB cable.

## Goals / Non-Goals

**Goals:**
- Windows PC can discover an Android phone connected via USB cable, and send/receive files
- Android phone can discover the paired Windows PC over USB, and send/receive files
- Discovery is automatic when USB scanning is enabled in settings
- Devices appear/disappear from the nearby devices list on plug/unplug
- USB-connected devices show a distinguishing badge in the UI
- All file transfer reuses the existing HTTP protocol over ADB TCP tunnels
- ADB binary is bundled with the Windows installer (no user setup required)
- The feature works in any Android USB mode (file transfer, tethering, etc.)

**Non-Goals:**
- Support for iOS devices (USB communication is heavily restricted)
- Support for Linux or macOS hosts (only Windows)
- Support for Android↔Android via OTG cable
- Modification of the existing transport/send/receive code
- Modification of existing LAN discovery mechanisms
- Wi-Fi Direct, Bluetooth, or other wireless alternatives

## Decisions

### Decision 1: ADB reverse/forward tunnels as transport mechanism

ADB provides a reliable TCP tunnel over USB that works regardless of the phone's USB mode (file transfer, tethering, etc.).

**Alternatives considered:**
- *USB tethering (RNDIS)*: Requires the user to manually enable "USB tethering" on the phone every time, which is a friction point. Also changes the phone's network routing.
- *MTP protocol*: Only handles file operations, no bidirectional real-time communication. Incompatible with HTTP-based transfer.
- *libusb/WinUSB direct communication*: Extremely complex, requires custom protocol, platform-specific drivers, and phone-side kernel support.

**Why ADB wins:** It's a well-established, stable protocol. The ADB binary is small (~1.5MB). The TCP tunnel abstraction means zero changes to LocalSend's HTTP transport layer.

### Decision 2: Port allocation scheme for multiple devices

```
                    reverse (PC→Phone)    forward (Phone→PC)
Device 1:           53318                 53319
Device 2:           53328                 53329
Device 3:           53338                 53339
...
```

Each device gets a dedicated pair of ports (base + 0 for reverse, base + 1 for forward), incremented by 10 to leave room. The provider tracks `serial → {reversePort, forwardPort}` in memory.

### Decision 3: Polling-based device detection

Both sides poll at 3-second intervals:
- **Windows**: `adb devices` to list connected phones. Compares with previous state to detect connect/disconnect.
- **Android**: HTTP GET to `127.0.0.1:{forwardPort}/info`. If the PC is reachable via the ADB forward tunnel, it's connected. Three consecutive failures = disconnected.

**Alternatives considered:**
- *USB event hooks (Windows)*: More complex, platform-specific, and doesn't handle the Android side.
- *adb track-devices*: ADB's streaming mode, but adds complexity and is less portable.

**Why polling wins:** Simple, works identically on both sides, and 3-second intervals are fast enough for the plug/unplug use case.

### Decision 4: Separate `UsbDiscovery` method with shared `nearbyDevices` list

USB-discovered devices appear in the same `nearbyDevices` list as LAN-discovered devices, with a `UsbDiscovery` marker in `discoveryMethods`. This allows:
- The existing send UI to handle USB devices without modification
- The `DeviceListTile` to render a USB-specific badge
- `transmissionMethods` to automatically resolve to `http` (reusing HTTP transport)

The device's `ip` is set to `127.0.0.1` (the ADB tunnel endpoint on localhost) and `port` to the tunnel's local port (e.g., 53318 for reverse, 53319 for forward). This allows the existing HTTP upload/download code to work without changes.

### Decision 5: ADB located via search strategy

Priority order:
1. `{app_install_dir}/adb/adb.exe` (bundled with installer)
2. Environment variable `ADB_PATH`
3. System PATH

On first use, if ADB is not found, the settings UI shows a clear error message with installation guidance.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| **ADB binary increases installer size** (~1.5MB) | Acceptable for a core feature. Can be made optional download in future. |
| **ADB protocol changes may break compatibility** | ADB is extremely stable (decade-old protocol). Pin a specific adb.exe version. |
| **User must enable USB debugging on phone** | This is a one-time setup. The settings UI will show clear instructions on first enable. |
| **Multiple phones connected simultaneously** | Port allocation scheme handles up to 10 concurrent devices. Unlikely to be exceeded. |
| **ADB authorization dialog blocks first connection** | After the user accepts the RSA fingerprint, subsequent connections are automatic. |
| **Phone-side scanning consumes battery** | 3-second HTTP probes are negligible. Timer only runs when USB scanning is enabled. |
| **Race condition: ADB tunnel before phone's server ready** | Retry logic: up to 3 attempts with 1-second delays for HTTP probe after creating tunnel. |
| **ADB permission denied on Windows (missing driver)** | Windows 10/11 automatically install ADB driver when phone is connected in debug mode. Document fallback driver install in settings. |
