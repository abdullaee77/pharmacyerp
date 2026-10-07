import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import 'payment.dart';
import 'sale.dart';
import 'sales_return.dart';

/// Combined contract for all sales and sales-return database operations.
abstract class SalesRepository {
  // ─── Sales ─────────────────────────────────────────────
  Future<Result<Sale>> createSale({
    required Sale sale,
    required List<PaymentTender> tenders,
  });

  Future<Result<List<Sale>>> getSales({
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<Result<Sale>> getSaleById(SaleId id);

  Future<Result<List<PaymentTender>>> getPaymentsForSale(SaleId id);

  // ─── Sales Returns ─────────────────────────────────────
  Future<Result<SalesReturn>> createSalesReturn(SalesReturn returnDoc);

  Future<Result<List<SalesReturn>>> getReturnsForSale(SaleId id);

  /// For a given sale item, returns how many units have already been returned.
  Future<Result<Map<String, int>>> getReturnedQuantities(SaleId id);
}