import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/value_objects.dart';

class CustomerId extends ValueObject {
  final String value;
  const CustomerId(this.value);

  factory CustomerId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return CustomerId('cus_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum CustomerStatus {
  active(label: 'Active'),
  inactive(label: 'Inactive'),
  blocked(label: 'Blocked');

  final String label;
  const CustomerStatus({required this.label});
}

class Customer extends Entity<CustomerId> {
  final String name;
  final String phone;
  final String email;
  final String address;
  final Money creditLimit;
  final CustomerStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required super.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.creditLimit = const Money(paisa: 0),
    this.status = CustomerStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    Money? creditLimit,
    CustomerStatus? status,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      creditLimit: creditLimit ?? this.creditLimit,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// A customer with their current outstanding balance snapshot.
class CustomerWithBalance {
  final Customer customer;
  final Money outstanding;
  final DateTime? lastActivityAt;

  const CustomerWithBalance({
    required this.customer,
    required this.outstanding,
    this.lastActivityAt,
  });
}
