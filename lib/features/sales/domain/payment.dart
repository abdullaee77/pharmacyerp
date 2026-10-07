import '../../medicines/domain/value_objects.dart';

/// Payment method options for a sale.
enum PaymentMethod {
  cash(label: 'Cash'),
  card(label: 'Card'),
  bank(label: 'Bank Transfer'),
  credit(label: 'Credit (Customer)');

  final String label;
  const PaymentMethod({required this.label});
}

/// A single payment tender (used for split payments too).
class PaymentTender {
  final PaymentMethod method;
  final Money amount;
  final String? reference;

  const PaymentTender({
    required this.method,
    required this.amount,
    this.reference,
  });

  Map<String, dynamic> toJson() => {
    'method': method.name,
    'amount': amount.paisa,
    'reference': reference,
  };

  factory PaymentTender.fromJson(Map<String, dynamic> json) => PaymentTender(
    method: PaymentMethod.values.firstWhere(
          (e) => e.name == json['method'],
      orElse: () => PaymentMethod.cash,
    ),
    amount: Money.fromPaisa(json['amount'] as int),
    reference: json['reference'] as String?,
  );
}