import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';

/// Unique manufacturer identifier.
class ManufacturerId extends ValueObject {
  final String value;
  const ManufacturerId(this.value);

  factory ManufacturerId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return ManufacturerId('mfr_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ManufacturerId &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Pharmaceutical manufacturer entity.
class Manufacturer extends Entity<ManufacturerId> {
  final String name;
  final String contact;
  final String address;
  final DateTime createdAt;

  const Manufacturer({
    required super.id,
    required this.name,
    this.contact = '',
    this.address = '',
    required this.createdAt,
  });

  Manufacturer copyWith({
    String? name,
    String? contact,
    String? address,
  }) {
    return Manufacturer(
      id: id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      address: address ?? this.address,
      createdAt: createdAt,
    );
  }
}