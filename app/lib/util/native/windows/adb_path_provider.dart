import 'dart:io';

class AdbPathProvider {
  static String? _cachedPath;

  /// Resolves the ADB executable path using the search strategy:
  /// 1. Bundled with app: `{app_install_dir}/adb/adb.exe`
  /// 2. Environment variable `ADB_PATH`
  /// 3. System PATH
  static String? resolve() {
    if (_cachedPath != null) return _cachedPath;

    // 1. Check bundled location
    final bundled = _findBundled();
    if (bundled != null) {
      _cachedPath = bundled;
      return bundled;
    }

    // 2. Check ADB_PATH environment variable
    final envPath = Platform.environment['ADB_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      final adbExe = _normalizeAdbPath(envPath);
      if (File(adbExe).existsSync()) {
        _cachedPath = adbExe;
        return adbExe;
      }
    }

    // 3. Check system PATH
    final inPath = _findInPath();
    if (inPath != null) {
      _cachedPath = inPath;
      return inPath;
    }

    return null;
  }

  static void clearCache() {
    _cachedPath = null;
  }

  static String _normalizeAdbPath(String path) {
    if (path.endsWith('adb') || path.endsWith('adb.exe')) {
      return path;
    }
    if (Platform.isWindows && !path.endsWith('.exe')) {
      return '$path\\adb.exe';
    }
    return '$path/adb';
  }

  static String? _findBundled() {
    if (!Platform.isWindows) return null;

    // Check relative to the executable or current directory
    final candidates = [
      'adb/adb.exe',
      '../adb/adb.exe',
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        return file.resolveSymbolicLinksSync();
      }
    }

    return null;
  }

  static String? _findInPath() {
    final pathEnv = Platform.environment['PATH'] ?? '';
    final separator = Platform.isWindows ? ';' : ':';
    final dirs = pathEnv.split(separator);

    for (final dir in dirs) {
      if (dir.isEmpty) continue;
      try {
        final adbExe = Platform.isWindows ? '$dir\\adb.exe' : '$dir/adb';
        final file = File(adbExe);
        if (file.existsSync()) {
          return adbExe;
        }
      } catch (_) {
        // Skip invalid paths
      }
    }

    return null;
  }
}
