import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/app_responsive_layout.dart';

/// Manages global workspace state: panel visibility and active focus context.
class WorkspaceController extends ChangeNotifier {
  bool _isLeftPanelVisible = true;
  bool _isRightPanelVisible = false;
  String _activeContext = 'home';
  DesktopBreakpoint _breakpoint = DesktopBreakpoint.wide;

  bool get isLeftPanelVisible => _isLeftPanelVisible;
  bool get isRightPanelVisible => _isRightPanelVisible;
  String get activeContext => _activeContext;
  DesktopBreakpoint get breakpoint => _breakpoint;

  void toggleLeftPanel() {
    _isLeftPanelVisible = !_isLeftPanelVisible;
    notifyListeners();
  }

  void toggleRightPanel() {
    _isRightPanelVisible = !_isRightPanelVisible;
    notifyListeners();
  }

  void setActiveContext(String context) {
    if (_activeContext != context) {
      _activeContext = context;
      notifyListeners();
    }
  }

  void updateBreakpoint(DesktopBreakpoint bp) {
    if (_breakpoint != bp) {
      _breakpoint = bp;
      notifyListeners();
    }
  }
}