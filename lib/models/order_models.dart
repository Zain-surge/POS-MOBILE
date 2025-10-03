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
  final double totalCharge;
  final double changeDue;
  final bool paidStatus;

  PaymentDetails({
    required this.paymentType,
    this.amountReceived,
    required this.discountPercentage,
    required this.totalCharge,
    this.paidStatus = true, // Default to paid
  }) : changeDue = (paymentType.toLowerCase() == 'cash' && amountReceived != null)
      ? (amountReceived - totalCharge).clamp(0.0, double.infinity)
      : (paymentType.toLowerCase() == 'card & cash' && amountReceived != null)
      ? (amountReceived - totalCharge).clamp(0.0, double.infinity)
      : 0.0;
}