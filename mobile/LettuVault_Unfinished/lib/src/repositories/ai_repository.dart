import '../core/api_client.dart';
import '../models/ai_scan.dart';

/// Repository for AI related commands and scans.
class AiRepository {
  final ApiClient _client;

  AiRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// Triggers a manual produce scan via the backend.
  Future<void> triggerProduceScan() async {
    await _client.post('/trigger-produce-scan', {});
  }

  /// Triggers the testing capture endpoint directly.
  Future<void> testCamera() async {
    await _client.post('/test-camera', {});
  }

  /// Fetches the latest produce scans, up to [limit].
  Future<List<AiProduceScan>> getProduceScans({int limit = 3}) async {
    try {
      final List<dynamic> data = await _client.get('/ai-scans/produce');
      // The API returns all scans, so we map them to Dart objects and take the newest `limit` items
      final allScans = data.map((json) => AiProduceScan.fromJson(json as Map<String, dynamic>)).toList();
      /// Endpoints typically return all items ordered by oldest to newest or grouped.
      /// Assuming the backend sends them chronologically or reverse. Let's sort them explicitly:
      allScans.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allScans.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches the latest condition scans (worms/wilting), up to [limit].
  Future<List<AiConditionScan>> getConditionScans({int limit = 3}) async {
    try {
      final List<dynamic> data = await _client.get('/ai-scans/condition');
      final allScans = data.map((json) => AiConditionScan.fromJson(json as Map<String, dynamic>)).toList();
      allScans.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allScans.take(limit).toList();
    } catch (e) {
      return [];
    }
  }
}
