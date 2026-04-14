/// Domain model for the system configuration target setpoints.
///
/// Maps to the `system_config` table.
class SystemConfig {
  final int id;
  final DateTime timestamp;
  final double? temperature;
  final double? humidity;
  final double? pressure;

  SystemConfig({
    required this.id,
    required this.timestamp,
    this.temperature,
    this.humidity,
    this.pressure,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
      id: json['id'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'pressure': pressure,
    };
  }
}
