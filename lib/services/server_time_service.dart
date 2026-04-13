// lib/services/server_time_service.dart

import 'package:hive/hive.dart';

class ServerTimeService {
  static DateTime? _lastKnownServerTime;
  static DateTime? _lastSyncDeviceTime;

  static const String _boxName = 'server_time';
  static const String _keyServerTime = 'last_known_server_time';
  static const String _keySyncDeviceTime = 'last_sync_device_time';
  static Box? _box;

  /// Initialize Hive box and load persisted values (call on app startup).
  static Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
    _loadFromBox();
  }

  static void _loadFromBox() {
    if (_box == null || !_box!.isOpen) return;

    final serverIso = _box!.get(_keyServerTime) as String?;
    final syncIso = _box!.get(_keySyncDeviceTime) as String?;

    final serverTime =
        serverIso != null ? DateTime.tryParse(serverIso) : null;
    final syncTime = syncIso != null ? DateTime.tryParse(syncIso) : null;

    if (serverTime != null && syncTime != null) {
      _lastKnownServerTime = serverTime;
      _lastSyncDeviceTime = syncTime;
    }
  }

  static void _saveToBox() {
    if (_box == null || !_box!.isOpen) return;
    if (_lastKnownServerTime == null || _lastSyncDeviceTime == null) return;

    _box!.put(_keyServerTime, _lastKnownServerTime!.toIso8601String());
    _box!.put(_keySyncDeviceTime, _lastSyncDeviceTime!.toIso8601String());
  }

  /// Update server time from the most recent order's created_at
  static void updateFromMostRecentOrder(DateTime orderCreatedAt) {
    _lastKnownServerTime = orderCreatedAt;
    _lastSyncDeviceTime = DateTime.now();
    print('✅ Server time synced: $orderCreatedAt');
    _saveToBox();
  }

  /// Get current server time (extrapolated from last known server time)
  static DateTime now() {
    if (_lastKnownServerTime == null || _lastSyncDeviceTime == null) {
      _loadFromBox();
    }
    if (_lastKnownServerTime == null || _lastSyncDeviceTime == null) {
      // Fallback to device time if no sync yet
      return DateTime.now();
    }

    // Calculate elapsed time since last sync
    final elapsed = DateTime.now().difference(_lastSyncDeviceTime!);

    // Add elapsed time to last known server time
    return _lastKnownServerTime!.add(elapsed);
  }

  /// Check if we have synced with server
  static bool isSynced() {
    return _lastKnownServerTime != null;
  }
}
