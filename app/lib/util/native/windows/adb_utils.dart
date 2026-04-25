import 'dart:convert';
import 'dart:io';

import 'package:localsend_app/util/native/windows/adb_path_provider.dart';
import 'package:logging/logging.dart';

final _logger = Logger('AdbUtils');

class AdbDevice {
  final String serial;
  final String status;

  const AdbDevice({required this.serial, required this.status});

  bool get isAuthorized => status == 'device';
  bool get isUnauthorized => status == 'unauthorized';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AdbDevice && serial == other.serial;

  @override
  int get hashCode => serial.hashCode;

  @override
  String toString() => 'AdbDevice(serial: $serial, status: $status)';
}

class AdbUtils {
  /// Checks if ADB is available on the system.
  static bool isAvailable() {
    return AdbPathProvider.resolve() != null;
  }

  /// Returns the path to the ADB executable, or null if not found.
  static String? getAdbPath() {
    return AdbPathProvider.resolve();
  }

  /// Runs `adb devices` and returns the list of connected devices.
  static Future<List<AdbDevice>> listDevices() async {
    final adbPath = AdbPathProvider.resolve();
    if (adbPath == null) {
      _logger.warning('ADB not found');
      return [];
    }

    try {
      final result = await Process.run(adbPath, ['devices']);
      if (result.exitCode != 0) {
        _logger.warning('adb devices failed: ${result.stderr}');
        return [];
      }

      return _parseDevicesOutput(result.stdout as String);
    } catch (e) {
      _logger.warning('Error running adb devices', e);
      return [];
    }
  }

  /// Creates a reverse tunnel: `adb -s <serial> reverse tcp:<localPort> tcp:<devicePort>`.
  /// This makes the Android device's port accessible on the PC at localhost.
  static Future<bool> createReverseTunnel({
    required String serial,
    required int devicePort,
    required int localPort,
  }) async {
    return _runAdb([
      '-s',
      serial,
      'reverse',
      'tcp:$localPort',
      'tcp:$devicePort',
    ]);
  }

  /// Removes a reverse tunnel: `adb -s <serial> reverse --remove tcp:<localPort>`.
  static Future<bool> removeReverseTunnel({
    required String serial,
    required int localPort,
  }) async {
    return _runAdb([
      '-s',
      serial,
      'reverse',
      '--remove',
      'tcp:$localPort',
    ]);
  }

  /// Creates a forward tunnel: `adb -s <serial> forward tcp:<localPort> tcp:<devicePort>`.
  /// This makes the PC's port accessible on the Android device at localhost.
  static Future<bool> createForwardTunnel({
    required String serial,
    required int devicePort,
    required int localPort,
  }) async {
    return _runAdb([
      '-s',
      serial,
      'forward',
      'tcp:$localPort',
      'tcp:$devicePort',
    ]);
  }

  /// Removes a forward tunnel: `adb -s <serial> forward --remove tcp:<localPort>`.
  static Future<bool> removeForwardTunnel({
    required String serial,
    required int localPort,
  }) async {
    return _runAdb([
      '-s',
      serial,
      'forward',
      '--remove',
      'tcp:$localPort',
    ]);
  }

  static Future<bool> _runAdb(List<String> args) async {
    final adbPath = AdbPathProvider.resolve();
    if (adbPath == null) {
      _logger.warning('ADB not found');
      return false;
    }

    try {
      final result = await Process.run(adbPath, args);
      if (result.exitCode != 0) {
        _logger.warning('ADB command failed: $args, error: ${result.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      _logger.warning('Error running ADB command: $args', e);
      return false;
    }
  }

  /// Parses the output of `adb devices`.
  /// Example output:
  /// ```
  /// List of devices attached
  /// emulator-5554   device
  /// 0123456789ABCDEF        unauthorized
  /// ```
  static List<AdbDevice> _parseDevicesOutput(String output) {
    final lines = LineSplitter.split(output);
    final devices = <AdbDevice>[];
    bool headerPassed = false;

    for (final line in lines) {
      if (!headerPassed) {
        if (line.trim() == 'List of devices attached') {
          headerPassed = true;
        }
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        devices.add(AdbDevice(serial: parts[0], status: parts[1]));
      }
    }

    return devices;
  }
}
