import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';
import '../domain/supplier_repository.dart';

class CreateSupplierUseCase {
  final SupplierRepository _repo;
  const CreateSupplierUseCase(this._repo);

  Future<Result<Supplier>> execute(Supplier s) async {
    if (s.name.trim().isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Supplier name is required.'),
      );
    }
    return _repo.createSupplier(s);
  }
}

class UpdateSupplierUseCase {
  final SupplierRepository _repo;
  const UpdateSupplierUseCase(this._repo);

  Future<Result<Supplier>> execute(Supplier s) async {
    if (s.name.trim().isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Supplier name is required.'),
      );
    }
    return _repo.updateSupplier(s);
  }
}

class GetSuppliersUseCase {
  final SupplierRepository _repo;
  const GetSuppliersUseCase(this._repo);

  Future<Result<List<SupplierWithBalance>>> execute({String? searchQuery}) {
    return _repo.getSuppliers(searchQuery: searchQuery);
  }
}

class DeleteSupplierUseCase {
  final SupplierRepository _repo;
  const DeleteSupplierUseCase(this._repo);

  Future<Result<void>> execute(SupplierId id) => _repo.deleteSupplier(id);
}

class GetSupplierLedgerUseCase {
  final SupplierRepository _repo;
  const GetSupplierLedgerUseCase(this._repo);

  Future<Result<List<SupplierLedgerRow>>> execute(SupplierId id) =>
      _repo.getLedger(id);
}

class RecordSupplierPaymentUseCase {
  final SupplierRepository _repo;
  const RecordSupplierPaymentUseCase(this._repo);

  Future<Result<void>> execute({
    required SupplierId supplierId,
    required Money amount,
    required String paymentMethod,
    String? reference,
    String? note,
    required String operatorName,
  }) async {
    if (amount.paisa <= 0) {
      return const Failure(
        ValidationFailure(message: 'Payment amount must be greater than zero.'),
      );
    }

    final entry = SupplierLedgerEntry(
      id: SupplierLedgerEntry.newId(),
      supplierId: supplierId,
      entryType: SupplierEntryType.payment,
      description: note == null || note.trim().isEmpty
          ? 'Payment made ($paymentMethod)'
          : note.trim(),
      reference: reference,
      debit: amount,
      credit: Money.zero(),
      paymentMethod: paymentMethod,
      operatorName: operatorName,
      createdAt: DateTime.now(),
    );

    return _repo.addLedgerEntry(entry);
  }
}

/// Called by the Purchases module after creating a purchase.
/// Posts a credit to the supplier's ledger (we owe them more).
class PostPurchaseToSupplierUseCase {
  final SupplierRepository _repo;
  const PostPurchaseToSupplierUseCase(this._repo);

  Future<Result<void>> execute({
    required String supplierName,
    required String invoiceNumber,
    required Money amount,
    required String operatorName,
  }) async {
    if (supplierName.trim().isEmpty) return const Success(null);

    final findResult = await _repo.findSupplierByName(supplierName.trim());
    if (findResult.isFailure) return Failure(findResult.failureOrNull!);
    final supplier = findResult.valueOrNull;
    if (supplier == null) return const Success(null);

    final entry = SupplierLedgerEntry(
      id: SupplierLedgerEntry.newId(),
      supplierId: supplier.id,
      entryType: SupplierEntryType.purchase,
      description: 'Purchase $invoiceNumber',
      reference: invoiceNumber,
      debit: Money.zero(),
      credit: amount,
      operatorName: operatorName,
      createdAt: DateTime.now(),
    );

    return _repo.addLedgerEntry(entry);
  }
}
