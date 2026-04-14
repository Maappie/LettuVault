import '../core/api_client.dart';
import '../models/system_config.dart';

/// Repository for system config setpoints.
/// Retrieves the target parameters for the environment from the backend.
class ConfigRepository {
  final ApiClient _client;

  ConfigRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// Fetches the most recent system config.
  Future<SystemConfig?> getLatest() async {
    try {
      final List<dynamic> data = await _client.get('/system_config');
      if (data.isNotEmpty) {
        return SystemConfig.fromJson(data.first as Map<String, dynamic>);
      }
    } catch (e) {
      // Return null and let caller handle UI fallback
    }
    return null;
  }

  /// Saves a new system config to the backend.
  Future<void> saveConfig({double? temperature, double? humidity, double? pressure}) async {
    final body = {
      if (temperature != null) 'temperature': temperature,
      if (humidity != null) 'humidity': humidity,
      if (pressure != null) 'pressure': pressure,
    };
    await _client.post('/system_config', body);
  }
}
