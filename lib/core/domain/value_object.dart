/// Base class for all domain value objects.
///
/// A value object is defined by its attributes, not by identity.
/// Value objects should be immutable and validate their own invariants.
///
/// Subclasses should override [==] and [hashCode] based on their properties.
abstract class ValueObject {
  const ValueObject();
}