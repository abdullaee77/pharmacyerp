import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/value_objects.dart';

class ExpenseId extends ValueObject {
  final String value;
  const ExpenseId(this.value);

  factory ExpenseId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return ExpenseId('exp_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ExpenseId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ExpenseCategory {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;

  const ExpenseCategory({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
  });
}

class Expense extends Entity<ExpenseId> {
  final String category;
  final String description;
  final Money amount;
  final String paymentMethod;
  final String? accountId;
  final String? reference;
  final String operatorName;
  final DateTime expenseDate;
  final DateTime createdAt;

  const Expense({
    required super.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    this.accountId,
    this.reference,
    required this.operatorName,
    required this.expenseDate,
    required this.createdAt,
  });
}

class ExpenseSummary {
  final Money today;
  final Money thisMonth;
  final Money total;
  final Map<String, Money> byCategory;

  const ExpenseSummary({
    required this.today,
    required this.thisMonth,
    required this.total,
    required this.byCategory,
  });
}