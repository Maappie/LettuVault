import '../core/api_client.dart';
import '../models/internal_environment_reading.dart';

/// Repository for internal environment readings.
///
/// Calls `GET /api/v1/internal-environment` and returns parsed domain models.
/// The endpoint is protected by X-API-KEY (injected by [ApiClient]).
class EnvironmentRepository {
  final ApiClient _client;

  EnvironmentRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// Fetches all readings (newest first) and returns the list.
  Future<List<InternalEnvironmentReading>> getAll() async {
    final List<dynamic> data = await _client.get('/internal-environment');
    return data.map((json) => InternalEnvironmentReading.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Convenience: returns only the most recent reading, or null if empty.
  Future<InternalEnvironmentReading?> getLatest() async {
    final readings = await getAll();
    return readings.isNotEmpty ? readings.first : null;
  }
}
