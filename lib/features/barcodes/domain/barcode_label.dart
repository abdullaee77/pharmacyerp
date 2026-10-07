import '../../../core/domain/value_object.dart';

/// Barcode label print format configurations.
enum LabelSize {
  small(label: 'Small (30x20mm)', widthMm: 30, heightMm: 20),
  medium(label: 'Medium (50x30mm)', widthMm: 50, heightMm: 30),
  large(label: 'Large (70x40mm)', widthMm: 70, heightMm: 40),
  shelf(label: 'Shelf Label (100x30mm)', widthMm: 100, heightMm: 30);

  final String label;
  final int widthMm;
  final int heightMm;

  const LabelSize({
    required this.label,
    required this.widthMm,
    required this.heightMm,
  });
}

/// Barcode print job configuration value object.
class BarcodeLabel extends ValueObject {
  final String barcode;
  final String medicineName;
  final String price;
  final String? strength;
  final LabelSize size;
  final int quantity;
  final bool includePrice;
  final bool includeName;

  const BarcodeLabel({
    required this.barcode,
    required this.medicineName,
    required this.price,
    this.strength,
    this.size = LabelSize.medium,
    this.quantity = 1,
    this.includePrice = true,
    this.includeName = true,
  });

  BarcodeLabel copyWith({
    LabelSize? size,
    int? quantity,
    bool? includePrice,
    bool? includeName,
  }) {
    return BarcodeLabel(
      barcode: barcode,
      medicineName: medicineName,
      price: price,
      strength: strength,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      includePrice: includePrice ?? this.includePrice,
      includeName: includeName ?? this.includeName,
    );
  }
}