// lib/services/uk_time_service.dart (FIXED)

import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:intl/intl.dart';

class UKTimeService {
  static late tz.Location _london;
  static bool _isInitialized = false;

  // Initialize the time zone database once
  static void initializeTimeZones() {
    if (_isInitialized) return;
    tzdata.initializeTimeZones();
    _london = tz.getLocation('Europe/London');
    _isInitialized = true;
  }

  // Get the current UK time properly using timezone package
  static DateTime now() {
    if (!_isInitialized) {
      initializeTimeZones();
    }

    // Get UK time directly from timezone
    final ukTime = tz.TZDateTime.now(_london);

    // Convert to DateTime object for compatibility
    return DateTime(
      ukTime.year,
      ukTime.month,
      ukTime.day,
      ukTime.hour,
      ukTime.minute,
      ukTime.second,
      ukTime.millisecond,
    );
  }

  // Alternative method: Get UK time directly from timezone
  static tz.TZDateTime nowTZ() {
    if (!_isInitialized) {
      initializeTimeZones();
    }
    return tz.TZDateTime.now(_london);
  }

  // Get the current local time in the UK and format it
  static String nowFormatted() {
    final nowInUK = now();
    final formatter = DateFormat('hh:mm a', 'en_GB');
    return formatter.format(nowInUK);
  }

  // Debug method to see what's happening
  static void debugTime() {
    if (!_isInitialized) {
      initializeTimeZones();
    }

    final utcNow = DateTime.now().toUtc();
    final ukTime = tz.TZDateTime.now(_london);
    final convertedUKTime = now();

    print('DEBUG UKTimeService:');
    print('  UTC Now: $utcNow');
    print('  UK Time (TZ): $ukTime');
    print('  UK Time (converted): $convertedUKTime');
    print('  UK Offset: ${_london.currentTimeZone.offset}ms');
  }
}
