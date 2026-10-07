import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/value_objects.dart';

class SupplierId extends ValueObject {
  final String value;
  const SupplierId(this.value);

  factory SupplierId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return SupplierId('sup_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum SupplierStatus {
  active(label: 'Active'),
  inactive(label: 'Inactive');

  final String label;
  const SupplierStatus({required this.label});
}

class Supplier extends Entity<SupplierId> {
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String paymentTerms;
  final SupplierStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required super.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.paymentTerms = '',
    this.status = SupplierStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  Supplier copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    SupplierStatus? status,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class SupplierWithBalance {
  final Supplier supplier;
  final Money payable;
  final DateTime? lastActivityAt;

  const SupplierWithBalance({
    required this.supplier,
    required this.payable,
    this.lastActivityAt,
  });
}
