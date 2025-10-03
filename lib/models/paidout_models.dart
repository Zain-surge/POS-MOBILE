// lib/models/paidout_models.dart

class PaidOut {
  String label;
  double amount;

  PaidOut({required this.label, required this.amount});

  Map<String, dynamic> toJson() {
    return {'label': label, 'amount': amount};
  }
}

class PaidOutRecord {
  final int id;
  final String payoutDate;
  final String label;
  final double amount;
  final String brandName;
  final DateTime createdAt;

  PaidOutRecord({
    required this.id,
    required this.payoutDate,
    required this.label,
    required this.amount,
    required this.brandName,
    required this.createdAt,
  });

  factory PaidOutRecord.fromJson(Map<String, dynamic> json) {
    return PaidOutRecord(
      id: json['id'],
      payoutDate: json['payout_date'],
      label: json['label'],
      amount: double.parse(json['amount'].toString()),
      brandName: json['brand_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
