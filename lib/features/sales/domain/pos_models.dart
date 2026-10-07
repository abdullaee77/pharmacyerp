import '../../medicines/domain/medicine.dart';

/// DTO for POS search results combining the medicine with its total available stock.
class PosSearchResult {
  final Medicine medicine;
  final int currentStock;

  const PosSearchResult({
    required this.medicine,
    required this.currentStock,
  });
}