import 'dart:math';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/value_objects.dart';
import 'supplier.dart';

/// Classification of a supplier ledger entry.
///
/// For suppliers:
///   - A purchase creates a CREDIT (we owe them more).
///   - A payment creates a DEBIT (we paid them, reducing what we owe).
enum SupplierEntryType {
  purchase(label: 'Purchase'),
  payment(label: 'Payment Made'),
  openingBalance(label: 'Opening Balance'),
  adjustment(label: 'Adjustment'),
  purchaseReturn(label: 'Purchase Return');

  final String label;
  const SupplierEntryType({required this.label});
}

/// Supplier ledger entry.
///
/// Credit = amount we owe the supplier (increases payable).
/// Debit = amount we paid the supplier or was credited back (decreases payable).
class SupplierLedgerEntry extends ValueObject {
  final String id;
  final SupplierId supplierId;
  final SupplierEntryType entryType;
  final String description;
  final String? reference;
  final Money debit;
  final Money credit;
  final String? paymentMethod;
  final String operatorName;
  final DateTime createdAt;

  const SupplierLedgerEntry({
    required this.id,
    required this.supplierId,
    required this.entryType,
    required this.description,
    this.reference,
    required this.debit,
    required this.credit,
    this.paymentMethod,
    required this.operatorName,
    required this.createdAt,
  });

  static String newId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(9999);
    return 'sle_${ts}_$rand';
  }
}

class SupplierLedgerRow {
  final SupplierLedgerEntry entry;
  final Money runningBalance;

  const SupplierLedgerRow({required this.entry, required this.runningBalance});
}
