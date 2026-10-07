import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';
import '../domain/customer_repository.dart';

class CreateCustomerUseCase {
  final CustomerRepository _repo;
  const CreateCustomerUseCase(this._repo);

  Future<Result<Customer>> execute(Customer customer) async {
    if (customer.name.trim().isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Customer name is required.'),
      );
    }
    return _repo.createCustomer(customer);
  }
}

class UpdateCustomerUseCase {
  final CustomerRepository _repo;
  const UpdateCustomerUseCase(this._repo);

  Future<Result<Customer>> execute(Customer customer) async {
    if (customer.name.trim().isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Customer name is required.'),
      );
    }
    return _repo.updateCustomer(customer);
  }
}

class GetCustomersUseCase {
  final CustomerRepository _repo;
  const GetCustomersUseCase(this._repo);

  Future<Result<List<CustomerWithBalance>>> execute({String? searchQuery}) {
    return _repo.getCustomers(searchQuery: searchQuery);
  }
}

class DeleteCustomerUseCase {
  final CustomerRepository _repo;
  const DeleteCustomerUseCase(this._repo);

  Future<Result<void>> execute(CustomerId id) => _repo.deleteCustomer(id);
}

class GetCustomerLedgerUseCase {
  final CustomerRepository _repo;
  const GetCustomerLedgerUseCase(this._repo);

  Future<Result<List<LedgerRow>>> execute(CustomerId id) => _repo.getLedger(id);
}

/// Records a customer payment, creating a ledger entry that reduces outstanding.
class RecordCustomerPaymentUseCase {
  final CustomerRepository _repo;
  const RecordCustomerPaymentUseCase(this._repo);

  Future<Result<void>> execute({
    required CustomerId customerId,
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

    final entry = CustomerLedgerEntry(
      id: CustomerLedgerEntry.newId(),
      customerId: customerId,
      entryType: CustomerEntryType.payment,
      description: note == null || note.trim().isEmpty
          ? 'Payment received ($paymentMethod)'
          : note.trim(),
      reference: reference,
      debit: Money.zero(),
      credit: amount,
      paymentMethod: paymentMethod,
      operatorName: operatorName,
      createdAt: DateTime.now(),
    );

    return _repo.addLedgerEntry(entry);
  }
}

/// Called by the Sales module when a credit tender is used.
/// Posts a debit to the customer's ledger (customer owes us).
class PostCreditSaleToCustomerUseCase {
  final CustomerRepository _repo;
  const PostCreditSaleToCustomerUseCase(this._repo);

  /// Looks up the customer by name. If not found, silently does nothing
  /// (walk-in customers are not persisted).
  Future<Result<void>> execute({
    required String customerName,
    required String invoiceNumber,
    required Money amount,
    required String operatorName,
  }) async {
    if (customerName.trim().isEmpty) return const Success(null);
    if (customerName.trim().toLowerCase() == 'walk-in customer') {
      return const Success(null);
    }

    final findResult = await _repo.findCustomerByName(customerName.trim());
    if (findResult.isFailure) return Failure(findResult.failureOrNull!);
    final customer = findResult.valueOrNull;
    if (customer == null) return const Success(null);

    final entry = CustomerLedgerEntry(
      id: CustomerLedgerEntry.newId(),
      customerId: customer.id,
      entryType: CustomerEntryType.sale,
      description: 'Credit sale $invoiceNumber',
      reference: invoiceNumber,
      debit: amount,
      credit: Money.zero(),
      operatorName: operatorName,
      createdAt: DateTime.now(),
    );

    return _repo.addLedgerEntry(entry);
  }
}
