import 'package:flutter/material.dart';
import '../../domain/navigation_item.dart';

/// Presentation state controller for the application shell and navigation.
class ShellController extends ChangeNotifier {
  NavigationItem _selectedItem = NavigationItem.home;
  bool _isRibbonCollapsed = false;
  String _searchQuery = '';

  NavigationItem get selectedItem => _selectedItem;
  bool get isRibbonCollapsed => _isRibbonCollapsed;
  String get searchQuery => _searchQuery;

  void selectItem(NavigationItem item) {
    if (_selectedItem != item) {
      _selectedItem = item;
      notifyListeners();
    }
  }

  void toggleRibbon() {
    _isRibbonCollapsed = !_isRibbonCollapsed;
    notifyListeners();
  }

  void setRibbonCollapsed(bool collapsed) {
    if (_isRibbonCollapsed != collapsed) {
      _isRibbonCollapsed = collapsed;
      notifyListeners();
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
}