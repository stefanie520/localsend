## Why

LocalSend only discovers nearby devices via LAN (UDP multicast and HTTP subnet scan), which frequently fails due to WiFi AP isolation, firewall rules, different subnets, VPNs, or enterprise network policies. USB data cable provides a reliable physical connection that completely bypasses network issues — but LocalSend currently has no USB support. Adding USB-based device discovery and file transfer solves this for the most common scenario: Windows PC ↔ Android phone.

## What Changes

- **New `UsbDiscovery` method** in the device discovery model, treated alongside existing `MulticastDiscovery`, `HttpDiscovery`, `SignalingDiscovery`
- **ADB-based USB scanning on Windows**: detect Android phones connected via USB, create ADB reverse/forward TCP tunnels, discover and register as nearby devices
- **Localhost-based USB scanning on Android**: detect the PC-side LocalSend server through the ADB forward tunnel
- **New settings toggle**: "USB scanning" switch in the network settings section, available on both Windows and Android
- **ADB binary bundled** with the Windows installer so users don't need to install Android SDK
- **USB badge in UI**: USB-connected devices show a "USB • HTTP" badge in the device list to distinguish from LAN-discovered devices
- **Automatic connect/disconnect**: USB devices appear when the cable is plugged in and disappear when unplugged, with no manual scan required

## Capabilities

### New Capabilities
- `usb-device-discovery`: Discover Android phones connected via USB cable to Windows PC, and vice versa, using ADB reverse/forward tunnels. Handle connect/disconnect events.
- `usb-file-transfer`: Transmit files between USB-connected devices using the existing HTTP protocol over ADB TCP tunnels. Reuse all existing send/receive infrastructure.

### Modified Capabilities

None. This is a purely additive feature with no changes to existing behavior.

## Impact

- **Model** (`common/lib/model/device.dart`): New `UsbDiscovery` subclass of `DiscoveryMethod`
- **Settings** (`app/lib/`): New `usbScanEnabled` boolean in `SettingsState`, persistence, and provider
- **New provider** (`app/lib/provider/network/usb_scan_provider.dart`): USB scanning lifecycle and state
- **New ADB utility** (`app/lib/util/native/windows/adb_utils.dart`): ADB process invocation on Windows
- **New provider** (`app/lib/provider/network/usb_scan_android_provider.dart`): Android-side localhost probe logic
- **UI**: Settings toggle (Windows + Android), USB badge in `DeviceListTile`
- **Installer**: Bundle `adb.exe` and required DLLs with Windows build
- **No changes** to the transport layer (send/receive HTTP protocol), existing discovery mechanisms, or the Rust core
