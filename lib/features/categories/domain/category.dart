import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';

class CategoryId extends ValueObject {
  final String value;
  const CategoryId(this.value);

  factory CategoryId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return CategoryId('cat_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CategoryId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Classification category for pharmacy medicines.
class Category extends Entity<CategoryId> {
  final String name;
  final String description;
  final DateTime createdAt;

  const Category({
    required super.id,
    required this.name,
    this.description = '',
    required this.createdAt,
  });

  Category copyWith({String? name, String? description}) {
    return Category(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}