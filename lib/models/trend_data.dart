import 'package:flutter/material.dart';

/// A single data point with a date and numeric value.
class DatedValue {
  final DateTime date;
  final double value;
  final String? label;

  const DatedValue({required this.date, required this.value, this.label});
}

/// A period during which a specific protocol was active.
class ProtocolPeriod {
  final String name;
  final DateTime start;
  final DateTime? end;
  final Color color;

  const ProtocolPeriod({
    required this.name,
    required this.start,
    this.end,
    required this.color,
  });
}

/// Computed trend data for the trends dashboard.
class TrendData {
  // HRV
  final List<DatedValue> hrvTimeSeries;
  final double? hrvTrend;
  final double? hrvBaseline;
  final double? hrvCurrent;

  // GSR
  final List<DatedValue> gsrTimeSeries;
  final double? gsrTrend;
  final double? gsrBaseline;
  final double? gsrCurrent;

  // Sleep (from Oura)
  final List<DatedValue> sleepScoreTimeSeries;
  final List<DatedValue> readinessTimeSeries;
  final List<DatedValue> overnightHrvTimeSeries;
  final double? avgSleepScore;
  final double? avgReadiness;

  // Session counts
  final Map<String, int> sessionCountByType;
  final int totalSessions;

  // Protocol periods
  final List<ProtocolPeriod> protocolPeriods;

  // Subjective trends
  final List<DatedValue> energyTimeSeries;
  final List<DatedValue> moodTimeSeries;
  final List<DatedValue> focusTimeSeries;

  const TrendData({
    this.hrvTimeSeries = const [],
    this.hrvTrend,
    this.hrvBaseline,
    this.hrvCurrent,
    this.gsrTimeSeries = const [],
    this.gsrTrend,
    this.gsrBaseline,
    this.gsrCurrent,
    this.sleepScoreTimeSeries = const [],
    this.readinessTimeSeries = const [],
    this.overnightHrvTimeSeries = const [],
    this.avgSleepScore,
    this.avgReadiness,
    this.sessionCountByType = const {},
    this.totalSessions = 0,
    this.protocolPeriods = const [],
    this.energyTimeSeries = const [],
    this.moodTimeSeries = const [],
    this.focusTimeSeries = const [],
  });
}
