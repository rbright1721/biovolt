import 'package:hive/hive.dart';

import '../models/session.dart';
import '../models/trend_data.dart';
import 'ai_service.dart';
import 'prompt_builder.dart';
import 'storage_service.dart';

/// Computes trend metrics from stored sessions and Oura records,
/// and optionally generates AI-powered weekly trend reports.
class TrendAnalyst {
  final StorageService _storage;
  final AiService _aiService;
  final PromptBuilder _promptBuilder;

  TrendAnalyst({
    required StorageService storage,
    required AiService aiService,
    required PromptBuilder promptBuilder,
  })  : _storage = storage,
        _aiService = aiService,
        _promptBuilder = promptBuilder;

  // ---------------------------------------------------------------------------
  // Weekly AI analysis
  // ---------------------------------------------------------------------------

  /// Run a weekly AI trend analysis. Returns the narrative string, or null
  /// if no AI key is configured.
  Future<String?> runWeeklyAnalysis() async {
    final hasKey = await _aiService.hasValidKey();
    if (!hasKey) return null;

    final prompt = await _promptBuilder.buildWeeklyTrendPrompt();
    final result = await _aiService.quickCoach(
      prompt,
      systemPrompt: _promptBuilder.weeklyTrendSystemPrompt,
    );

    // Store in Hive with date key
    final box = await Hive.openBox<String>('weekly_summaries');
    final key = DateTime.now().toIso8601String().substring(0, 10);
    await box.put(key, result);

    return result;
  }

  /// Get the most recent weekly summary, or null if none exists.
  Future<(String summary, DateTime date)?> getLatestWeeklySummary() async {
    final box = await Hive.openBox<String>('weekly_summaries');
    if (box.isEmpty) return null;

    final keys = box.keys.cast<String>().toList()..sort();
    final latestKey = keys.last;
    final summary = box.get(latestKey);
    if (summary == null) return null;

    return (summary, DateTime.parse(latestKey));
  }

  // ---------------------------------------------------------------------------
  // Trend computation (no AI needed)
  // ---------------------------------------------------------------------------

