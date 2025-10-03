// lib/config/brand_info.dart
class BrandInfo {
  static const String _currentBrand =
      'Dallas'; // Change this value to switch brands

  static const Map<String, String> _brandConfigs = {
    'TVP': 'TVP',
    'Dallas': 'Dallas',
    'SuperSub': 'SuperSub',
  };

  // Getter to get current brand value
  static String get currentBrand =>
      _brandConfigs[_currentBrand] ?? _currentBrand;

  // Method to get headers with brand included
  static Map<String, String> getDefaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'brand': currentBrand,
      'x-client-id': currentBrand,
    };
  }
}
