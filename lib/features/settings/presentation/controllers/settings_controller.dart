import 'package:flutter/material.dart';
import '../../application/settings_use_cases.dart';
import '../../domain/setting.dart';
import '../../domain/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  final GetAllSettingsUseCase _getAll;
  final SaveSettingsUseCase _save;

  SettingsController({required SettingsRepository repository})
      : _getAll = GetAllSettingsUseCase(repository),
        _save = SaveSettingsUseCase(repository);

  List<Setting> _settings = [];
  bool _isLoading = false;
  String? _error;

  List<Setting> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String getValue(String key) {
    final s = _settings.where((s) => s.key == key).toList();
    return s.isEmpty ? '' : s.first.value;
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final r = await _getAll.execute();
    r.fold(
      onSuccess: (d) { _settings = d; _isLoading = false; notifyListeners(); },
      onFailure: (f) { _error = f.message; _isLoading = false; notifyListeners(); },
    );
  }

  Future<String?> saveSettings(Map<String, String> values) async {
    final r = await _save.execute(values);
    return r.fold(
      onSuccess: (_) { loadSettings(); return null; },
      onFailure: (f) => f.message,
    );
  }
}