  /// Compute all trend metrics from stored data for the given number of days.
  Future<TrendData> computeTrends(int days) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));

    final sessions = _storage.getSessionsInRange(from, now);
    final ouraRecords = _storage.getOuraRecordsInRange(from, now);

    // -- HRV time series --
    final hrvSeries = <DatedValue>[];
    for (final s in sessions) {
      final hrv = s.biometrics?.computed?.hrvRmssdMs;
      if (hrv != null) {
        hrvSeries.add(DatedValue(date: s.createdAt, value: hrv));
      }
    }

    // -- GSR time series --
    final gsrSeries = <DatedValue>[];
    for (final s in sessions) {
      final gsr = s.biometrics?.esp32?.gsrMeanUs;
      if (gsr != null) {
        gsrSeries.add(DatedValue(date: s.createdAt, value: gsr));
      }
    }

    // -- HRV baseline (first 14 days) and current (last 7 days) --
    final baselineCutoff = from.add(const Duration(days: 14));
    final currentCutoff = now.subtract(const Duration(days: 7));
    final hrvBaseline = _avgWhere(
        hrvSeries, (d) => d.date.isBefore(baselineCutoff));
    final hrvCurrent = _avgWhere(
        hrvSeries, (d) => d.date.isAfter(currentCutoff));

    // -- GSR baseline and current --
    final gsrBaseline = _avgWhere(
        gsrSeries, (d) => d.date.isBefore(baselineCutoff));
    final gsrCurrent = _avgWhere(
        gsrSeries, (d) => d.date.isAfter(currentCutoff));

    // -- Linear regression slopes --
    final hrvTrend = _linearSlope(hrvSeries);
    final gsrTrend = _linearSlope(gsrSeries);

    // -- Sleep & readiness from Oura --
    final sleepScores = <DatedValue>[];
    final readinessScores = <DatedValue>[];
    final overnightHrv = <DatedValue>[];

    for (final r in ouraRecords) {
      if (r.sleepScore != null) {
        sleepScores.add(
            DatedValue(date: r.date, value: r.sleepScore!.toDouble()));
      }
      if (r.readinessScore != null) {
        readinessScores.add(
            DatedValue(date: r.date, value: r.readinessScore!.toDouble()));
      }
      if (r.overnightHrvAverageMs != null) {
        overnightHrv.add(
            DatedValue(date: r.date, value: r.overnightHrvAverageMs!));
      }
    }

    final avgSleep = sleepScores.isEmpty
        ? null
        : sleepScores.map((d) => d.value).reduce((a, b) => a + b) /
            sleepScores.length;
    final avgReadiness = readinessScores.isEmpty
        ? null
        : readinessScores.map((d) => d.value).reduce((a, b) => a + b) /
            readinessScores.length;

    // -- Session counts by type --
    final countByType = <String, int>{};
    for (final s in sessions) {
      final type = s.context?.activities.firstOrNull?.type ?? 'unknown';
      countByType[type] = (countByType[type] ?? 0) + 1;
    }

    // -- Subjective time series --
    final energy = <DatedValue>[];
    final mood = <DatedValue>[];
    final focus = <DatedValue>[];

    for (final s in sessions) {
      final scores = s.subjective?.postSession ?? s.subjective?.preSession;
      if (scores == null) continue;
      if (scores.energy != null) {
        energy.add(
            DatedValue(date: s.createdAt, value: scores.energy!.toDouble()));
      }
      if (scores.mood != null) {
        mood.add(
            DatedValue(date: s.createdAt, value: scores.mood!.toDouble()));
      }
      if (scores.focus != null) {
        focus.add(
            DatedValue(date: s.createdAt, value: scores.focus!.toDouble()));
      }
    }

    // -- Protocol periods --
    final protocolPeriods = _detectProtocolPeriods(sessions);

    return TrendData(
      hrvTimeSeries: hrvSeries,
      hrvTrend: hrvTrend,
      hrvBaseline: hrvBaseline,
      hrvCurrent: hrvCurrent,
      gsrTimeSeries: gsrSeries,
      gsrTrend: gsrTrend,
      gsrBaseline: gsrBaseline,
      gsrCurrent: gsrCurrent,
      sleepScoreTimeSeries: sleepScores,
      readinessTimeSeries: readinessScores,
      overnightHrvTimeSeries: overnightHrv,
      avgSleepScore: avgSleep,
      avgReadiness: avgReadiness,
      sessionCountByType: countByType,
      totalSessions: sessions.length,
      protocolPeriods: protocolPeriods,
      energyTimeSeries: energy,
      moodTimeSeries: mood,
      focusTimeSeries: focus,
    );
  }

  // ---------------------------------------------------------------------------
  // Math helpers
  // ---------------------------------------------------------------------------

  double? _avgWhere(
      List<DatedValue> series, bool Function(DatedValue) predicate) {
    final filtered = series.where(predicate).toList();
    if (filtered.isEmpty) return null;
    return filtered.map((d) => d.value).reduce((a, b) => a + b) /
        filtered.length;
  }

  /// Simple linear regression slope (value per day).
  double? _linearSlope(List<DatedValue> series) {
    if (series.length < 3) return null;

    final first = series.first.date;
    final n = series.length.toDouble();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (final d in series) {
      final x = d.date.difference(first).inHours / 24.0;
      final y = d.value;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return 0;
    return (n * sumXY - sumX * sumY) / denom;
  }

  /// Detect protocol periods from session interventions.
  List<ProtocolPeriod> _detectProtocolPeriods(List<Session> sessions) {
    // Protocol periods would be detected from linked Interventions records.
    // For now, return empty — will be populated when the interventions
    // logging UI is built.
    return const [];
  }
}
