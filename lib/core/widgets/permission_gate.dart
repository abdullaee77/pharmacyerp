import 'package:flutter/material.dart';
import '../../features/authentication/domain/user.dart';
import '../../features/users/domain/role.dart';

/// Centralised permission guard for UI controls.
///
/// Usage:
///   PermissionGate.show(user, PermissionCategory.sales, PermissionAction.add,
///     AppButton(label: 'New Sale', onPressed: _add),
///   )
///
/// Admin users always see everything.
class PermissionGate {
  PermissionGate._();

  /// True when the user may perform [action] in [category].
  static bool allow(User? user, PermissionCategory cat, PermissionAction act) {
    if (user == null) return false;
    return user.can(cat, act);
  }

  /// Shows [child] only when the user has the permission.
  /// Returns a zero-size widget otherwise so layouts don't shift.
  static Widget show(
      User? user,
      PermissionCategory cat,
      PermissionAction act,
      Widget child,
      ) {
    if (allow(user, cat, act)) return child;
    return const SizedBox.shrink();
  }

  /// Shows [child] greyed-out and non-interactive when the user lacks
  /// the permission, with an explanatory tooltip.
  static Widget disable(
      User? user,
      PermissionCategory cat,
      PermissionAction act,
      Widget child, {
        String? tooltip,
      }) {
    if (allow(user, cat, act)) return child;
    return Tooltip(
      message: tooltip ?? 'You do not have permission for this action.',
      child: Opacity(
        opacity: 0.38,
        child: IgnorePointer(child: child),
      ),
    );
  }
}