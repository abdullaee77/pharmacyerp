import '../../../core/result/result.dart';
import '../../inventory/domain/batch.dart';
import '../../medicines/domain/medicine.dart';
import 'pos_models.dart';

abstract class PosRepository {
  /// Fast search across name, generic name, barcode, manufacturer.
  /// Returns at most [limit] results along with their total physical stock.
  Future<Result<List<PosSearchResult>>> searchMedicines(String query, {int limit = 20});

  /// Resolve a medicine by barcode.
  Future<Result<PosSearchResult>> findByBarcode(String barcode);

  /// Load all available batches for a medicine with stock > 0, ordered by FEFO.
  Future<Result<List<Batch>>> getAvailableBatches(MedicineId medicineId);
}