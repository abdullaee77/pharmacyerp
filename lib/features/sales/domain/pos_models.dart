import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';

/// DTO for POS search results combining medicine, total stock, and FEFO batch selling price.
class PosSearchResult {
  final Medicine medicine;
  final int currentStock;
  final Money? fefoSellingPrice;

  const PosSearchResult({
    required this.medicine,
    required this.currentStock,
    this.fefoSellingPrice,
  });

  /// Displays active FEFO batch selling price if available, otherwise falls back to medicine catalog price.
  Money get displayPrice => (fefoSellingPrice != null && fefoSellingPrice!.paisa > 0)
      ? fefoSellingPrice!
      : medicine.sellingPrice;

  /// Calculates box price based on the active batch unit price and box size.
  Money get displayBoxPrice => Money.fromPaisa(displayPrice.paisa * medicine.boxSize);
}