import 'dart:math';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/value_objects.dart';
import 'customer.dart';

/// Classification of a customer ledger entry.
enum CustomerEntryType {
  sale(label: 'Credit Sale'),
  payment(label: 'Payment Received'),
  openingBalance(label: 'Opening Balance'),
  adjustment(label: 'Adjustment'),
  salesReturn(label: 'Sales Return');

  final String label;
  const CustomerEntryType({required this.label});
}

/// A single row in the customer's running ledger.
///
/// Debit = amount customer owes us (increases balance).
/// Credit = amount customer paid or was credited back (decreases balance).
class CustomerLedgerEntry extends ValueObject {
  final String id;
  final CustomerId customerId;
  final CustomerEntryType entryType;
  final String description;
  final String? reference;
  final Money debit;
  final Money credit;
  final String? paymentMethod;
  final String operatorName;
  final DateTime createdAt;

  const CustomerLedgerEntry({
    required this.id,
    required this.customerId,
    required this.entryType,
    required this.description,
    this.reference,
    required this.debit,
    required this.credit,
    this.paymentMethod,
    required this.operatorName,
    required this.createdAt,
  });

  factory CustomerLedgerEntry.generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(9999);
    final randId = 'cle_${ts}_$rand';
    return CustomerLedgerEntry(
      id: randId,
      customerId: const CustomerId(''),
      entryType: CustomerEntryType.adjustment,
      description: '',
      debit: Money.zero(),
      credit: Money.zero(),
      operatorName: '',
      createdAt: DateTime.now(),
    );
  }

  static String newId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(9999);
    return 'cle_${ts}_$rand';
  }
}

/// A ledger entry with the running balance computed up to that point.
class LedgerRow {
  final CustomerLedgerEntry entry;
  final Money runningBalance;

  const LedgerRow({required this.entry, required this.runningBalance});
}
