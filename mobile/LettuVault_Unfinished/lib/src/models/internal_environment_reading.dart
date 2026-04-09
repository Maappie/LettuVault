/// Domain model for a single internal environment reading from the backend.
///
/// Maps to the `internal_environment_readings` table.
/// Response shape: { id, timestamp, temperature, humidity, pressure, device_id }
class InternalEnvironmentReading {
  final int id;
  final DateTime timestamp;
  final double? temperature;
  final double? humidity;
  final double? pressure;
  final String? deviceId;

  InternalEnvironmentReading({
    required this.id,
    required this.timestamp,
    this.temperature,
    this.humidity,
    this.pressure,
    this.deviceId,
  });

  factory InternalEnvironmentReading.fromJson(Map<String, dynamic> json) {
    return InternalEnvironmentReading(
      id: json['id'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble(),
      deviceId: json['device_id'] as String?,
    );
  }
}
