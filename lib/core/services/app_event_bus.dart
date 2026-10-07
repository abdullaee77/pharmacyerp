// lib/core/services/app_event_bus.dart
import 'dart:async';

/// Global events that trigger reactiveness across separated feature domains.
enum AppEvent {
  saleCompleted,
  purchaseCompleted,
  expenseAdded,
  customerUpdated,
  supplierUpdated,
  medicineUpdated,
}

class AppEventBus {
  AppEventBus._();
  static final AppEventBus instance = AppEventBus._();

  final StreamController<AppEvent> _streamController = StreamController<AppEvent>.broadcast();

  /// Listen to this stream to catch global app updates.
  Stream<AppEvent> get stream => _streamController.stream;

  /// Fire an event to notify listeners of a state change.
  void fire(AppEvent event) {
    _streamController.add(event);
  }
}