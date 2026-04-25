## 1. Model Layer

- [x] 1.1 Add `UsbDiscovery` class extending `DiscoveryMethod` in `common/lib/model/device.dart`
- [x] 1.2 Run `dart run build_runner build` to regenerate mappers for `UsbDiscovery`

## 2. Settings & Persistence

- [x] 2.1 Add `usbScanEnabled` bool field to `SettingsState` in `app/lib/model/state/settings_state.dart`
- [x] 2.2 Add `_usbScan` persistence key + getter/setter in `app/lib/provider/persistence_provider.dart`
- [x] 2.3 Add `setUsbScanEnabled()` method to `SettingsService` in `app/lib/provider/settings_provider.dart`

## 3. ADB Utility (Windows)

- [x] 3.1 Create `app/lib/util/native/windows/adb_utils.dart` with:
  - `AdbDevice` data class (serial, status)
  - `AdbUtils.isAvailable()` — find adb.exe in install dir / PATH
  - `AdbUtils.listDevices()` — parse `adb devices` output
  - `AdbUtils.createReverseTunnel(serial, devicePort, localPort)` — `adb reverse`
  - `AdbUtils.removeReverseTunnel(serial, localPort)` — `adb reverse --remove`
  - `AdbUtils.createForwardTunnel(serial, localPort, devicePort)` — `adb forward`
  - `AdbUtils.removeForwardTunnel(serial, localPort)` — `adb forward --remove`
- [x] 3.2 Create `app/lib/util/native/windows/adb_path_provider.dart` with ADB search strategy logic

## 4. USB Scan Provider (Windows)

- [x] 4.1 Create `app/lib/provider/network/usb_scan_provider.dart` with:
  - `UsbScanNotifier` extending `Notifier<Set<String>>` (tracks connected device serials)
  - `start()` — start 3-second polling timer
  - `stop()` — cancel timer, remove all tunnels, clear USB devices from nearby list
  - `_pollDevices()` — call `adb devices`, diff against previous state
  - `_onDeviceConnected(serial)` — create tunnels, probe HTTP `/info`, register device
  - `_onDeviceDisconnected(serial)` — remove tunnels, unregister device
  - Port allocation logic (53318, 53328, 53338...) using `_nextAvailablePort()`
  - Retry logic for HTTP probe (3 attempts, 1s delay)
- [x] 4.2 Integrate `RegisterDeviceAction` call with USB-specific key to avoid IP collision in the `devices` map

## 5. USB Scan Provider (Android)

- [x] 5.1 Create `app/lib/provider/network/usb_scan_android_provider.dart` with:
  - `UsbScanAndroidNotifier` extending `Notifier<bool>` (tracks PC connection state)
  - `start()` — start 3-second polling timer
  - `stop()` — cancel timer, remove PC device from nearby list
  - `_pollPC()` — HTTP GET `127.0.0.1:53319/info`, track consecutive failures
  - Register/unregister PC as nearby device using `RegisterDeviceAction`

## 6. Settings UI

- [x] 6.1 Add USB scan toggle in `app/lib/pages/tabs/settings_tab.dart`:
  - Windows: USB scan toggle in Network section, ADB status indicator
  - Android: USB scan toggle in Network section
  - ADB not found warning on Windows (red text if ADB unavailable)
  - Tooltip/link to USB debugging setup guide on first enable
- [x] 6.2 Wire toggle to start/stop USB scan provider

## 7. USB Badge in Device List

- [x] 7.1 Modify `app/lib/widget/list_tile/device_list_tile.dart`:
  - In badge rendering logic: check `device.discoveryMethods` for `UsbDiscovery`
  - Show `"USB • HTTP"` badge instead of `"LAN • HTTP"` when USB-discovered
  - Use a different badge color for USB devices (visual distinction)

## 8. Init & Lifecycle

- [x] 8.1 In `app/lib/config/init.dart`: if `usbScanEnabled` is true on app start, auto-start USB scanning
- [x] 8.2 Ensure USB scan stops when app goes to background (if applicable)

## 9. Installer & ADB Binary

- [ ] 9.1 Download `adb.exe` and required DLLs (AdbWinApi.dll, AdbWinUsbApi.dll) from Android SDK Platform Tools
- [x] 9.2 Create `windows/adb/` directory in the project with `adb.exe` and DLLs
- [x] 9.3 Update Windows installer configuration (CMakeLists.txt) to bundle `adb/` folder

## 10. Testing & Verification

- [ ] 10.1 Manual test: connect Android phone via USB, enable USB debugging, verify discovery on Windows
- [ ] 10.2 Manual test: send files Windows → Android over USB
- [ ] 10.3 Manual test: send files Android → Windows over USB
- [ ] 10.4 Manual test: unplug cable, verify device removal within 5 seconds
- [ ] 10.5 Manual test: disable USB scanning in settings, verify cleanup
- [ ] 10.6 Manual test: two phones connected simultaneously, verify both discovered
- [ ] 10.7 Manual test: LAN and USB simultaneously, verify no duplicate devices
