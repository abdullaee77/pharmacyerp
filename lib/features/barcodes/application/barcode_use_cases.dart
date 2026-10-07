import 'dart:math';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/medicine_repository.dart';
import '../../medicines/domain/value_objects.dart';

/// Resolves a medicine from a scanned barcode.
class ScanBarcodeUseCase {
  final MedicineRepository _repository;
  const ScanBarcodeUseCase(this._repository);

  Future<Result<Medicine>> execute(String barcode) async {
    if (barcode.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Barcode cannot be empty.'));
    }
    return _repository.getMedicineByBarcode(barcode.trim());
  }
}

/// Generates a new unique barcode for a medicine.
///
/// Uses EAN-13 compatible 13-digit numeric format.
class GenerateBarcodeUseCase {
  const GenerateBarcodeUseCase();

  String execute() {
    final rand = Random();
    final digits = List.generate(12, (_) => rand.nextInt(10)).join();
    final checkDigit = _calculateEan13CheckDigit(digits);
    return '$digits$checkDigit';
  }

  int _calculateEan13CheckDigit(String digits) {
    int sum = 0;
    for (int i = 0; i < digits.length; i++) {
      final n = int.parse(digits[i]);
      sum += (i % 2 == 0) ? n : n * 3;
    }
    final mod = sum % 10;
    return mod == 0 ? 0 : 10 - mod;
  }
}

/// Assigns or reassigns a barcode to a medicine with uniqueness validation.
class AssignBarcodeUseCase {
  final MedicineRepository _repository;
  const AssignBarcodeUseCase(this._repository);

  Future<Result<Medicine>> execute(MedicineId medicineId, String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return const Failure(ValidationFailure(message: 'Barcode cannot be empty.'));
    }

    // Validate not already used by a different medicine
    final existing = await _repository.getMedicineByBarcode(trimmed);
    if (existing.isSuccess && existing.valueOrNull!.id != medicineId) {
      return const Failure(
        ValidationFailure(message: 'Barcode is already assigned to another medicine.'),
      );
    }

    // Fetch target and update
    final targetResult = await _repository.getMedicineById(medicineId);
    if (targetResult.isFailure) return Failure(targetResult.failureOrNull!);

    final updated = targetResult.valueOrNull!.copyWith(
      barcode: Barcode.unsafe(trimmed),
    );

    return _repository.updateMedicine(updated);
  }
}