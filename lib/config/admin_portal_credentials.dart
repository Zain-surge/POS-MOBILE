import 'package:epos/config/brand_info.dart';

/// Stores brand-specific credentials used to auto-login to the hosted Admin panel.
///
/// Update the username/password values for the brand(s) you care about. Leaving
/// them blank disables the auto-login helper (the WebView will still load).
class AdminPortalCredentials {
  const AdminPortalCredentials._();

  /// Load credentials from compile-time environment (dart-define) to avoid
  /// hard-coding secrets in source.
  ///
  /// Examples:
  ///   --dart-define=ADMIN_USERNAME_TVP=admin
  ///   --dart-define=ADMIN_PASSWORD_TVP=secret
  static final Map<String, Map<String, String>> _brandCredentials = {
    'TVP': {
      'username': const String.fromEnvironment('ADMIN_USERNAME_TVP'),
      'password': const String.fromEnvironment('ADMIN_PASSWORD_TVP'),
    },
    'Dallas': {
      'username': const String.fromEnvironment('ADMIN_USERNAME_DALLAS'),
      'password': const String.fromEnvironment('ADMIN_PASSWORD_DALLAS'),
    },
    'SuperSub': {
      'username': const String.fromEnvironment('ADMIN_USERNAME_SUPERSUB'),
      'password': const String.fromEnvironment('ADMIN_PASSWORD_SUPERSUB'),
    },
  };

  static String get username =>
      _brandCredentials[BrandInfo.currentBrand]?['username'] ?? '';

  static String get password =>
      _brandCredentials[BrandInfo.currentBrand]?['password'] ?? '';

  static bool get isConfigured =>
      username.trim().isNotEmpty && password.trim().isNotEmpty;
}
