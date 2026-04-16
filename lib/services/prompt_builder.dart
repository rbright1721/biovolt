import '../models/session.dart';
import 'storage_service.dart';

/// Assembles full biological context prompts from stored data for AI analysis.
class PromptBuilder {
  final StorageService _storage;

  PromptBuilder({required StorageService storage}) : _storage = storage;

  // ---------------------------------------------------------------------------
  // System prompt — the AI's role and instructions
  // ---------------------------------------------------------------------------

  static const String systemPrompt = '''
You are a specialized health optimization AI with access to a user's complete biological dataset.

Your role: analyze multi-modal physiological data and find patterns, anomalies, and actionable insights specific to this user's protocols and goals.

Rules:
- Ground every insight in the actual data provided — no generic health advice
- Flag anomalies relative to the user's own baseline, not population averages
- Require 3+ data points before claiming a trend
- Never diagnose — frame as patterns and observations
- When data is insufficient, say so specifically
- Prioritize actionable over explanatory

Output format — respond ONLY with valid JSON, no markdown, no preamble:
{
  "insights": ["array of specific observations grounded in data"],
  "anomalies": ["anything that deviates meaningfully from user baseline"],
  "correlations_detected": ["cross-metric patterns observed"],
  "protocol_recommendations": ["specific adjustments to current protocols"],
  "flags": ["anything requiring attention"],
  "trend_summary": "one paragraph on how this session fits the longer arc",
  "confidence": 0.0-1.0
}''';

  static const String _quickCoachSystem = '''
You are a real-time biofeedback coach. You have access to the user's current session metrics.

Rules:
- Respond with ONE sentence — a specific observation or coaching cue
- Reference the actual numbers provided
- Be direct and actionable, not encouraging or vague
- If metrics are improving, note what's working
- If metrics are declining, suggest a specific adjustment''';

  static const String _weeklyTrendSystem = '''
You are a health data analyst reviewing a user's weekly biometric trends.

Write a concise narrative summary (3-5 paragraphs) covering:
1. Overall trajectory — are they improving, plateauing, or declining?
2. Notable patterns across sleep, HRV, and session performance
3. Correlations between interventions and outcomes
4. Specific recommendations for the next week

Be data-grounded. Reference specific numbers and dates. No generic advice.''';

  // ---------------------------------------------------------------------------
  // Post-session analysis prompt
  // ---------------------------------------------------------------------------

