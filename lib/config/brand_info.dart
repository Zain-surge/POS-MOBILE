// lib/config/brand_info.dart
class BrandInfo {

  static const String _currentBrand = 'DALLAS'; // this value will be changed for multiple brands

  static const Map<String, String> _brandConfigs = {
    'TVP': 'TVP',
    'DALLAS': 'DALLAS'
  };

  // Getter to get current brand value
  static String get currentBrand => _brandConfigs[_currentBrand] ?? _currentBrand;

  // Method to get headers with brand included
  static Map<String, String> getDefaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'brand': currentBrand,
    };
  }
}