import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('UsbScanAndroid');

/// The forward tunnel port on Android side (maps to PC's LocalSend server).
/// See port allocation: forwardPort = base + 1 (53319 for first device).
const _forwardPort = 53319;

/// How often to probe the PC.
const _pollInterval = Duration(seconds: 3);

/// Number of consecutive failures before considering the PC disconnected.
const _maxConsecutiveFailures = 3;

final usbScanAndroidProvider = NotifierProvider<UsbScanAndroidNotifier, bool>((ref) {
  return UsbScanAndroidNotifier(ref);
});

class UsbScanAndroidNotifier extends Notifier<bool> {
  final Ref _ref;
  Timer? _timer;
  int _consecutiveFailures = 0;
  bool _wasConnected = false;

  UsbScanAndroidNotifier(this._ref);

  @override
  bool init() => false;

  /// Starts the USB scan polling timer (Android only).
  void start() {
    if (!checkPlatform([TargetPlatform.android])) return;
    if (_timer != null) return;

    _logger.info('Starting USB scan (Android)');
    _timer = Timer.periodic(_pollInterval, (_) => _pollPC());
    _pollPC();
  }

  /// Stops the USB scan and removes the PC device.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _consecutiveFailures = 0;

    if (_wasConnected) {
      _unregisterPC();
    }
    state = false;
  }

  Timer? get timer => _timer;

  void _pollPC() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$_forwardPort/api/localsend/v2/info'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        _consecutiveFailures = 0;

        if (!_wasConnected) {
          _logger.info('PC detected via ADB forward tunnel');
          _registerPC(body);
          _wasConnected = true;
          state = true;
        }
        client.close();
        return;
      }
      client.close();
    } catch (_) {}

    _consecutiveFailures++;
    _logger.finest('USB probe failed ($_consecutiveFailures/$_maxConsecutiveFailures)');

    if (_wasConnected && _consecutiveFailures >= _maxConsecutiveFailures) {
      _logger.info('PC disconnected (USB)');
      _unregisterPC();
      _wasConnected = false;
      state = false;
    }
  }

  void _registerPC(String infoBody) {
    String alias = 'Windows PC';
    String? deviceModel;
    String version = 'unknown';
    String fingerprint = 'usb_pc';

    try {
      final info = jsonDecode(infoBody) as Map<String, dynamic>;
      alias = info['alias'] as String? ?? alias;
      deviceModel = info['deviceModel'] as String?;
      version = info['version'] as String? ?? version;
      fingerprint = info['fingerprint'] as String? ?? fingerprint;
    } catch (_) {}

    final device = Device(
      signalingId: null,
      ip: '127.0.0.1',
      version: version,
      port: _forwardPort,
      https: false,
      fingerprint: fingerprint,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: DeviceType.desktop,
      download: true,
      discoveryMethods: {const UsbDiscovery()},
    );

    _ref.redux(nearbyDevicesProvider).dispatch(RegisterUsbScanAndroidDeviceAction(device));
  }

  void _unregisterPC() {
    _ref.redux(nearbyDevicesProvider).dispatch(UnregisterUsbScanAndroidDeviceAction());
  }
}

/// Registers the PC discovered via USB on Android.
class RegisterUsbScanAndroidDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Device device;

  RegisterUsbScanAndroidDeviceAction(this.device);

  @override
  bool get trackOrigin => false;

  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      devices: {...state.devices}..update('usb_pc', (_) => device, ifAbsent: () => device),
    );
  }
}

/// Removes the USB-connected PC from nearby devices on Android.
class UnregisterUsbScanAndroidDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  UnregisterUsbScanAndroidDeviceAction();

  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      devices: {...state.devices}..remove('usb_pc'),
    );
  }
}