  /// Build a comprehensive prompt for post-session AI analysis.
  ///
  /// Pulls the session, last night's Oura data, 90-day baseline, interventions,
  /// and user profile from [StorageService].
  Future<String> buildSessionPrompt(String sessionId) async {
    final buf = StringBuffer();

    // -- Current session --
    final session = _storage.getSession(sessionId);
    if (session == null) {
      return 'Error: Session $sessionId not found in storage.';
    }
    buf.writeln('=== CURRENT SESSION ===');
    _writeSession(buf, session);

    // -- Last night's Oura data --
    buf.writeln();
    buf.writeln('=== LAST NIGHT (OURA) ===');
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final oura = _storage.getOuraDailyRecord(yesterday);
    if (oura != null) {
      _writeOuraDaily(buf, oura);
    } else {
      buf.writeln('No Oura data available for last night.');
    }

    // -- 90-day baseline summary --
    buf.writeln();
    buf.writeln('=== 90-DAY BASELINE ===');
    final now = DateTime.now();
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));
    final allSessions = _storage.getSessionsInRange(ninetyDaysAgo, now);
    _writeBaselineSummary(buf, allSessions, session);

    // -- Active protocol context (interventions) --
    buf.writeln();
    buf.writeln('=== ACTIVE PROTOCOL ===');
    _writeInterventions(buf, session);

    // -- User profile --
    buf.writeln();
    buf.writeln('=== USER PROFILE ===');
    final profile = _storage.getUserProfile();
    if (profile != null) {
      buf.writeln('Health goals: ${profile.healthGoals.join(', ')}');
      buf.writeln('Baseline established: ${profile.baselineEstablished}');
      if (profile.knownConditions.isNotEmpty) {
        buf.writeln('Known conditions: ${profile.knownConditions.join(', ')}');
      }
      if (profile.aiCoachingStyle != null) {
        buf.writeln('Coaching style preference: ${profile.aiCoachingStyle}');
      }

      // Genetic context
      final hasGenetics = profile.mthfr != null ||
          profile.apoe != null ||
          profile.comt != null;
      if (hasGenetics) {
        buf.writeln();
        buf.writeln('=== GENETIC CONTEXT ===');
        if (profile.mthfr != null) {
          buf.writeln(
              'MTHFR: ${profile.mthfr} \u2014 ${_mthfrDescription(profile.mthfr!)}');
        }
        if (profile.apoe != null) {
          buf.writeln(
              'APOE: ${profile.apoe} \u2014 ${_apoeDescription(profile.apoe!)}');
        }
        if (profile.comt != null) {
          buf.writeln(
              'COMT: ${profile.comt} \u2014 ${_comtDescription(profile.comt!)}');
        }
      }
    } else {
      buf.writeln('No user profile configured.');
    }

    return buf.toString();
  }

  /// Whether the last session prompt included Oura context.
  bool lastPromptUsedOura = false;

  // ---------------------------------------------------------------------------
  // Quick coach prompt (real-time, lightweight)
  // ---------------------------------------------------------------------------

  /// Build a short prompt for real-time coaching during an active session.
  /// Target: under 500 tokens.
  Future<String> buildQuickCoachPrompt(
    Session session,
    Map<String, double> currentMetrics,
  ) async {
    final buf = StringBuffer();

    final activityType =
        session.context?.activities.firstOrNull?.type ?? 'unknown';
    final activitySubtype = session.context?.activities.firstOrNull?.subtype;
    final elapsed = session.durationSeconds ?? 0;

    buf.writeln('Session: $activityType'
        '${activitySubtype != null ? ' ($activitySubtype)' : ''}'
        ', ${elapsed}s elapsed');

    buf.writeln('Current metrics:');
    for (final entry in currentMetrics.entries) {
      buf.writeln('  ${entry.key}: ${entry.value.toStringAsFixed(2)}');
    }

    // Add brief baseline context
    final now = DateTime.now();
    final recent = _storage.getSessionsInRange(
      now.subtract(const Duration(days: 7)),
      now,
    );
    final sameType =
        recent.where((s) => _sessionActivityType(s) == activityType).toList();
    if (sameType.isNotEmpty) {
      final avgHrv = _avgComputed(sameType, (c) => c.hrvRmssdMs);
      if (avgHrv != null) {
        buf.writeln('7-day avg HRV for $activityType: '
            '${avgHrv.toStringAsFixed(1)} ms');
      }
    }

    // Active protocols for coach context
    final protocols = _storage.getAllActiveProtocols();
    if (protocols.isNotEmpty) {
      buf.writeln('Active protocols: ${protocols.map((p) =>
          '${p.name} day ${p.currentCycleDay}/${p.cycleLengthDays}').join(', ')}');
    }

    return buf.toString();
  }

  /// System prompt for quick coaching.
  String get quickCoachSystemPrompt => _quickCoachSystem;

  // ---------------------------------------------------------------------------
  // Weekly trend prompt
  // ---------------------------------------------------------------------------

  /// Build a prompt for weekly trend analysis covering the last 30 days.
  Future<String> buildWeeklyTrendPrompt() async {
    final buf = StringBuffer();
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Sessions
    final sessions = _storage.getSessionsInRange(thirtyDaysAgo, now);
    buf.writeln('=== SESSIONS (LAST 30 DAYS) ===');
    buf.writeln('Total sessions: ${sessions.length}');

    // Group by week
    for (var weekStart = thirtyDaysAgo;
        weekStart.isBefore(now);
        weekStart = weekStart.add(const Duration(days: 7))) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final weekSessions = sessions
          .where((s) =>
              !s.createdAt.isBefore(weekStart) &&
              s.createdAt.isBefore(weekEnd))
          .toList();

      final weekLabel =
          '${weekStart.month}/${weekStart.day}-${weekEnd.month}/${weekEnd.day}';
      buf.writeln('Week $weekLabel: ${weekSessions.length} sessions');

      final avgHrv = _avgComputed(weekSessions, (c) => c.hrvRmssdMs);
      final avgHr = _avgComputed(weekSessions, (c) => c.heartRateMeanBpm);
      if (avgHrv != null) buf.writeln('  Avg HRV: ${avgHrv.toStringAsFixed(1)} ms');
      if (avgHr != null) buf.writeln('  Avg HR: ${avgHr.toStringAsFixed(0)} BPM');
    }

    // Oura records
    buf.writeln();
    buf.writeln('=== OURA DAILY (LAST 30 DAYS) ===');
    final ouraRecords = _storage.getOuraRecordsInRange(thirtyDaysAgo, now);
    if (ouraRecords.isEmpty) {
      buf.writeln('No Oura data available.');
    } else {
      buf.writeln('Days with Oura data: ${ouraRecords.length}');
      final avgSleep = ouraRecords
          .where((r) => r.sleepScore != null)
          .map((r) => r.sleepScore!)
          .toList();
      if (avgSleep.isNotEmpty) {
        buf.writeln('Avg sleep score: '
            '${(avgSleep.reduce((a, b) => a + b) / avgSleep.length).toStringAsFixed(0)}');
      }
      final avgReadiness = ouraRecords
          .where((r) => r.readinessScore != null)
          .map((r) => r.readinessScore!)
          .toList();
      if (avgReadiness.isNotEmpty) {
        buf.writeln('Avg readiness score: '
            '${(avgReadiness.reduce((a, b) => a + b) / avgReadiness.length).toStringAsFixed(0)}');
      }
      final avgOvernightHrv = ouraRecords
          .where((r) => r.overnightHrvAverageMs != null)
          .map((r) => r.overnightHrvAverageMs!)
          .toList();
      if (avgOvernightHrv.isNotEmpty) {
        buf.writeln('Avg overnight HRV: '
            '${(avgOvernightHrv.reduce((a, b) => a + b) / avgOvernightHrv.length).toStringAsFixed(1)} ms');
      }
    }

    // User profile
    final profile = _storage.getUserProfile();
    if (profile != null && profile.healthGoals.isNotEmpty) {
      buf.writeln();
      buf.writeln('=== USER GOALS ===');
      buf.writeln(profile.healthGoals.join(', '));
    }

    return buf.toString();
  }

  /// System prompt for weekly trend reports.
  String get weeklyTrendSystemPrompt => _weeklyTrendSystem;

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _writeSession(StringBuffer buf, Session session) {
    final activity = session.context?.activities.firstOrNull;
    buf.writeln('Activity: ${activity?.type ?? 'unknown'}'
        '${activity?.subtype != null ? ' (${activity!.subtype})' : ''}');
    buf.writeln(
        'Duration: ${session.durationSeconds ?? 0}s');
    buf.writeln('Timezone: ${session.timezone}');
    buf.writeln('Data sources: ${session.dataSources.join(', ')}');

    final bio = session.biometrics;
    if (bio != null) {
      final computed = bio.computed;
      if (computed != null) {
        buf.writeln('Computed metrics:');
        if (computed.heartRateMeanBpm != null) {
          buf.writeln('  HR mean: ${computed.heartRateMeanBpm!.toStringAsFixed(0)} BPM'
              ' (min ${computed.heartRateMinBpm?.toStringAsFixed(0) ?? '?'}'
              ', max ${computed.heartRateMaxBpm?.toStringAsFixed(0) ?? '?'})');
        }
        if (computed.hrvRmssdMs != null) {
          buf.writeln('  HRV RMSSD: ${computed.hrvRmssdMs!.toStringAsFixed(1)} ms');
        }
        if (computed.coherenceScore != null) {
          buf.writeln('  Coherence: ${computed.coherenceScore!.toStringAsFixed(1)}');
        }
        if (computed.lfHfProxy != null) {
          buf.writeln('  LF/HF: ${computed.lfHfProxy!.toStringAsFixed(2)}');
        }
        buf.writeln('  HR source: ${computed.hrSource ?? '?'}'
            ', HRV source: ${computed.hrvSource ?? '?'}');
      }

      final esp32 = bio.esp32;
      if (esp32 != null) {
        if (esp32.gsrMeanUs != null) {
          buf.writeln('  GSR mean: ${esp32.gsrMeanUs!.toStringAsFixed(2)} µS');
        }
        if (esp32.skinTempC != null) {
          buf.writeln('  Skin temp: ${esp32.skinTempC!.toStringAsFixed(1)} °C');
        }
        if (esp32.spo2Percent != null) {
          buf.writeln('  SpO2: ${esp32.spo2Percent!.toStringAsFixed(0)}%');
        }
      }

      final polar = bio.polarH10;
      if (polar != null) {
        buf.writeln('  Polar H10: HR ${polar.heartRateBpm?.toStringAsFixed(0) ?? '?'} BPM'
            ', HRV ${polar.hrvRmssdMs?.toStringAsFixed(1) ?? '?'} ms');
      }
    }

    final subj = session.subjective;
    if (subj != null) {
      if (subj.preSession != null) {
        buf.writeln('Pre-session subjective:');
        _writeSubjective(buf, subj.preSession!);
      }
      if (subj.postSession != null) {
        buf.writeln('Post-session subjective:');
        _writeSubjective(buf, subj.postSession!);
      }
    }
  }

  void _writeSubjective(StringBuffer buf, SubjectiveScores s) {
    final fields = <String, int?>{
      'energy': s.energy,
      'mood': s.mood,
      'focus': s.focus,
      'anxiety': s.anxiety,
      'calm': s.calm,
      'motivation': s.motivation,
      'physicalFeeling': s.physicalFeeling,
      'sessionQuality': s.sessionQuality,
    };
    for (final entry in fields.entries) {
      if (entry.value != null) {
        buf.writeln('  ${entry.key}: ${entry.value}/10');
      }
    }
    if (s.notableEffects != null) {
      buf.writeln('  Notable effects: ${s.notableEffects}');
    }
    if (s.notes != null) buf.writeln('  Notes: ${s.notes}');
  }

  void _writeOuraDaily(StringBuffer buf, oura) {
    if (oura.sleepScore != null) {
      buf.writeln('Sleep score: ${oura.sleepScore}');
    }
    if (oura.readinessScore != null) {
      buf.writeln('Readiness score: ${oura.readinessScore}');
    }
    if (oura.overnightHrvAverageMs != null) {
      buf.writeln(
          'Overnight HRV avg: ${oura.overnightHrvAverageMs.toStringAsFixed(1)} ms');
    }
    if (oura.temperatureDeviationC != null) {
      buf.writeln(
          'Skin temp deviation: ${oura.temperatureDeviationC!.toStringAsFixed(2)} °C');
    }
    if (oura.spo2AveragePercent != null) {
      buf.writeln(
          'SpO2 avg: ${oura.spo2AveragePercent!.toStringAsFixed(0)}%');
    }
    if (oura.stressDaySummary != null) {
      buf.writeln('Stress summary: ${oura.stressDaySummary}');
    }
    if (oura.resilienceLevel != null) {
      buf.writeln('Resilience level: ${oura.resilienceLevel}');
    }
    if (oura.readinessContributors != null) {
      final rc = oura.readinessContributors!;
      buf.writeln('Readiness contributors:');
      if (rc.activityBalance != null) buf.writeln('  Activity balance: ${rc.activityBalance}');
      if (rc.bodyTemperature != null) buf.writeln('  Body temperature: ${rc.bodyTemperature}');
      if (rc.hrvBalance != null) buf.writeln('  HRV balance: ${rc.hrvBalance}');
      if (rc.restingHeartRate != null) buf.writeln('  Resting HR: ${rc.restingHeartRate}');
      if (rc.sleepBalance != null) buf.writeln('  Sleep balance: ${rc.sleepBalance}');
    }
    if (oura.sleepContributors != null) {
      final sc = oura.sleepContributors!;
      buf.writeln('Sleep contributors:');
      if (sc.deepSleep != null) buf.writeln('  Deep sleep: ${sc.deepSleep}');
      if (sc.efficiency != null) buf.writeln('  Efficiency: ${sc.efficiency}');
      if (sc.remSleep != null) buf.writeln('  REM sleep: ${sc.remSleep}');
      if (sc.restfulness != null) buf.writeln('  Restfulness: ${sc.restfulness}');
      if (sc.timing != null) buf.writeln('  Timing: ${sc.timing}');
    }

    lastPromptUsedOura = true;
  }

  void _writeBaselineSummary(
      StringBuffer buf, List<Session> allSessions, Session current) {
    buf.writeln('Total sessions (90 days): ${allSessions.length}');

    if (allSessions.isEmpty) {
      buf.writeln('No baseline data available yet.');
      return;
    }

    // Count by activity type
    final byType = <String, List<Session>>{};
    for (final s in allSessions) {
      final t = _sessionActivityType(s);
      byType.putIfAbsent(t, () => []).add(s);
    }
    for (final entry in byType.entries) {
      buf.writeln('  ${entry.key}: ${entry.value.length} sessions');
    }

    // Mean HRV across all sessions
    final allHrv = _avgComputed(allSessions, (c) => c.hrvRmssdMs);
    if (allHrv != null) {
      buf.writeln('Mean HRV across all sessions: ${allHrv.toStringAsFixed(1)} ms');
    }

    // Mean GSR
    final allGsr = allSessions
        .where((s) => s.biometrics?.esp32?.gsrMeanUs != null)
        .map((s) => s.biometrics!.esp32!.gsrMeanUs!)
        .toList();
    if (allGsr.isNotEmpty) {
      final avgGsr = allGsr.reduce((a, b) => a + b) / allGsr.length;
      buf.writeln('Mean GSR baseline: ${avgGsr.toStringAsFixed(2)} µS');
    }

    // Best HRV response by activity type
    for (final entry in byType.entries) {
      final best = _avgComputed(entry.value, (c) => c.hrvRmssdMs);
      if (best != null) {
        buf.writeln('Avg HRV (${entry.key}): ${best.toStringAsFixed(1)} ms');
      }
    }

    // Current session's activity type average
    final currentType = _sessionActivityType(current);
    final sameType = byType[currentType];
    if (sameType != null && sameType.length > 1) {
      final avgHrv = _avgComputed(sameType, (c) => c.hrvRmssdMs);
      if (avgHrv != null) {
        buf.writeln('Your avg HRV for $currentType: ${avgHrv.toStringAsFixed(1)} ms');
      }
    }
  }

  void _writeInterventions(StringBuffer buf, Session session) {
    final ctx = session.context;
    if (ctx != null) {
      if (ctx.fastingHours != null) {
        buf.writeln('Fasting: ${ctx.fastingHours!.toStringAsFixed(1)} hours');
      }
      if (ctx.timeSinceWakeHours != null) {
        buf.writeln('Time since wake: ${ctx.timeSinceWakeHours!.toStringAsFixed(1)} hours');
      }
      if (ctx.sleepLastNightHours != null) {
        buf.writeln('Sleep last night: ${ctx.sleepLastNightHours!.toStringAsFixed(1)} hours');
      }
      if (ctx.stressContext != null) {
        buf.writeln('Stress context: ${ctx.stressContext}');
      }
      if (ctx.notes != null) {
        buf.writeln('Notes: ${ctx.notes}');
      }
    }

    // Active peptide/supplement protocols
    final protocols = _storage.getAllActiveProtocols();
    if (protocols.isNotEmpty) {
      buf.writeln('Active protocols:');
      for (final p in protocols) {
        final dose = p.doseMcg > 0
            ? ' ${p.doseMcg.toStringAsFixed(0)}mcg'
            : '';
        buf.writeln(
          '  ${p.name}$dose ${p.route} \u2014 day ${p.currentCycleDay} of ${p.cycleLengthDays}'
        );
      }
    } else if (ctx == null) {
      buf.writeln('No protocol context recorded for this session.');
    }
  }

  String _sessionActivityType(Session s) =>
      s.context?.activities.firstOrNull?.type ?? 'unknown';

  double? _avgComputed(
      List<Session> sessions, double? Function(ComputedMetrics) selector) {
    final values = sessions
        .where((s) => s.biometrics?.computed != null)
        .map((s) => selector(s.biometrics!.computed!))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _mthfrDescription(String variant) => switch (variant) {
        'C677T het' =>
          'heterozygous — ~35% reduced methylation, moderate homocysteine risk',
        'C677T hom' =>
          'homozygous — ~70% reduced methylation, higher homocysteine risk',
        'A1298C' =>
          'A1298C variant — mild BH4 impact, less clinically significant',
        'Normal' => 'no significant variants — normal methylation',
        _ => variant,
      };

  String _apoeDescription(String variant) => switch (variant) {
        'E3/E3' => 'standard cardiovascular risk profile',
        'E3/E4' =>
          'one E4 allele — elevated cardiovascular and Alzheimer risk, optimize lipids',
        'E4/E4' =>
          'two E4 alleles — significantly elevated risk, prioritize cardiovascular and cognitive protocols',
        _ => variant,
      };

  String _comtDescription(String variant) => switch (variant) {
        'Val/Val (fast)' =>
          'fast COMT — rapid dopamine clearance, may benefit from dopamine support',
        'Val/Met' => 'moderate dopamine clearance — balanced profile',
        'Met/Met (slow)' =>
          'slow COMT — higher dopamine/catecholamine levels, stress-sensitive, avoid excess stimulants',
        _ => variant,
      };
}
