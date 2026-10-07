import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/value_objects.dart';

class AccountId extends ValueObject {
  final String value;
  const AccountId(this.value);

  factory AccountId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return AccountId('acc_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AccountId &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum AccountType {
  cash(label: 'Cash'),
  bank(label: 'Bank'),
  receivable(label: 'Receivable'),
  payable(label: 'Payable'),
  expense(label: 'Expense'),
  other(label: 'Other');

  final String label;
  const AccountType({required this.label});
}

enum AccountStatus {
  active(label: 'Active'),
  inactive(label: 'Inactive');

  final String label;
  const AccountStatus({required this.label});
}

class Account extends Entity<AccountId> {
  final String name;
  final AccountType accountType;
  final Money openingBalance;
  final AccountStatus status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    required super.id,
    required this.name,
    required this.accountType,
    this.openingBalance = const Money(paisa: 0),
    this.status = AccountStatus.active,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Account copyWith({
    String? name,
    AccountType? accountType,
    Money? openingBalance,
    AccountStatus? status,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      openingBalance: openingBalance ?? this.openingBalance,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class AccountWithBalance {
  final Account account;
  final Money currentBalance;

  const AccountWithBalance({
    required this.account,
    required this.currentBalance,
  });
}