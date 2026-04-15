// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  25  — AiAnalysis
// =============================================================================

import 'package:hive/hive.dart';

part 'ai_analysis.g.dart';

@HiveType(typeId: 25)
class AiAnalysis {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final DateTime generatedAt;

  @HiveField(2)
  final String provider;

  @HiveField(3)
  final String model;

  @HiveField(4)
  final String promptVersion;

  @HiveField(5)
  final List<String> insights;

  @HiveField(6)
  final List<String> anomalies;

  @HiveField(7)
  final List<String> correlationsDetected;

  @HiveField(8)
  final List<String> protocolRecommendations;

  @HiveField(9)
  final List<String> flags;

  @HiveField(10)
  final String? trendSummary;

  @HiveField(11)
  final double confidence;

  @HiveField(12)
  final bool ouraContextUsed;

  AiAnalysis({
    required this.sessionId,
    required this.generatedAt,
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.insights,
    required this.anomalies,
    required this.correlationsDetected,
    required this.protocolRecommendations,
    required this.flags,
    this.trendSummary,
    required this.confidence,
    required this.ouraContextUsed,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'generatedAt': generatedAt.toIso8601String(),
        'provider': provider,
        'model': model,
        'promptVersion': promptVersion,
        'insights': insights,
        'anomalies': anomalies,
        'correlationsDetected': correlationsDetected,
        'protocolRecommendations': protocolRecommendations,
        'flags': flags,
        'trendSummary': trendSummary,
        'confidence': confidence,
        'ouraContextUsed': ouraContextUsed,
      };

  factory AiAnalysis.fromJson(Map<String, dynamic> json) => AiAnalysis(
        sessionId: json['sessionId'] as String,
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        provider: json['provider'] as String,
        model: json['model'] as String,
        promptVersion: json['promptVersion'] as String,
        insights: (json['insights'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        anomalies: (json['anomalies'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        correlationsDetected: (json['correlationsDetected'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        protocolRecommendations:
            (json['protocolRecommendations'] as List<dynamic>)
                .map((e) => e as String)
                .toList(),
        flags: (json['flags'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        trendSummary: json['trendSummary'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
        ouraContextUsed: json['ouraContextUsed'] as bool,
      );
}
