import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import 'customer.dart';
import 'customer_ledger.dart';

abstract class CustomerRepository {
  // Customer CRUD
  Future<Result<List<CustomerWithBalance>>> getCustomers({String? searchQuery});
  Future<Result<Customer>> getCustomerById(CustomerId id);
  Future<Result<Customer?>> findCustomerByName(String name);
  Future<Result<Customer>> createCustomer(Customer customer);
  Future<Result<Customer>> updateCustomer(Customer customer);
  Future<Result<void>> deleteCustomer(CustomerId id);

  // Ledger
  Future<Result<List<LedgerRow>>> getLedger(CustomerId id);
  Future<Result<Money>> getOutstandingBalance(CustomerId id);
  Future<Result<void>> addLedgerEntry(CustomerLedgerEntry entry);
}
