## ADDED Requirements

### Requirement: File transfer over ADB tunnel
File transfer between USB-connected devices SHALL use the existing HTTP protocol (prepare-upload / upload / cancel) with the target address pointing to the ADB tunnel endpoint.

#### Scenario: Send files from Windows to Android
- **WHEN** the user selects a phone discovered via USB and initiates a file transfer
- **THEN** the send provider sends HTTP requests to `127.0.0.1:{reverseTunnelPort}`
- **AND** the request reaches the phone's LocalSend server via the ADB reverse tunnel
- **AND** the transfer proceeds identically to a LAN transfer

#### Scenario: Send files from Android to Windows
- **WHEN** the user selects a PC discovered via USB and initiates a file transfer
- **THEN** the send provider sends HTTP requests to `127.0.0.1:{forwardTunnelPort}`
- **AND** the request reaches the PC's LocalSend server via the ADB forward tunnel
- **AND** the transfer proceeds identically to a LAN transfer

#### Scenario: Upload progress reporting
- **WHEN** a file is being transferred over the ADB tunnel
- **THEN** progress is reported in real-time to both the sender and receiver
- **AND** the progress bar/percentage is displayed as with any other transfer

#### Scenario: Transfer cancellation
- **WHEN** the user cancels a file transfer over USB
- **THEN** the cancellation request is sent via the ADB tunnel using the existing cancel endpoint
- **AND** the transfer is interrupted on both sides

### Requirement: Tunnel lifecycle management
ADB tunnels SHALL be created when a device is first detected and cleaned up when the device disconnects or USB scanning is disabled.

#### Scenario: Tunnel creation on connect
- **WHEN** a new Android device is detected via `adb devices`
- **THEN** `adb -s {serial} reverse tcp:{port} tcp:53317` is executed to create the reverse tunnel
- **AND** `adb -s {serial} forward tcp:{port} tcp:53317` is executed to create the forward tunnel

#### Scenario: Tunnel cleanup on disconnect
- **WHEN** a device is no longer listed by `adb devices`
- **THEN** `adb -s {serial} reverse --remove tcp:{port}` removes the reverse tunnel
- **AND** `adb -s {serial} forward --remove tcp:{port}` removes the forward tunnel

#### Scenario: Tunnel cleanup on setting toggle off
- **WHEN** the user disables USB scanning
- **THEN** all active ADB tunnels are removed
- **AND** all USB-discovered devices are removed from the list

### Requirement: Device address resolution
The Device model for USB-connected devices SHALL use `127.0.0.1` as the IP address and the ADB tunnel port as the port number.

#### Scenario: Correct address for HTTP transport
- **WHEN** the send provider sends a request to a USB-discovered device
- **THEN** the request URL is `http://127.0.0.1:{tunnelPort}/api/localsend/v2/...`
- **AND** the request is routed through the ADB tunnel to the remote device
