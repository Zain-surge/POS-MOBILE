import 'package:epos/config/brand_info.dart';

/// Stores brand-specific credentials used to auto-login to the hosted Admin panel.
///
/// Update the username/password values for the brand(s) you care about. Leaving
/// them blank disables the auto-login helper (the WebView will still load).
class AdminPortalCredentials {
  const AdminPortalCredentials._();

  static const Map<String, Map<String, String>> _brandCredentials = {
    'TVP': {'username': 'admin', 'password': 'surge2002'},
    'Dallas': {'username': '', 'password': ''},
    'SuperSub': {'username': 'admin_12', 'password': 'supersub2389'},
  };

  static String get username =>
      _brandCredentials[BrandInfo.currentBrand]?['username'] ?? '';

  static String get password =>
      _brandCredentials[BrandInfo.currentBrand]?['password'] ?? '';

  static bool get isConfigured =>
      username.trim().isNotEmpty && password.trim().isNotEmpty;
}
