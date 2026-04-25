import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/windows/adb_utils.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('UsbScan');

/// Port allocation base for USB devices.
/// Each device gets a pair: reversePort = base + 0, forwardPort = base + 1.
/// Increment by 10 for each device to leave room.
const _portBase = 53318;
const _portStep = 10;

/// The LocalSend server port on the device.
const _localsendPort = 53317;

/// The default HTTP probe timeout.
const _probeTimeout = Duration(seconds: 3);

/// Maximum retries for HTTP probe after creating a tunnel.
const _maxProbeRetries = 3;

/// Polling interval.
const _pollInterval = Duration(seconds: 3);

final usbScanProvider = NotifierProvider<UsbScanNotifier, Set<String>>((ref) {
  return UsbScanNotifier(ref);
});

/// Tracks the port allocation for each connected USB device.
class _UsbPorts {
  final int reversePort;
  final int forwardPort;

  const _UsbPorts({required this.reversePort, required this.forwardPort});
}

class UsbScanNotifier extends Notifier<Set<String>> {
  final Ref _ref;
  Timer? _timer;
  int _nextDeviceIndex = 0;
  final Map<String, _UsbPorts> _devicePorts = {};

  UsbScanNotifier(this._ref);

  @override
  Set<String> init() => {};

  /// Starts the USB scan polling timer (Windows only).
  void start() {
    if (!checkPlatform([TargetPlatform.windows])) return;
    if (_timer != null) return;

    _logger.info('Starting USB scan');
    _timer = Timer.periodic(_pollInterval, (_) => _pollDevices());
    _pollDevices();
  }

  /// Stops the USB scan, removes all tunnels and cleans up devices.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;

    _logger.info('Stopping USB scan, cleaning up ${_devicePorts.length} devices');
    for (final serial in _devicePorts.keys.toList()) {
      await _onDeviceDisconnected(serial);
    }
  }

  Timer? get timer => _timer;

  /// Gets the device key for a given serial number.
  static String deviceKeyFromSerial(String serial) => 'usb_$serial';

  void _pollDevices() async {
    try {
      final devices = await AdbUtils.listDevices();
      final connectedSerials = devices
          .where((d) => d.isAuthorized)
          .map((d) => d.serial)
          .toSet();

      for (final serial in _devicePorts.keys.toList()) {
        if (!connectedSerials.contains(serial)) {
          await _onDeviceDisconnected(serial);
        }
      }

      for (final serial in connectedSerials) {
        if (!_devicePorts.containsKey(serial)) {
          await _onDeviceConnected(serial);
        }
      }

      state = connectedSerials;
    } catch (e) {
      _logger.warning('Error polling USB devices', e);
    }
  }

  Future<void> _onDeviceConnected(String serial) async {
    _logger.info('USB device connected: $serial');

    final ports = _allocatePorts();
    _devicePorts[serial] = ports;

    await AdbUtils.createReverseTunnel(
      serial: serial,
      devicePort: _localsendPort,
      localPort: ports.reversePort,
    );

    await AdbUtils.createForwardTunnel(
      serial: serial,
      devicePort: _localsendPort,
      localPort: ports.forwardPort,
    );

    await _probeDevice(serial, ports);
  }

  Future<void> _probeDevice(String serial, _UsbPorts ports) async {
    for (int attempt = 0; attempt < _maxProbeRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(seconds: 1));
      }

      try {
        final client = HttpClient();
        client.connectionTimeout = _probeTimeout;
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${ports.reversePort}/api/localsend/v2/info'),
        );
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          _logger.info('USB device responded on reverse tunnel: $serial');
          _registerDevice(serial, ports, body);
          client.close();
          return;
        }
        client.close();
      } catch (e) {
        _logger.info('USB probe attempt $attempt failed for $serial: $e');
      }
    }

    _logger.warning('USB device $serial did not respond after $_maxProbeRetries attempts');
  }

  void _registerDevice(String serial, _UsbPorts ports, String? infoBody) {
    String alias = 'Android ($serial)';
    String? deviceModel;
    String version = 'unknown';
    String fingerprint = serial;
    DeviceType deviceType = DeviceType.mobile;

    if (infoBody != null && infoBody.isNotEmpty) {
      try {
        final info = jsonDecode(infoBody) as Map<String, dynamic>;
        alias = info['alias'] as String? ?? alias;
        deviceModel = info['deviceModel'] as String?;
        version = info['version'] as String? ?? version;
        fingerprint = info['fingerprint'] as String? ?? fingerprint;
        if (info['deviceType'] != null) {
          deviceType = DeviceType.values.firstWhere(
            (t) => t.name == info['deviceType'],
            orElse: () => DeviceType.mobile,
          );
        }
      } catch (_) {}
    }

    final device = Device(
      signalingId: null,
      ip: '127.0.0.1',
      version: version,
      port: ports.reversePort,
      https: false,
      fingerprint: fingerprint,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType,
      download: true,
      discoveryMethods: {const UsbDiscovery()},
    );

    _ref.redux(nearbyDevicesProvider).dispatch(RegisterUsbDeviceAction(serial, device));
  }

  Future<void> _onDeviceDisconnected(String serial) async {
    _logger.info('USB device disconnected: $serial');

    final ports = _devicePorts.remove(serial);
    if (ports != null) {
      await AdbUtils.removeReverseTunnel(serial: serial, localPort: ports.reversePort);
      await AdbUtils.removeForwardTunnel(serial: serial, localPort: ports.forwardPort);
    }

    _ref.redux(nearbyDevicesProvider).dispatch(UnregisterUsbDeviceAction(serial));
  }

  _UsbPorts _allocatePorts() {
    final index = _nextDeviceIndex++;
    final base = _portBase + index * _portStep;
    return _UsbPorts(reversePort: base, forwardPort: base + 1);
  }
}

/// Registers a USB-discovered device in the nearby devices list.
/// Uses a compound key (`usb_{serial}`) to avoid IP collision in the [devices] map.
class RegisterUsbDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final String serial;
  final Device device;

  RegisterUsbDeviceAction(this.serial, this.device);

  @override
  bool get trackOrigin => false;

  @override
  NearbyDevicesState reduce() {
    final key = UsbScanNotifier.deviceKeyFromSerial(serial);
    return state.copyWith(
      devices: {...state.devices}..update(key, (_) => device, ifAbsent: () => device),
    );
  }
}

/// Removes a USB-discovered device from the nearby devices list.
class UnregisterUsbDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final String serial;

  UnregisterUsbDeviceAction(this.serial);

  @override
  NearbyDevicesState reduce() {
    final key = UsbScanNotifier.deviceKeyFromSerial(serial);
    return state.copyWith(
      devices: {...state.devices}..remove(key),
    );
  }
}
