import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/setting.dart';
import '../domain/settings_repository.dart';

class GetAllSettingsUseCase {
  final SettingsRepository _repo;
  const GetAllSettingsUseCase(this._repo);

  Future<Result<List<Setting>>> execute() => _repo.getAllSettings();
}

class GetSettingUseCase {
  final SettingsRepository _repo;
  const GetSettingUseCase(this._repo);

  Future<Result<String>> execute(String key) => _repo.getSetting(key);
}

class SaveSettingsUseCase {
  final SettingsRepository _repo;
  const SaveSettingsUseCase(this._repo);

  Future<Result<void>> execute(Map<String, String> settings) async {
    if (settings.isEmpty) {
      return const Failure(ValidationFailure(message: 'No settings to save.'));
    }
    return _repo.saveSettings(settings);
  }
}