import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import 'supplier.dart';
import 'supplier_ledger.dart';

abstract class SupplierRepository {
  Future<Result<List<SupplierWithBalance>>> getSuppliers({String? searchQuery});
  Future<Result<Supplier>> getSupplierById(SupplierId id);
  Future<Result<Supplier?>> findSupplierByName(String name);
  Future<Result<Supplier>> createSupplier(Supplier supplier);
  Future<Result<Supplier>> updateSupplier(Supplier supplier);
  Future<Result<void>> deleteSupplier(SupplierId id);

  Future<Result<List<SupplierLedgerRow>>> getLedger(SupplierId id);
  Future<Result<Money>> getPayableBalance(SupplierId id);
  Future<Result<void>> addLedgerEntry(SupplierLedgerEntry entry);
}
