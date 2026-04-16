import '../models/active_protocol.dart';
import '../models/session.dart';
import '../models/session_template.dart';
import 'storage_service.dart';

// ---------------------------------------------------------------------------
// InferredContext — what the app knows before the user taps anything
// ---------------------------------------------------------------------------

class InferredContext {
  final double? fastingHours;
  final bool fastingInferred;
  final String? fastingSource;
  final List<ActiveProtocol> activeProtocols;
  final SessionTemplate? suggestedTemplate;
  final double? baselineHrvMs;
  final int sessionCountToday;
  final Session? lastSession;

  const InferredContext({
    this.fastingHours,
    this.fastingInferred = false,
    this.fastingSource,
    this.activeProtocols = const [],
    this.suggestedTemplate,
    this.baselineHrvMs,
    this.sessionCountToday = 0,
    this.lastSession,
  });
}

// ---------------------------------------------------------------------------
// ContextInferrer
// ---------------------------------------------------------------------------

class ContextInferrer {
  final StorageService _storage;

  ContextInferrer({required StorageService storage}) : _storage = storage;

  InferredContext infer({String? sessionType}) {
    // 1. FASTING CALCULATION
    // Priority: explicit lastMealTime > schedule inference > null
    double? fastingHours;
    bool fastingInferred = false;
    String? fastingSource;

    final profile = _storage.getUserProfile();

    if (profile?.lastMealTime != null) {
      final hours = DateTime.now()
          .difference(profile!.lastMealTime!)
          .inMinutes /
          60.0;
      // Only report fasting if last meal was within 72 hours (sanity check)
      if (hours <= 72) {
        fastingHours = hours;
        fastingInferred = false;
        fastingSource = 'last_meal';
      }
    }

    if (fastingHours == null &&
        profile?.fastingType == '16:8' &&
        profile?.eatWindowStartHour != null &&
        profile?.eatWindowEndHour != null) {
      final now = DateTime.now();
      final currentHour = now.hour + now.minute / 60.0;
      final eatStart = profile!.eatWindowStartHour!.toDouble();
      final eatEnd = profile.eatWindowEndHour!.toDouble();

      if (currentHour < eatStart) {
        // Before eating window — fasting since yesterday's eatEnd
        fastingHours = currentHour + (24.0 - eatEnd);
      } else if (currentHour >= eatEnd) {
        // After eating window — fasting since today's eatEnd
        fastingHours = currentHour - eatEnd;
      } else {
        // Inside eating window — technically not fasting
        fastingHours = 0.0;
      }
      fastingInferred = true;
      fastingSource = 'schedule';
    }

    // 2. ACTIVE PROTOCOLS
    final activeProtocols = _storage.getAllActiveProtocols();

    // 3. SUGGESTED TEMPLATE
    // If sessionType provided: most-used template for that type
    // Otherwise: most recently used template overall
    final allTemplates = _storage.getAllTemplates(); // sorted by useCount desc
    SessionTemplate? suggested;
    if (sessionType != null && allTemplates.isNotEmpty) {
      final typeMatches =
          allTemplates.where((t) => t.sessionType == sessionType).toList();
      suggested = typeMatches.isNotEmpty ? typeMatches.first : null;
    }
    suggested ??= allTemplates.isNotEmpty ? allTemplates.first : null;

    // 4. BASELINE HRV — 90-day average, require at least 5 sessions
    final now = DateTime.now();
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));
    final recentSessions = _storage.getSessionsInRange(ninetyDaysAgo, now);

    final relevantSessions = sessionType == null
        ? recentSessions
        : recentSessions
            .where((s) =>
                s.context?.activities.firstOrNull?.type == sessionType)
            .toList();

    final hrvValues = relevantSessions
        .map((s) => s.biometrics?.computed?.hrvRmssdMs)
        .whereType<double>()
        .toList();

    final baselineHrvMs = hrvValues.length >= 5
        ? hrvValues.reduce((a, b) => a + b) / hrvValues.length
        : null;

    // 5. SESSION COUNT TODAY
    final todayStart = DateTime(now.year, now.month, now.day);
    final sessionCountToday =
        _storage.getSessionsInRange(todayStart, now).length;

    // 6. LAST SESSION
    final allSessions = _storage.getAllSessions(); // sorted newest first
    final lastSession = allSessions.isNotEmpty ? allSessions.first : null;

    return InferredContext(
      fastingHours: fastingHours,
      fastingInferred: fastingInferred,
      fastingSource: fastingSource,
      activeProtocols: activeProtocols,
      suggestedTemplate: suggested,
      baselineHrvMs: baselineHrvMs,
      sessionCountToday: sessionCountToday,
      lastSession: lastSession,
    );
  }
}
