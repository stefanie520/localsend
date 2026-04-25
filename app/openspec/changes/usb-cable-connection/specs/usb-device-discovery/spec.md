## ADDED Requirements

### Requirement: Windows discovers Android phone via ADB
When USB scanning is enabled, the Windows app SHALL automatically discover Android phones connected via USB cable using ADB.

#### Scenario: Phone connected and authorized
- **WHEN** an Android phone with USB debugging enabled is connected via USB and the PC is authorized
- **THEN** the phone appears in the nearby devices list within 5 seconds

#### Scenario: Phone disconnected
- **WHEN** a previously connected phone is unplugged
- **THEN** the phone is removed from the nearby devices list within 5 seconds

#### Scenario: Phone not authorized
- **WHEN** an Android phone is connected but the RSA fingerprint has not been accepted
- **THEN** the phone is NOT added to the nearby devices list (ADB lists it as "unauthorized")

#### Scenario: Multiple phones connected
- **WHEN** multiple Android phones are connected via USB simultaneously
- **THEN** each phone appears as a separate device in the nearby devices list

#### Scenario: ADB not found
- **WHEN** the user enables USB scanning but ADB is not available on the system
- **THEN** the UI shows a clear error message indicating ADB is required

### Requirement: Android discovers Windows PC via ADB forward tunnel
When USB scanning is enabled on Android, the app SHALL periodically probe the ADB forward tunnel to detect the Windows PC.

#### Scenario: PC connected
- **WHEN** the Android phone is connected via USB and the ADB forward tunnel is active
- **THEN** the PC appears in the nearby devices list within 5 seconds

#### Scenario: PC disconnected
- **WHEN** the USB cable is removed or the PC shuts down LocalSend
- **THEN** the PC is removed from the nearby devices list within 10 seconds (3 failed probes)

#### Scenario: PC reconnected
- **WHEN** the USB cable is reconnected after a brief disconnection
- **THEN** the PC reappears in the nearby devices list without requiring a manual rescan

### Requirement: USB device identification
USB-connected devices SHALL carry a `UsbDiscovery` marker that distinguishes them from LAN-discovered devices.

#### Scenario: Discovery method attribution
- **WHEN** a device is discovered via USB scanning
- **THEN** its `discoveryMethods` contains `UsbDiscovery`
- **AND** `transmissionMethods` resolves to `http`

#### Scenario: Deduplication with LAN discovery
- **WHEN** a device is simultaneously reachable via LAN and USB
- **THEN** its `discoveryMethods` contains both `HttpDiscovery` and `UsbDiscovery`
- **AND** it appears only once in the nearby devices list

### Requirement: USB scan settings
The app SHALL provide a settings toggle to enable or disable USB scanning.

#### Scenario: Enable USB scanning
- **WHEN** the user enables USB scanning in settings
- **THEN** the USB scanner starts polling for connected devices

#### Scenario: Disable USB scanning
- **WHEN** the user disables USB scanning in settings
- **THEN** the USB scanner stops polling and all USB-discovered devices are removed from the nearby devices list
