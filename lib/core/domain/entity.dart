/// Base class for all domain entities.
///
/// An entity is defined by its identity, not its attributes.
/// Two entities with the same properties but different IDs are not equal.
///
/// The generic [Id] parameter allows typed identifiers
/// (e.g., MedicineId, UserId) in future features.
abstract class Entity<Id> {
  final Id id;

  const Entity({required this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Entity<Id> &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}