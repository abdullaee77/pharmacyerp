import '../../../core/result/result.dart';
import 'setting.dart';

abstract class SettingsRepository {
  Future<Result<List<Setting>>> getAllSettings();
  Future<Result<String>> getSetting(String key);
  Future<Result<void>> saveSetting(String key, String value);
  Future<Result<void>> saveSettings(Map<String, String> settings);
}