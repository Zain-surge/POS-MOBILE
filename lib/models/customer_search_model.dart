// lib/models/customer_search_model.dart

class CustomerAddressSearch {
  final String street;
  final String city;
  final String? county; // Made nullable as per example response
  final String postalCode;

  CustomerAddressSearch({
    required this.street,
    required this.city,
    this.county,
    required this.postalCode,
  });

  factory CustomerAddressSearch.fromJson(Map<String, dynamic> json) {
    return CustomerAddressSearch(
      street: json['street'] as String,
      city: json['city'] as String,
      county: json['county'] as String?, // Nullable
      postalCode: json['postal_code'] as String,
    );
  }
}

class CustomerSearchResponse {
  final String source;
  final String name;
  final String? email; // Email can be null in the response
  final CustomerAddressSearch?
  address; // Address can be null if not present/relevant
  final String phoneNumber; // Backend might return cleaned number

  CustomerSearchResponse({
    required this.source,
    required this.name,
    this.email,
    this.address,
    required this.phoneNumber,
  });

  factory CustomerSearchResponse.fromJson(Map<String, dynamic> json) {
    return CustomerSearchResponse(
      source: json['source'] as String,
      name: json['name'] as String,
      email: json['email'] as String?, // Handle nullable email
      address:
          json['address'] != null
              ? CustomerAddressSearch.fromJson(
                json['address'] as Map<String, dynamic>,
              )
              : null, // Handle nullable address
      phoneNumber: json['phone_number'] as String,
    );
  }
}
