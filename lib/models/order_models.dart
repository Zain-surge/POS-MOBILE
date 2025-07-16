// lib/models/order_models.dart

class CustomerDetails {
  final String name;
  final String phoneNumber;
  final String? email;
  final String? streetAddress;
  final String? city;
  final String? postalCode;

  CustomerDetails({
    required this.name,
    required this.phoneNumber,
    this.email,
    this.streetAddress,
    this.city,
    this.postalCode,
  });
}

class PaymentDetails {
  final String paymentType;
  final double? amountReceived;
  final double discountPercentage;

  PaymentDetails({
    required this.paymentType,
    this.amountReceived,
    required this.discountPercentage,
  });
}