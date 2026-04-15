import 'package:flutter/foundation.dart';

class AiProduceScan {
  final int id;
  final DateTime timestamp;
  final double confidenceScore;
  final String? image;
  final String produceType;
  final String label;

  AiProduceScan({
    required this.id,
    required this.timestamp,
    required this.confidenceScore,
    this.image,
    required this.produceType,
    required this.label,
  });

  factory AiProduceScan.fromJson(Map<String, dynamic> json) {
    return AiProduceScan(
      id: json['id'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      image: json['image'] as String?,
      produceType: json['produce_type'] as String,
      label: json['label'] as String? ?? '',
    );
  }
}
