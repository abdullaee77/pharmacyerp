import 'dart:math';
import '../../../core/domain/value_object.dart';
import '../../inventory/domain/batch.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';

/// Unique in-memory cart line identifier.
class CartItemId extends ValueObject {
  final String value;
  const CartItemId(this.value);

  factory CartItemId.generate() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(9999);
    return CartItemId('line_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CartItemId &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Immutable snapshot of a cart line.
///
/// Prices are snapshotted at the moment of addition so later master data
/// changes do not retroactively modify the current transaction.
class CartItem extends ValueObject {
  final CartItemId id;
  final Medicine medicine;
  final Batch batch;
  final int quantity;
  final Money unitPrice;
  final int discountPercent;

  const CartItem({
    required this.id,
    required this.medicine,
    required this.batch,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
  });

  /// Line gross = quantity × unit price.
  Money get grossTotal => Money.fromPaisa(unitPrice.paisa * quantity);

  /// Discount amount in paisa.
  Money get discountAmount =>
      Money.fromPaisa((grossTotal.paisa * discountPercent) ~/ 100);

  /// Final line total = gross - discount.
  Money get lineTotal =>
      Money.fromPaisa(grossTotal.paisa - discountAmount.paisa);

  CartItem copyWith({
    int? quantity,
    int? discountPercent,
    Batch? batch,
  }) {
    return CartItem(
      id: id,
      medicine: medicine,
      batch: batch ?? this.batch,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CartItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Aggregate totals for the entire cart.
class CartTotals extends ValueObject {
  final int itemCount;
  final int totalUnits;
  final Money subtotal;
  final Money totalDiscount;
  final Money grandTotal;

  const CartTotals({
    required this.itemCount,
    required this.totalUnits,
    required this.subtotal,
    required this.totalDiscount,
    required this.grandTotal,
  });

  factory CartTotals.empty() => CartTotals(
    itemCount: 0,
    totalUnits: 0,
    subtotal: Money.zero(),
    totalDiscount: Money.zero(),
    grandTotal: Money.zero(),
  );

  factory CartTotals.fromItems(List<CartItem> items) {
    if (items.isEmpty) return CartTotals.empty();

    int subPaisa = 0;
    int discPaisa = 0;
    int units = 0;

    for (final item in items) {
      subPaisa += item.grossTotal.paisa;
      discPaisa += item.discountAmount.paisa;
      units += item.quantity;
    }

    return CartTotals(
      itemCount: items.length,
      totalUnits: units,
      subtotal: Money.fromPaisa(subPaisa),
      totalDiscount: Money.fromPaisa(discPaisa),
      grandTotal: Money.fromPaisa(subPaisa - discPaisa),
    );
  }
}